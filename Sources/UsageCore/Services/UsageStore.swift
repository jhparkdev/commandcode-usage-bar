import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// 사용량 스냅샷과 일별/시간별 누적치를 로컬 SQLite에 저장한다.
public actor UsageStore {
    public enum StoreError: LocalizedError {
        case openFailed(String)
        case executeFailed(String)
        case prepareFailed(String)

        public var errorDescription: String? {
            switch self {
            case .openFailed(let message): return "사용량 DB를 열 수 없습니다: \(message)"
            case .executeFailed(let message): return "DB 작업 실패: \(message)"
            case .prepareFailed(let message): return "DB 준비 실패: \(message)"
            }
        }
    }

    public struct DailyUsage: Sendable, Equatable, Identifiable {
        public let day: String
        public let spent: Double
        public let requests: Int
        public let tokensIn: Int
        public let tokensOut: Int

        public var id: String { day }

        public init(day: String, spent: Double, requests: Int, tokensIn: Int, tokensOut: Int) {
            self.day = day
            self.spent = spent
            self.requests = requests
            self.tokensIn = tokensIn
            self.tokensOut = tokensOut
        }

        /// "2026-10-20" -> "10/20"
        public var shortLabel: String {
            let parts = day.split(separator: "-")
            guard parts.count == 3 else { return day }
            return "\(parts[1])/\(parts[2])"
        }
    }

    public struct HourlyUsage: Sendable, Equatable, Identifiable {
        public let hour: String
        public let spent: Double
        public let requests: Int

        public var id: String { hour }

        public init(hour: String, spent: Double, requests: Int) {
            self.hour = hour
            self.spent = spent
            self.requests = requests
        }

        /// "2026-10-20-14" -> "14시"
        public var shortLabel: String {
            let parts = hour.split(separator: "-")
            guard parts.count == 4 else { return hour }
            return "\(parts[3])시"
        }
    }

    private var db: OpaquePointer?
    private let dayFormatter: DateFormatter
    private let hourFormatter: DateFormatter

    public init(path: URL) throws {
        let directory = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "알 수 없음"
            sqlite3_close(handle)
            throw StoreError.openFailed(message)
        }
        db = handle

        dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = .current
        dayFormatter.dateFormat = "yyyy-MM-dd"

        hourFormatter = DateFormatter()
        hourFormatter.locale = Locale(identifier: "en_US_POSIX")
        hourFormatter.timeZone = .current
        hourFormatter.dateFormat = "yyyy-MM-dd-HH"

        try UsageStore.execute(on: handle, "PRAGMA journal_mode=WAL;")
        try UsageStore.execute(on: handle, "PRAGMA busy_timeout=5000;")
        try UsageStore.execute(on: handle, UsageStore.schema)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    public static let schema = """
    CREATE TABLE IF NOT EXISTS snapshots (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fetched_at REAL NOT NULL,
      period_start TEXT,
      period_end TEXT,
      plan_id TEXT,
      monthly_remaining REAL,
      purchased_credits REAL,
      free_credits REAL,
      five_hour_used REAL,
      five_hour_cap REAL,
      five_hour_reset_at REAL,
      weekly_used REAL,
      weekly_cap REAL,
      weekly_reset_at REAL,
      total_spent REAL,
      total_count INTEGER,
      total_tokens_in INTEGER,
      total_tokens_out INTEGER,
      success_rate REAL
    );
    CREATE INDEX IF NOT EXISTS idx_snapshots_fetched_at ON snapshots(fetched_at);

    CREATE TABLE IF NOT EXISTS daily_usage (
      day TEXT NOT NULL,
      period_start TEXT NOT NULL,
      spent REAL NOT NULL DEFAULT 0,
      requests INTEGER NOT NULL DEFAULT 0,
      tokens_in INTEGER NOT NULL DEFAULT 0,
      tokens_out INTEGER NOT NULL DEFAULT 0,
      updated_at REAL NOT NULL,
      PRIMARY KEY (day, period_start)
    );

    CREATE TABLE IF NOT EXISTS hourly_usage (
      hour TEXT NOT NULL,
      period_start TEXT NOT NULL,
      spent REAL NOT NULL DEFAULT 0,
      requests INTEGER NOT NULL DEFAULT 0,
      tokens_in INTEGER NOT NULL DEFAULT 0,
      tokens_out INTEGER NOT NULL DEFAULT 0,
      updated_at REAL NOT NULL,
      PRIMARY KEY (hour, period_start)
    );
    """

    // MARK: - 기록

    /// 스냅샷을 저장하고 직전 관측과의 증가분을 누적한다.
    @discardableResult
    public func record(_ overview: UsageOverview, at date: Date = Date()) throws -> UsageDelta {
        let previous = try latestSnapshot()
        let delta = UsageDeltaCalculator.delta(previous: previous, current: overview)
        let snapshot = UsageSnapshot(overview: overview, fetchedAt: date)
        let periodStart = snapshot.periodStart ?? ""

        try insert(snapshot: snapshot)
        try upsert(
            table: "daily_usage",
            keyColumn: "day",
            key: dayFormatter.string(from: date),
            periodStart: periodStart,
            delta: delta,
            updatedAt: date.timeIntervalSince1970
        )
        try upsert(
            table: "hourly_usage",
            keyColumn: "hour",
            key: hourFormatter.string(from: date),
            periodStart: periodStart,
            delta: delta,
            updatedAt: date.timeIntervalSince1970
        )
        try pruneIfNeeded(now: date)
        return delta
    }

    public func latestSnapshot() throws -> UsageSnapshot? {
        let sql = """
        SELECT fetched_at, period_start, period_end, plan_id, monthly_remaining, purchased_credits, free_credits,
               five_hour_used, five_hour_cap, five_hour_reset_at,
               weekly_used, weekly_cap, weekly_reset_at,
               total_spent, total_count, total_tokens_in, total_tokens_out, success_rate
        FROM snapshots ORDER BY fetched_at DESC, id DESC LIMIT 1
        """
        let statement = try prepare(sql)
        defer { statement.finalize() }
        guard try statement.step() else { return nil }
        return snapshot(from: statement)
    }

    // MARK: - 조회

    /// 최근 N일의 일별 누적치 (오래된 순)
    public func dailyUsage(days: Int) throws -> [DailyUsage] {
        let window = max(1, days)
        let cutoff = dayFormatter.string(
            from: Calendar.current.date(byAdding: .day, value: -(window - 1), to: Date()) ?? Date()
        )
        let sql = """
        SELECT day, SUM(spent) AS spent, SUM(requests) AS requests, SUM(tokens_in) AS tokens_in, SUM(tokens_out) AS tokens_out
        FROM daily_usage
        WHERE day >= ?
        GROUP BY day
        ORDER BY day DESC
        LIMIT ?
        """
        let statement = try prepare(sql)
        defer { statement.finalize() }
        try statement.bind([.text(cutoff), .int(Int64(window))])
        var rows: [DailyUsage] = []
        while try statement.step() {
            rows.append(
                DailyUsage(
                    day: statement.text(at: 0) ?? "",
                    spent: statement.double(at: 1),
                    requests: Int(statement.int(at: 2)),
                    tokensIn: Int(statement.int(at: 3)),
                    tokensOut: Int(statement.int(at: 4))
                )
            )
        }
        return rows.reversed()
    }

    /// 최근 N시간의 시간별 누적치 (오래된 순)
    public func hourlyUsage(hours: Int) throws -> [HourlyUsage] {
        let window = max(1, hours)
        let cutoff = hourFormatter.string(
            from: Calendar.current.date(byAdding: .hour, value: -(window - 1), to: Date()) ?? Date()
        )
        let sql = """
        SELECT hour, SUM(spent) AS spent, SUM(requests) AS requests
        FROM hourly_usage
        WHERE hour >= ?
        GROUP BY hour
        ORDER BY hour ASC
        """
        let statement = try prepare(sql)
        defer { statement.finalize() }
        try statement.bind([.text(cutoff)])
        var rows: [HourlyUsage] = []
        while try statement.step() {
            rows.append(
                HourlyUsage(
                    hour: statement.text(at: 0) ?? "",
                    spent: statement.double(at: 1),
                    requests: Int(statement.int(at: 2))
                )
            )
        }
        return rows
    }

    // MARK: - 정리

    public func prune(now: Date = Date()) throws {
        let snapshotCutoff = now.addingTimeInterval(-30 * 24 * 60 * 60).timeIntervalSince1970
        let hourlyCutoffKey = hourFormatter.string(from: now.addingTimeInterval(-90 * 24 * 60 * 60))
        let dailyCutoffKey = dayFormatter.string(from: now.addingTimeInterval(-730 * 24 * 60 * 60))

        try execute("DELETE FROM snapshots WHERE fetched_at < \(snapshotCutoff);")
        try execute("DELETE FROM hourly_usage WHERE hour < '\(hourlyCutoffKey)';")
        try execute("DELETE FROM daily_usage WHERE day < '\(dailyCutoffKey)';")
    }

    public func resetHistory() throws {
        try execute("DELETE FROM snapshots;")
        try execute("DELETE FROM daily_usage;")
        try execute("DELETE FROM hourly_usage;")
    }

    /// 하루에 한 번만 정리한다(오래된 스냅샷 · 시간별 · 일별 행 제거).
    public func pruneIfNeeded(
        now: Date = Date(),
        defaults: UserDefaults = .standard,
        key: String = "com.jhpark.commandcode-usage-bar.lastPrunedAt"
    ) throws {
        let last = defaults.double(forKey: key)
        if last > 0, now.timeIntervalSince1970 - last < 24 * 60 * 60 { return }
        try prune(now: now)
        defaults.set(now.timeIntervalSince1970, forKey: key)
    }

    // MARK: - 내부 구현

    private func insert(snapshot: UsageSnapshot) throws {
        let sql = """
        INSERT INTO snapshots (
          fetched_at, period_start, period_end, plan_id, monthly_remaining, purchased_credits, free_credits,
          five_hour_used, five_hour_cap, five_hour_reset_at,
          weekly_used, weekly_cap, weekly_reset_at,
          total_spent, total_count, total_tokens_in, total_tokens_out, success_rate
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        let statement = try prepare(sql)
        defer { statement.finalize() }
        try statement.bind([
            .double(snapshot.fetchedAt.timeIntervalSince1970),
            .text(snapshot.periodStart),
            .text(snapshot.periodEnd),
            .text(snapshot.planId),
            .double(snapshot.monthlyRemaining),
            .double(snapshot.purchasedCredits),
            .double(snapshot.freeCredits),
            .double(snapshot.fiveHourUsed),
            .double(snapshot.fiveHourCap),
            .double(snapshot.fiveHourResetAt?.timeIntervalSince1970),
            .double(snapshot.weeklyUsed),
            .double(snapshot.weeklyCap),
            .double(snapshot.weeklyResetAt?.timeIntervalSince1970),
            .double(snapshot.totalSpent),
            .int(snapshot.totalCount.map(Int64.init)),
            .int(snapshot.totalTokensIn.map(Int64.init)),
            .int(snapshot.totalTokensOut.map(Int64.init)),
            .double(snapshot.successRate)
        ])
        try statement.run()
    }

    private func upsert(
        table: String,
        keyColumn: String,
        key: String,
        periodStart: String,
        delta: UsageDelta,
        updatedAt: TimeInterval
    ) throws {
        let sql = """
        INSERT INTO \(table) (\(keyColumn), period_start, spent, requests, tokens_in, tokens_out, updated_at)
        VALUES (?,?,?,?,?,?,?)
        ON CONFLICT(\(keyColumn), period_start) DO UPDATE SET
          spent = spent + excluded.spent,
          requests = requests + excluded.requests,
          tokens_in = tokens_in + excluded.tokens_in,
          tokens_out = tokens_out + excluded.tokens_out,
          updated_at = excluded.updated_at
        """
        let statement = try prepare(sql)
        defer { statement.finalize() }
        try statement.bind([
            .text(key),
            .text(periodStart),
            .double(delta.spent),
            .int(Int64(delta.requests)),
            .int(Int64(delta.tokensIn)),
            .int(Int64(delta.tokensOut)),
            .double(updatedAt)
        ])
        try statement.run()
    }

    private func snapshot(from statement: Statement) -> UsageSnapshot {
        UsageSnapshot(
            fetchedAt: Date(timeIntervalSince1970: statement.double(at: 0)),
            periodStart: statement.text(at: 1),
            periodEnd: statement.text(at: 2),
            planId: statement.text(at: 3),
            monthlyRemaining: statement.optionalDouble(at: 4),
            purchasedCredits: statement.optionalDouble(at: 5),
            freeCredits: statement.optionalDouble(at: 6),
            fiveHourUsed: statement.optionalDouble(at: 7),
            fiveHourCap: statement.optionalDouble(at: 8),
            fiveHourResetAt: statement.optionalDouble(at: 9).map { Date(timeIntervalSince1970: $0) },
            weeklyUsed: statement.optionalDouble(at: 10),
            weeklyCap: statement.optionalDouble(at: 11),
            weeklyResetAt: statement.optionalDouble(at: 12).map { Date(timeIntervalSince1970: $0) },
            totalSpent: statement.optionalDouble(at: 13),
            totalCount: statement.optionalInt(at: 14),
            totalTokensIn: statement.optionalInt(at: 15),
            totalTokensOut: statement.optionalInt(at: 16),
            successRate: statement.optionalDouble(at: 17)
        )
    }

    private func execute(_ sql: String) throws {
        try UsageStore.execute(on: db, sql)
    }

    private static func execute(on db: OpaquePointer?, _ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errorPointer) == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? "알 수 없음"
            sqlite3_free(errorPointer)
            throw StoreError.executeFailed(message)
        }
    }

    private func prepare(_ sql: String) throws -> Statement {
        guard let db else { throw StoreError.prepareFailed("DB가 열려 있지 않습니다.") }
        return try Statement(db: db, sql: sql)
    }
}

// MARK: - Statement 헬퍼

private final class Statement {
    enum Value {
        case text(String?)
        case double(Double?)
        case int(Int64?)
    }

    private let handle: OpaquePointer
    private var isFinalized = false

    init(db: OpaquePointer, sql: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "알 수 없음"
            sqlite3_finalize(handle)
            throw UsageStore.StoreError.prepareFailed(message)
        }
        self.handle = handle
    }

    deinit { finalize() }

    func finalize() {
        guard !isFinalized else { return }
        isFinalized = true
        sqlite3_finalize(handle)
    }

    func bind(_ values: [Value]) throws {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let status: Int32
            switch value {
            case .text(let string):
                if let string {
                    status = string.withCString { sqlite3_bind_text(handle, index, $0, -1, sqliteTransient) }
                } else {
                    status = sqlite3_bind_null(handle, index)
                }
            case .double(let number):
                if let number {
                    status = sqlite3_bind_double(handle, index, number)
                } else {
                    status = sqlite3_bind_null(handle, index)
                }
            case .int(let number):
                if let number {
                    status = sqlite3_bind_int64(handle, index, number)
                } else {
                    status = sqlite3_bind_null(handle, index)
                }
            }
            guard status == SQLITE_OK else {
                throw UsageStore.StoreError.executeFailed("값 바인딩 실패 (인덱스 \(index))")
            }
        }
    }

    /// true 를 반환하면 행이 하나 읽힌 상태
    func step() throws -> Bool {
        let status = sqlite3_step(handle)
        switch status {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default:
            let message = String(cString: sqlite3_errmsg(handle))
            throw UsageStore.StoreError.executeFailed(message)
        }
    }

    func run() throws {
        _ = try step()
    }

    func text(at index: Int) -> String? {
        let column = Int32(index)
        guard sqlite3_column_type(handle, column) != SQLITE_NULL,
              let pointer = sqlite3_column_text(handle, column) else { return nil }
        return String(cString: pointer)
    }

    func double(at index: Int) -> Double {
        sqlite3_column_double(handle, Int32(index))
    }

    func int(at index: Int) -> Int64 {
        sqlite3_column_int64(handle, Int32(index))
    }

    func optionalDouble(at index: Int) -> Double? {
        sqlite3_column_type(handle, Int32(index)) == SQLITE_NULL ? nil : sqlite3_column_double(handle, Int32(index))
    }

    func optionalInt(at index: Int) -> Int? {
        sqlite3_column_type(handle, Int32(index)) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(handle, Int32(index)))
    }
}

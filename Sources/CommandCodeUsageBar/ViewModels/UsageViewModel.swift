import AppKit
import Combine
import Foundation
import UsageCore

@MainActor
final class UsageViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case loading
        case live
        case stale(String)
        case failed(String)
    }

    @Published private(set) var overview: UsageOverview?
    @Published private(set) var status: Status = .idle
    @Published private(set) var dailyHistory: [UsageStore.DailyUsage] = []
    @Published private(set) var hourlyHistory: [UsageStore.HourlyUsage] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var storeError: String?
    @Published private(set) var authMessage: String?
    @Published var settings: AppSettings {
        didSet {
            settingsStore.save(settings)
            if settings.refreshInterval != oldValue.refreshInterval {
                restartTicker()
            }
        }
    }

    private let auth: AuthKeyResolver
    private let settingsStore: SettingsStore
    private let desktopCache: DesktopCacheReader
    private var store: UsageStore?
    private var ticker: Task<Void, Never>?
    private var observers: [AnyCancellable] = []
    private var consecutiveFailures = 0
    private var isRefreshing = false
    private var hasStarted = false

    init(
        auth: AuthKeyResolver = AuthKeyResolver(),
        settingsStore: SettingsStore = SettingsStore(),
        desktopCache: DesktopCacheReader = DesktopCacheReader(),
        storePath: URL = UsageViewModel.defaultStoreURL()
    ) {
        self.auth = auth
        self.settingsStore = settingsStore
        self.desktopCache = desktopCache
        self.settings = settingsStore.load()
        do {
            store = try UsageStore(path: storePath)
        } catch {
            store = nil
            storeError = error.localizedDescription
        }
    }

    nonisolated public static func defaultStoreURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home
            .appendingPathComponent("Library/Application Support/CommandCodeUsageBar", isDirectory: true)
            .appendingPathComponent("usage.sqlite", isDirectory: false)
    }

    // MARK: - 수명 주기

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        NotificationManager.shared.isEnabled = settings.notificationsEnabled
        let center = NSWorkspace.shared.notificationCenter
        observers.append(
            center.publisher(for: NSWorkspace.didWakeNotification)
                .sink { [weak self] _ in
                    Task { @MainActor in await self?.refresh() }
                }
        )
        observers.append(
            center.publisher(for: NSWorkspace.willSleepNotification)
                .sink { [weak self] _ in
                    Task { @MainActor in self?.ticker?.cancel() }
                }
        )
        restartTicker()
        Task { await refresh() }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        observers.removeAll()
    }

    private func restartTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            // Task 는 MainActor 를 상속하므로 nextInterval() 은 동기 호출이다.
            while !Task.isCancelled {
                let interval = self?.nextInterval() ?? 60
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                await self?.refresh()
            }
        }
    }

    /// 실패하면 백오프(최대 300초), 성공하면 설정 간격으로 복귀. 약간의 지터로 요청을 분산한다.
    private func nextInterval() -> Double {
        let base = settings.refreshInterval
        let backed = min(300, base * pow(2, Double(consecutiveFailures)))
        let jitter = Double.random(in: -5...5)
        return max(30, min(300, backed + jitter))
    }

    // MARK: - 갱신

    func refresh(force: Bool = false) async {
        guard !isRefreshing else { return }
        if !force, let lastUpdated, Date().timeIntervalSince(lastUpdated) < 10, status == .live { return }

        isRefreshing = true
        status = .loading
        let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Command Code 사용량 갱신")
        defer {
            ProcessInfo.processInfo.endActivity(activity)
            isRefreshing = false
        }

        do {
            let key = try auth.readKey()
            authMessage = nil
            let baseURL = URL(string: settings.apiBaseURL) ?? CommandCodeAPIClient.defaultBaseURL
            let client = CommandCodeAPIClient(
                baseURL: baseURL,
                commandCodeVersion: CommandCodeVersion.current
            )
            var fetched = try await client.fetchOverview(apiKey: key)

            if let store {
                let delta = try await store.record(fetched)
                if let warning = delta.warning {
                    fetched.warnings.append(warning)
                }
                await reloadHistory()
            }

            overview = fetched
            lastUpdated = Date()
            consecutiveFailures = 0
            status = .live
            await NotificationManager.shared.evaluate(overview: fetched)
        } catch {
            consecutiveFailures += 1
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if error is AuthError {
                authMessage = message
            }
            if let fallback = desktopCache.readOverview() {
                overview = fallback
                status = .stale(message)
            } else {
                status = .failed(message)
            }
        }
    }

    // MARK: - 인증 설정

    /// 사용자가 `auth.json` 을 직접 고르게 한다(샌드박스 빌드 대응).
    func selectAuthFile() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Command Code 인증 파일(auth.json) 선택"
        panel.message = "~/.commandcode/auth.json 을 선택해 주세요."
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".commandcode")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try auth.saveSelectedFile(url)
            authMessage = nil
            await refresh(force: true)
        } catch {
            authMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 사용자가 직접 넣은 API 키를 키체인에 보관한다.
    func saveManualKey(_ key: String) async {
        do {
            try auth.saveManualKey(key)
            authMessage = nil
            await refresh(force: true)
        } catch {
            authMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func clearManualKey() {
        try? auth.clearManualKey()
    }

    private func reloadHistory() async {
        guard let store else { return }
        do {
            dailyHistory = try await store.dailyUsage(days: 14)
            hourlyHistory = try await store.hourlyUsage(hours: 24)
        } catch {
            storeError = error.localizedDescription
        }
    }

    func resetHistory() async {
        guard let store else { return }
        do {
            try await store.resetHistory()
            dailyHistory = []
            hourlyHistory = []
        } catch {
            storeError = error.localizedDescription
        }
    }

    // MARK: - 파생 값

    var todayUsage: UsageStore.DailyUsage? {
        let key = Self.dayKeyFormatter.string(from: Date())
        return dailyHistory.last { $0.day == key }
    }

    /// 최근 7일을 항상 7칸으로 채운다(관측이 없으면 0).
    var lastSevenDays: [UsageStore.DailyUsage] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let byDay = Dictionary(dailyHistory.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = Self.dayKeyFormatter.string(from: day)
            return byDay[key] ?? UsageStore.DailyUsage(day: key, spent: 0, requests: 0, tokensIn: 0, tokensOut: 0)
        }
    }

    var isLoading: Bool { status == .loading }

    // MARK: - 링크

    func openCommandCodeApp() {
        let path = "/Applications/Command Code.app"
        guard FileManager.default.fileExists(atPath: path) else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func openUsageDashboard() {
        let host = "https://commandcode.ai"
        let login = overview?.org?.login ?? overview?.user?.userName
        let url = login.map { URL(string: "\(host)/\($0)/settings/usage") } ?? URL(string: "\(host)/usage")
        if let url { NSWorkspace.shared.open(url) }
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

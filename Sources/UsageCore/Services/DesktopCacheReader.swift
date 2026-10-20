import Foundation

/// Command Code 데스크톱 앱이 남긴 캐시를 읽는 폴백.
///
/// 데스크톱 앱이 실행 중일 때만 갱신되므로 "마지막 캐시" 용도로만 사용한다.
public struct DesktopCacheReader: Sendable {
    public let appStateURL: URL

    public init(appStateURL: URL = DesktopCacheReader.defaultURL()) {
        self.appStateURL = appStateURL
    }

    public static func defaultURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home
            .appendingPathComponent("Library/Application Support/Command Code", isDirectory: true)
            .appendingPathComponent("app-state.json", isDirectory: false)
    }

    public func readOverview(fetchedAt: Date = Date()) -> UsageOverview? {
        guard
            let data = try? Data(contentsOf: appStateURL),
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any],
            let cache = root["accountCache"] as? [String: Any],
            let result = cache["result"] as? [String: Any],
            let overview = result["overview"] as? [String: Any]
        else { return nil }

        let user = (overview["user"] as? [String: Any]).map {
            UserInfo(
                id: $0["id"] as? String,
                name: $0["name"] as? String,
                email: $0["email"] as? String,
                userName: $0["userName"] as? String
            )
        }
        let subscription = overview["subscription"] as? [String: Any]
        let credits = overview["credits"] as? [String: Any]
        let usage = overview["usage"] as? [String: Any]
        let planId = subscription?["planId"] as? String

        return UsageOverview(
            user: user,
            org: nil,
            planId: planId,
            subscriptionStatus: subscription?["status"] as? String,
            periodStart: (subscription?["currentPeriodStart"] as? String).flatMap(ISO8601.shared.date(from:)),
            periodEnd: (subscription?["currentPeriodEnd"] as? String).flatMap(ISO8601.shared.date(from:)),
            monthlyCredits: credits?["monthlyCredits"] as? Double,
            purchasedCredits: credits?["purchasedCredits"] as? Double,
            freeCredits: credits?["freeCredits"] as? Double,
            planTotalCredits: PlanCatalog.total(for: planId),
            limits: readLimits(overview["windowLimits"]),
            summary: readSummary(usage),
            warnings: ["Command Code 데스크톱 앱이 저장한 캐시를 표시합니다."],
            fetchedAt: (cache["fetchedAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) } ?? fetchedAt
        )
    }

    private func readLimits(_ raw: Any?) -> LimitSet? {
        guard let limits = raw as? [String: Any] else { return nil }
        return LimitSet(
            limited: limits["limited"] as? Bool ?? false,
            exceeded: limits["exceeded"] as? Bool,
            fiveHour: readLimit(limits["fiveHour"]),
            weekly: readLimit(limits["weekly"])
        )
    }

    private func readLimit(_ raw: Any?) -> UsageLimit? {
        guard let window = raw as? [String: Any] else { return nil }
        let resetAt = (window["resetAt"] as? Double).map {
            Date(timeIntervalSince1970: $0 > 1_000_000_000_000 ? $0 / 1000 : $0)
        }
        return UsageLimit(
            used: window["used"] as? Double ?? 0,
            cap: window["cap"] as? Double ?? 0,
            exceeded: window["exceeded"] as? Bool ?? false,
            resetAt: resetAt
        )
    }

    private func readSummary(_ raw: Any?) -> UsageSummary? {
        guard let usage = raw as? [String: Any] else { return nil }
        return UsageSummary(
            totalCount: usage["totalCount"] as? Int ?? 0,
            completedCount: usage["completedCount"] as? Int ?? 0,
            failedCount: usage["failedCount"] as? Int ?? 0,
            totalTokensIn: usage["totalTokensIn"] as? Int ?? 0,
            totalTokensOut: usage["totalTokensOut"] as? Int ?? 0,
            totalTokens: usage["totalTokens"] as? Int ?? 0,
            totalCredits: usage["totalCredits"] as? Double ?? 0,
            totalCost: usage["totalCost"] as? Double ?? 0,
            averageCost: usage["averageCost"] as? Double ?? 0,
            successRate: usage["successRate"] as? Double ?? 0
        )
    }
}

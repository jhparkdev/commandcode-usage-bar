import Foundation

/// 사용량 조회 결과. 서버 응답을 그대로 담는 대신, UI/저장소가 쓸 형태로 정규화한다.
public struct UsageOverview: Sendable, Equatable {
    public var user: UserInfo?
    public var org: OrgInfo?
    public var planId: String?
    public var subscriptionStatus: String?
    public var periodStart: Date?
    public var periodEnd: Date?
    public var monthlyCredits: Double?
    public var purchasedCredits: Double?
    public var freeCredits: Double?
    public var planTotalCredits: Double?
    public var limits: LimitSet?
    public var summary: UsageSummary?
    public var warnings: [String]
    public var fetchedAt: Date

    public init(
        user: UserInfo? = nil,
        org: OrgInfo? = nil,
        planId: String? = nil,
        subscriptionStatus: String? = nil,
        periodStart: Date? = nil,
        periodEnd: Date? = nil,
        monthlyCredits: Double? = nil,
        purchasedCredits: Double? = nil,
        freeCredits: Double? = nil,
        planTotalCredits: Double? = nil,
        limits: LimitSet? = nil,
        summary: UsageSummary? = nil,
        warnings: [String] = [],
        fetchedAt: Date = Date()
    ) {
        self.user = user
        self.org = org
        self.planId = planId
        self.subscriptionStatus = subscriptionStatus
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.monthlyCredits = monthlyCredits
        self.purchasedCredits = purchasedCredits
        self.freeCredits = freeCredits
        self.planTotalCredits = planTotalCredits
        self.limits = limits
        self.summary = summary
        self.warnings = warnings
        self.fetchedAt = fetchedAt
    }

    /// 월간 + 구매 + 무료 크레딧 합계
    public var totalRemainingCredits: Double {
        (monthlyCredits ?? 0) + (purchasedCredits ?? 0) + (freeCredits ?? 0)
    }

    /// 이번 기간에 이미 사용된 크레딧 (서버 권위 값)
    public var periodSpentCredits: Double? {
        summary?.totalCost
    }

    public var daysUntilPeriodEnd: Int? {
        guard let periodEnd else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: periodEnd).day ?? 0
        return max(0, days)
    }
}

public struct UserInfo: Sendable, Equatable {
    public var id: String?
    public var name: String?
    public var email: String?
    public var userName: String?

    public init(id: String? = nil, name: String? = nil, email: String? = nil, userName: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.userName = userName
    }

    public var displayName: String {
        let candidates = [name, userName, email?.split(separator: "@").first.map(String.init)]
        for candidate in candidates {
            if let candidate, !candidate.isEmpty { return candidate }
        }
        return "Command Code"
    }
}

public struct OrgInfo: Sendable, Equatable {
    public var id: String?
    public var name: String?
    public var login: String?

    public init(id: String? = nil, name: String? = nil, login: String? = nil) {
        self.id = id
        self.name = name
        self.login = login
    }
}

/// 롤링 5시간 / 주간 사용량 한도
public struct LimitSet: Sendable, Equatable {
    public var limited: Bool
    public var exceeded: Bool?
    public var fiveHour: UsageLimit?
    public var weekly: UsageLimit?
    public var daily: UsageLimit?

    public init(
        limited: Bool = false,
        exceeded: Bool? = nil,
        fiveHour: UsageLimit? = nil,
        weekly: UsageLimit? = nil,
        daily: UsageLimit? = nil
    ) {
        self.limited = limited
        self.exceeded = exceeded
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.daily = daily
    }
}

/// 개별 사용량 한도
public struct UsageLimit: Sendable, Equatable {
    public var used: Double
    public var cap: Double
    public var exceeded: Bool
    public var resetAt: Date?

    public init(used: Double = 0, cap: Double = 0, exceeded: Bool = false, resetAt: Date? = nil) {
        self.used = used
        self.cap = cap
        self.exceeded = exceeded
        self.resetAt = resetAt
    }

    /// 0...1 구간의 사용률
    public var fraction: Double {
        guard cap > 0 else { return 0 }
        return min(max(used / cap, 0), 1)
    }

    /// 남은 양 (cap - used)
    public var remaining: Double {
        max(cap - used, 0)
    }

    /// 0...1 구간의 잔여율. 화면은 사용량이 아니라 남은량을 보여준다.
    public var remainingFraction: Double {
        guard cap > 0 else { return 0 }
        return min(max(remaining / cap, 0), 1)
    }

    public var percent: Int {
        Int((fraction * 100).rounded())
    }

    /// 잔여량 퍼센트
    public var remainingPercent: Int {
        Int((remainingFraction * 100).rounded())
    }
}

/// 이번 결제 기간의 누적 사용 요약
public struct UsageSummary: Sendable, Equatable {
    public var totalCount: Int
    public var completedCount: Int
    public var failedCount: Int
    public var totalTokensIn: Int
    public var totalTokensOut: Int
    public var totalTokens: Int
    public var totalCredits: Double
    public var totalCost: Double
    public var averageCost: Double
    public var successRate: Double

    public init(
        totalCount: Int = 0,
        completedCount: Int = 0,
        failedCount: Int = 0,
        totalTokensIn: Int = 0,
        totalTokensOut: Int = 0,
        totalTokens: Int = 0,
        totalCredits: Double = 0,
        totalCost: Double = 0,
        averageCost: Double = 0,
        successRate: Double = 0
    ) {
        self.totalCount = totalCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.totalTokensIn = totalTokensIn
        self.totalTokensOut = totalTokensOut
        self.totalTokens = totalTokens
        self.totalCredits = totalCredits
        self.totalCost = totalCost
        self.averageCost = averageCost
        self.successRate = successRate
    }
}

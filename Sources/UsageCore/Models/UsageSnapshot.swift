import Foundation

/// 관측된 한 시점의 사용량 스냅샷 (서버 권위 값)
public struct UsageSnapshot: Sendable, Equatable {
    public var fetchedAt: Date
    public var periodStart: String?
    public var periodEnd: String?
    public var planId: String?
    public var monthlyRemaining: Double?
    public var purchasedCredits: Double?
    public var freeCredits: Double?
    public var fiveHourUsed: Double?
    public var fiveHourCap: Double?
    public var fiveHourResetAt: Date?
    public var weeklyUsed: Double?
    public var weeklyCap: Double?
    public var weeklyResetAt: Date?
    public var totalSpent: Double?
    public var totalCount: Int?
    public var totalTokensIn: Int?
    public var totalTokensOut: Int?
    public var successRate: Double?

    public init(
        fetchedAt: Date,
        periodStart: String? = nil,
        periodEnd: String? = nil,
        planId: String? = nil,
        monthlyRemaining: Double? = nil,
        purchasedCredits: Double? = nil,
        freeCredits: Double? = nil,
        fiveHourUsed: Double? = nil,
        fiveHourCap: Double? = nil,
        fiveHourResetAt: Date? = nil,
        weeklyUsed: Double? = nil,
        weeklyCap: Double? = nil,
        weeklyResetAt: Date? = nil,
        totalSpent: Double? = nil,
        totalCount: Int? = nil,
        totalTokensIn: Int? = nil,
        totalTokensOut: Int? = nil,
        successRate: Double? = nil
    ) {
        self.fetchedAt = fetchedAt
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.planId = planId
        self.monthlyRemaining = monthlyRemaining
        self.purchasedCredits = purchasedCredits
        self.freeCredits = freeCredits
        self.fiveHourUsed = fiveHourUsed
        self.fiveHourCap = fiveHourCap
        self.fiveHourResetAt = fiveHourResetAt
        self.weeklyUsed = weeklyUsed
        self.weeklyCap = weeklyCap
        self.weeklyResetAt = weeklyResetAt
        self.totalSpent = totalSpent
        self.totalCount = totalCount
        self.totalTokensIn = totalTokensIn
        self.totalTokensOut = totalTokensOut
        self.successRate = successRate
    }

    public init(overview: UsageOverview, fetchedAt: Date = Date()) {
        self.init(
            fetchedAt: fetchedAt,
            periodStart: overview.periodStart.map { ISO8601.shared.string(from: $0) },
            periodEnd: overview.periodEnd.map { ISO8601.shared.string(from: $0) },
            planId: overview.planId,
            monthlyRemaining: overview.monthlyCredits,
            purchasedCredits: overview.purchasedCredits,
            freeCredits: overview.freeCredits,
            fiveHourUsed: overview.limits?.fiveHour?.used,
            fiveHourCap: overview.limits?.fiveHour?.cap,
            fiveHourResetAt: overview.limits?.fiveHour?.resetAt,
            weeklyUsed: overview.limits?.weekly?.used,
            weeklyCap: overview.limits?.weekly?.cap,
            weeklyResetAt: overview.limits?.weekly?.resetAt,
            totalSpent: overview.summary?.totalCost,
            totalCount: overview.summary?.totalCount,
            totalTokensIn: overview.summary?.totalTokensIn,
            totalTokensOut: overview.summary?.totalTokensOut,
            successRate: overview.summary?.successRate
        )
    }
}

/// 두 관측 사이의 증가분. 첫 관측이거나 기간이 바뀌면 baseline(0)이다.
public struct UsageDelta: Sendable, Equatable {
    public var spent: Double
    public var requests: Int
    public var tokensIn: Int
    public var tokensOut: Int
    public var isBaseline: Bool
    public var warning: String?

    public init(
        spent: Double = 0,
        requests: Int = 0,
        tokensIn: Int = 0,
        tokensOut: Int = 0,
        isBaseline: Bool = false,
        warning: String? = nil
    ) {
        self.spent = spent
        self.requests = requests
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.isBaseline = isBaseline
        self.warning = warning
    }

    public static let zero = UsageDelta()
}

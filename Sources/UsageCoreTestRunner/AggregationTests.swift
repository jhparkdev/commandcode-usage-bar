import Foundation
@testable import UsageCore

func registerAggregationTests() {
    let periodStart = Date(timeIntervalSince1970: 1_792_461_873) // 2026-10-20T02:04:33Z

    func makeOverview(
        totalCost: Double,
        totalCount: Int = 10,
        tokensIn: Int = 100,
        tokensOut: Int = 20
    ) -> UsageOverview {
        UsageOverview(
            planId: "individual-goat",
            periodStart: periodStart,
            periodEnd: periodStart.addingTimeInterval(30 * 24 * 3600),
            monthlyCredits: 70 - totalCost,
            summary: UsageSummary(
                totalCount: totalCount,
                totalTokensIn: tokensIn,
                totalTokensOut: tokensOut,
                totalCost: totalCost
            )
        )
    }

    test("첫 관측은 기준점으로만 잡는다") {
        let delta = UsageDeltaCalculator.delta(previous: nil, current: makeOverview(totalCost: 5))
        expect(delta.isBaseline, "baseline 이어야 합니다")
        expect(delta.spent == 0, "증가분은 0 이어야 합니다")
        expect(delta.requests == 0, "요청 증가분은 0 이어야 합니다")
    }

    test("같은 기간이면 직전 관측과의 차이를 쓴다") {
        let previous = UsageSnapshot(overview: makeOverview(totalCost: 5, totalCount: 10, tokensIn: 100, tokensOut: 20))
        let delta = UsageDeltaCalculator.delta(
            previous: previous,
            current: makeOverview(totalCost: 7.5, totalCount: 13, tokensIn: 160, tokensOut: 35)
        )

        expect(!delta.isBaseline, "baseline 이 아니어야 합니다")
        expectClose(delta.spent, 2.5, accuracy: 0.0001, "spent")
        expect(delta.requests == 3, "requests 는 3 이어야 합니다")
        expect(delta.tokensIn == 60, "tokensIn 은 60 이어야 합니다")
        expect(delta.tokensOut == 15, "tokensOut 은 15 이어야 합니다")
    }

    test("결제 기간이 바뀌면 기준점을 다시 잡는다") {
        let previous = UsageSnapshot(overview: makeOverview(totalCost: 5))
        let next = UsageOverview(
            planId: "individual-goat",
            periodStart: periodStart.addingTimeInterval(30 * 24 * 3600),
            summary: UsageSummary(totalCount: 2, totalCost: 0.4)
        )
        let delta = UsageDeltaCalculator.delta(previous: previous, current: next)

        expect(delta.isBaseline, "baseline 이어야 합니다")
        expect(delta.spent == 0, "증가분은 0 이어야 합니다")
    }

    test("누적값이 줄면 0 으로 처리하고 알려준다") {
        let previous = UsageSnapshot(overview: makeOverview(totalCost: 5, totalCount: 10))
        let delta = UsageDeltaCalculator.delta(previous: previous, current: makeOverview(totalCost: 3, totalCount: 8))

        expect(delta.spent == 0, "증가분은 0 이어야 합니다")
        expect(delta.requests == 0, "요청 증가분도 0 이어야 합니다")
        expect(delta.warning != nil, "경고가 있어야 합니다")
    }

    test("요약이 없으면 증가분을 계산하지 않는다") {
        let previous = UsageSnapshot(overview: makeOverview(totalCost: 5))
        let current = UsageOverview(planId: "individual-goat", periodStart: periodStart)
        let delta = UsageDeltaCalculator.delta(previous: previous, current: current)

        expect(delta.isBaseline, "baseline 이어야 합니다")
    }
}

import Foundation

/// 스냅샷 사이의 증가분을 계산한다.
///
/// 서버는 현재 기간의 누적값만 주기 때문에, 일별/시간별 히스토리는
/// "직전 관측과의 차이"를 로컬에 누적해야 한다. 앱이 꺼져 있던 구간은
/// 재관측 시점의 증가분으로 귀속되며, 첫 관측은 baseline으로 둔다.
public enum UsageDeltaCalculator {
    public static func delta(previous: UsageSnapshot?, current: UsageOverview) -> UsageDelta {
        guard let previous else {
            return UsageDelta(isBaseline: true)
        }
        guard let currentPeriod = current.periodStart.map({ ISO8601.shared.string(from: $0) }) else {
            return UsageDelta(isBaseline: true)
        }
        guard previous.periodStart == currentPeriod else {
            // 결제 기간이 바뀌면 누적 기준도 새로 잡는다.
            return UsageDelta(isBaseline: true)
        }
        guard let currentSummary = current.summary else {
            return UsageDelta(isBaseline: true)
        }
        guard let previousSpent = previous.totalSpent,
              let previousCount = previous.totalCount,
              let previousTokensIn = previous.totalTokensIn,
              let previousTokensOut = previous.totalTokensOut
        else {
            return UsageDelta(isBaseline: true)
        }

        var warning: String?
        let spent = currentSummary.totalCost - previousSpent
        let requests = currentSummary.totalCount - previousCount
        let tokensIn = currentSummary.totalTokensIn - previousTokensIn
        let tokensOut = currentSummary.totalTokensOut - previousTokensOut

        if spent < 0 || requests < 0 || tokensIn < 0 || tokensOut < 0 {
            warning = "누적값이 감소했습니다(환불/보정). 증가분은 0으로 처리했습니다."
        }

        return UsageDelta(
            spent: max(0, spent),
            requests: max(0, requests),
            tokensIn: max(0, tokensIn),
            tokensOut: max(0, tokensOut),
            isBaseline: false,
            warning: warning
        )
    }
}

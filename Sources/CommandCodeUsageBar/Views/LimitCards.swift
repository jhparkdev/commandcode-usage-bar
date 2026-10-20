import GlassUI
import SwiftUI
import UsageCore

/// 한도 보드.
///
/// 세 개의 한도(5시간 · 주간 · 월간)를 하나의 유리 패널 안에 모아 한 섹션으로
/// 보여준다. 카드가 나란히 늘어지면 좁은 폭 때문에 제목이 잘리고, 서로 다른
/// 섹션처럼 읽히므로 divider 로만 나눈다.
///
/// 모든 한도는 **남은량** 기준으로 보여준다(사용량이 아니라).
struct LimitCards: View {
    let overview: UsageOverview

    var body: some View {
        GlassPanel(cornerRadius: GlassTokens.Radius.panel) {
            VStack(alignment: .leading, spacing: GlassLayout.panelRowGap) {
                if let fiveHour = overview.limits?.fiveHour {
                    GlassHeroLimit(
                        title: "5시간 한도",
                        value: GlassFormat.credits(fiveHour.remaining),
                        valueSuffix: "/ \(GlassFormat.credits(fiveHour.cap)) 크레딧",
                        caption: resetCaption(fiveHour),
                        percent: fiveHour.remainingPercent,
                        percentLabel: "남음",
                        fraction: fiveHour.remainingFraction,
                        color: color(for: fiveHour)
                    )
                }

                if overview.limits?.weekly != nil || overview.planTotalCredits != nil {
                    GlassDivider()
                }

                if let weekly = overview.limits?.weekly {
                    GlassLimitRow(
                        title: "주간 한도",
                        value: GlassFormat.credits(weekly.remaining),
                        valueSuffix: "/ \(GlassFormat.credits(weekly.cap))",
                        caption: resetCaption(weekly),
                        percent: weekly.remainingPercent,
                        percentLabel: "남음",
                        fraction: weekly.remainingFraction,
                        color: color(for: weekly)
                    )
                }

                if overview.planTotalCredits != nil {
                    GlassDivider()
                    monthlyRow
                }
            }
        }
    }

    // MARK: - 월간 한도 (남은량 기준)

    @ViewBuilder
    private var monthlyRow: some View {
        if let total = overview.planTotalCredits, total > 0 {
            let remaining = max(overview.totalRemainingCredits, 0)
            let remainingFraction = min(max(remaining / total, 0), 1)
            GlassLimitRow(
                title: "월간 한도",
                value: GlassFormat.credits(remaining),
                valueSuffix: "/ \(GlassFormat.credits(total))",
                caption: periodCaption,
                percent: GlassFormat.percentValue(remainingFraction),
                percentLabel: "남음",
                fraction: remainingFraction,
                color: GlassPalette.balanceStatus(for: remainingFraction)
            )
        } else {
            // 총량을 모르면 남은 크레딧만 보여준다.
            GlassLimitRow(
                title: "월간 한도",
                value: GlassFormat.credits(overview.totalRemainingCredits),
                valueSuffix: "",
                caption: periodCaption,
                percent: 0,
                percentLabel: "남음",
                fraction: 0,
                color: GlassPalette.secondaryText
            )
        }
    }

    // MARK: - 보조

    private var periodCaption: String? {
        guard let days = overview.daysUntilPeriodEnd else { return nil }
        return "\(days)일 남음"
    }

    /// 잔여량 기준 상태 색
    private func color(for limit: UsageLimit) -> Color {
        GlassPalette.balanceStatus(for: limit.remainingFraction, exceeded: limit.exceeded)
    }

    private func resetCaption(_ limit: UsageLimit) -> String {
        if limit.exceeded { return "한도 초과" }
        return GlassFormat.countdown(to: limit.resetAt)
    }
}

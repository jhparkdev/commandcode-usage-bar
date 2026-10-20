import GlassUI
import SwiftUI
import UsageCore

/// 오늘(로컬 관측) 사용량. 서버 값과 구분해서 "관측 기준"임을 드러낸다.
struct TodayStats: View {
    let today: UsageStore.DailyUsage?

    var body: some View {
        VStack(alignment: .leading, spacing: GlassLayout.groupGap) {
            GlassSectionLabel("오늘 관측된 사용량", caption: "앱 실행 중 증가분")
            HStack(alignment: .top, spacing: GlassLayout.statGap) {
                GlassStat(
                    label: "크레딧",
                    value: GlassFormat.credits(today?.spent ?? 0, maximumFractionDigits: 2)
                )
                GlassStat(
                    label: "요청",
                    value: "\(today?.requests ?? 0)",
                    valueFont: GlassTokens.Typography.numeric
                )
                GlassStat(
                    label: "입력 토큰",
                    value: GlassFormat.tokens(today?.tokensIn ?? 0),
                    valueFont: GlassTokens.Typography.numeric
                )
                GlassStat(
                    label: "출력 토큰",
                    value: GlassFormat.tokens(today?.tokensOut ?? 0),
                    valueFont: GlassTokens.Typography.numeric
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("오늘 관측된 사용량")
    }
}

import Charts
import GlassUI
import SwiftUI
import UsageCore

/// 최근 7일 크레딧 사용 추이.
struct HistoryChart: View {
    let data: [UsageStore.DailyUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: GlassLayout.labelGap) {
            GlassSectionLabel("최근 7일 크레딧 사용", caption: "로컬 관측 기준")

            if data.isEmpty {
                Text("아직 관측 기록이 없습니다. 앱이 켜져 있는 동안 사용량이 쌓입니다.")
                    .font(GlassTokens.Typography.caption)
                    .foregroundStyle(GlassPalette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("일", item.shortLabel),
                        y: .value("크레딧", item.spent)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(GlassTokens.Typography.caption)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                            .font(GlassTokens.Typography.caption)
                    }
                }
                .frame(height: 72)
            }
        }
    }
}

import GlassUI
import SwiftUI
import UsageCore

/// 메뉴바 라벨. 남은량(잔여 %) 기준.
///
/// 상태는 색과 심볼로 함께 알린다(색만으로 전달하지 않는다).
struct MenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        HStack(spacing: GlassLayout.inlineGap) {
            Image(systemName: symbolName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint, GlassPalette.secondaryText.opacity(0.35))
                .font(.system(size: 12, weight: .medium))
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .accessibilityLabel(accessibilityText)
        .help(tooltip)
    }

    // MARK: - 값

    private var text: String {
        switch viewModel.settings.menuBarMode {
        case .fiveHourPercent:
            guard let limit = viewModel.overview?.limits?.fiveHour else { return "—" }
            return GlassFormat.percent(limit.remainingFraction)
        case .weeklyPercent:
            guard let limit = viewModel.overview?.limits?.weekly else { return "—" }
            return GlassFormat.percent(limit.remainingFraction)
        case .remainingCredits:
            guard let overview = viewModel.overview else { return "—" }
            return GlassFormat.credits(overview.totalRemainingCredits)
        }
    }

    /// 잔여율(0...1). 많을수록 좋다.
    private var remainingFraction: Double {
        switch viewModel.settings.menuBarMode {
        case .fiveHourPercent:
            return viewModel.overview?.limits?.fiveHour?.remainingFraction ?? 0
        case .weeklyPercent:
            return viewModel.overview?.limits?.weekly?.remainingFraction ?? 0
        case .remainingCredits:
            guard
                let overview = viewModel.overview,
                let total = overview.planTotalCredits,
                total > 0
            else { return 0 }
            return min(max(overview.totalRemainingCredits / total, 0), 1)
        }
    }

    private var exceeded: Bool {
        switch viewModel.settings.menuBarMode {
        case .fiveHourPercent: return viewModel.overview?.limits?.fiveHour?.exceeded ?? false
        case .weeklyPercent: return viewModel.overview?.limits?.weekly?.exceeded ?? false
        case .remainingCredits: return false
        }
    }

    // MARK: - 표현

    private var symbolName: String {
        switch remainingFraction {
        case 0.6...: return "gauge.with.dots.needle.67percent"
        case 0.25...: return "gauge.with.dots.needle.33percent"
        default: return "gauge.with.dots.needle.100percent"
        }
    }

    private var tint: Color {
        GlassPalette.balanceStatus(for: remainingFraction, exceeded: exceeded)
    }

    private var tooltip: String {
        guard let overview = viewModel.overview else { return "Command Code 사용량" }
        var parts: [String] = ["Command Code \(PlanCatalog.name(for: overview.planId) ?? "사용량")"]
        if let limit = overview.limits?.fiveHour {
            parts.append("5시간 한도 남음 \(GlassFormat.credits(limit.remaining))/\(GlassFormat.credits(limit.cap))")
        }
        if let limit = overview.limits?.weekly {
            parts.append("주간 한도 남음 \(GlassFormat.credits(limit.remaining))/\(GlassFormat.credits(limit.cap))")
        }
        parts.append("업데이트 \(GlassFormat.relativeTime(viewModel.lastUpdated))")
        return parts.joined(separator: " · ")
    }

    private var accessibilityText: String {
        "Command Code 사용량 \(text)"
    }
}

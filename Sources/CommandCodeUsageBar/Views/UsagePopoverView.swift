import GlassUI
import SwiftUI
import UsageCore

/// 모니터링 화면.
/// 구조: 식별(헤더) → 생존 신호(5시간 한도) → 보조 지표 → 관측값 → 추이 → 조작.
struct UsagePopoverView: View {
    @EnvironmentObject private var viewModel: UsageViewModel
    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingSettings {
                SettingsView(showingSettings: $showingSettings)
            } else {
                monitorContent
            }
        }
        .frame(width: 400)
        .task {
            await viewModel.refresh()
        }
    }

    private var monitorContent: some View {
        VStack(alignment: .leading, spacing: GlassLayout.sectionGap) {
            header
                .glassEntrance(index: 0)

            statusBanner
                .glassEntrance(index: 1)

            if let overview = viewModel.overview {
                LimitCards(overview: overview)
                    .glassEntrance(index: 2)

                observationSection
                    .glassEntrance(index: 3)
            } else {
                emptyState
                    .glassEntrance(index: 2)
            }

            GlassDivider()
            footer
                .glassEntrance(index: 4)
        }
        .padding(GlassLayout.screenPadding)
    }

    /// 관측 섹션: 오늘 사용량 + 7일 추이
    private var observationSection: some View {
        VStack(alignment: .leading, spacing: GlassLayout.subSectionGap) {
            TodayStats(today: viewModel.todayUsage)
            HistoryChart(data: viewModel.lastSevenDays)
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(alignment: .center, spacing: GlassLayout.groupGap) {
            VStack(alignment: .leading, spacing: GlassLayout.labelGap) {
                HStack(spacing: GlassLayout.inlineGap) {
                    Text(planTitle)
                        .font(GlassTokens.Typography.title)
                    GlassBadge(statusLabel, tint: statusTint)
                }
                Text(subtitle)
                    .font(GlassTokens.Typography.caption)
                    .foregroundStyle(GlassPalette.secondaryText)
            }
            Spacer(minLength: 0)
            GlassIconButton(
                systemImage: "arrow.clockwise",
                help: "지금 갱신",
                isBusy: viewModel.isLoading
            ) {
                Task { await viewModel.refresh(force: true) }
            }
        }
    }

    private var planTitle: String {
        guard let overview = viewModel.overview else { return "Command Code" }
        let name = PlanCatalog.name(for: overview.planId) ?? "Command Code"
        if let org = overview.org?.name, !org.isEmpty { return "\(name) · \(org)" }
        return name
    }

    private var statusLabel: String {
        switch viewModel.status {
        case .idle, .loading: return "갱신 중"
        case .live: return viewModel.overview?.subscriptionStatus == "active" ? "구독 중" : "활성"
        case .stale: return "오프라인"
        case .failed: return "오류"
        }
    }

    private var statusTint: Color? {
        switch viewModel.status {
        case .stale: return GlassPalette.warning
        case .failed: return GlassPalette.critical
        default: return nil
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let end = viewModel.overview?.periodEnd {
            parts.append("\(GlassFormat.day(end))까지")
        }
        parts.append("업데이트 \(GlassFormat.relativeTime(viewModel.lastUpdated))")
        return parts.joined(separator: " · ")
    }

    // MARK: - 상태 배너

    @ViewBuilder
    private var statusBanner: some View {
        switch viewModel.status {
        case .failed(let message):
            banner(
                icon: "exclamationmark.triangle.fill",
                tint: GlassPalette.critical,
                title: "사용량을 가져오지 못했습니다",
                message: message,
                actionTitle: "인증 설정 열기",
                action: { showingSettings = true }
            )
        case .stale(let message):
            banner(
                icon: "wifi.slash",
                tint: GlassPalette.warning,
                title: "오프라인 · 마지막 캐시 표시 중",
                message: message,
                actionTitle: nil,
                action: nil
            )
        default:
            EmptyView()
        }
    }

    private func banner(
        icon: String,
        tint: Color,
        title: String,
        message: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(alignment: .top, spacing: GlassLayout.groupGap) {
            Image(systemName: icon)
                .font(.system(size: GlassTokens.Size.icon, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: GlassLayout.labelGap) {
                Text(title)
                    .font(GlassTokens.Typography.body.weight(.medium))
                Text(message)
                    .font(GlassTokens.Typography.caption)
                    .foregroundStyle(GlassPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.link)
                        .font(GlassTokens.Typography.caption.weight(.medium))
                }
            }
        }
        .padding(GlassLayout.bannerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: GlassTokens.Radius.control, style: .continuous))
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: GlassLayout.groupGap) {
            Image(systemName: emptyStateSymbol)
                .font(.system(size: 24))
                .foregroundStyle(GlassPalette.secondaryText)
            Text(emptyStateTitle)
                .font(GlassTokens.Typography.body)
                .foregroundStyle(GlassPalette.secondaryText)
            GlassTextButton(emptyStateActionTitle, systemImage: emptyStateActionSymbol) {
                emptyStateAction()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GlassLayout.emptyStatePadding)
    }

    private var isFailed: Bool {
        if case .failed = viewModel.status { return true }
        return false
    }

    private var emptyStateTitle: String {
        isFailed ? "사용량에 연결하지 못했습니다" : "사용량 정보를 불러오고 있습니다"
    }

    private var emptyStateSymbol: String {
        isFailed ? "exclamationmark.triangle" : "gauge.with.dots.needle.50percent"
    }

    private var emptyStateActionTitle: String {
        isFailed ? "인증 설정 열기" : "Command Code 로그인 확인"
    }

    private var emptyStateActionSymbol: String {
        isFailed ? "key" : "arrow.up.forward.app"
    }

    private func emptyStateAction() {
        if isFailed {
            showingSettings = true
        } else {
            viewModel.openCommandCodeApp()
        }
    }

    // MARK: - 푸터

    private var footer: some View {
        HStack(spacing: GlassLayout.groupGap) {
            GlassTextButton("대시보드", systemImage: "safari") {
                viewModel.openUsageDashboard()
            }
            GlassTextButton("설정", systemImage: "gearshape") {
                showingSettings = true
            }
            Spacer(minLength: 0)
            GlassTextButton("종료", systemImage: "power") {
                viewModel.quit()
            }
        }
    }
}

import GlassUI
import SwiftUI
import UsageCore

/// 설정 화면. 시스템 컨트롤(Picker/Toggle/TextField)을 그대로 써서
/// macOS 26 의 네이티브 Liquid Glass 표현을 물려받는다.
///
/// 화면은 세 그룹(기본 · 인증 · 고급)으로 나누고, 그룹 사이에는 `sectionGap` 을 둔다.
struct SettingsView: View {
    @EnvironmentObject private var viewModel: UsageViewModel
    @Binding var showingSettings: Bool
    @State private var launchAtLoginError: String?
    @State private var manualKey: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: GlassLayout.sectionGap) {
            header

            group("기본") {
                Picker("갱신 간격", selection: $viewModel.settings.refreshInterval) {
                    ForEach(AppSettings.refreshIntervalOptions, id: \.self) { option in
                        Text("\(Int(option))초").tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Picker("메뉴바 표시", selection: $viewModel.settings.menuBarMode) {
                    ForEach(MenuBarMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("알림 사용 (남은 20% · 5% 이하 시)", isOn: $viewModel.settings.notificationsEnabled)
                    .onChange(of: viewModel.settings.notificationsEnabled) { _, enabled in
                        Task { await NotificationManager.shared.setEnabled(enabled) }
                    }

                Toggle("로그인 시 자동 실행", isOn: $viewModel.settings.launchAtLogin)
                    .onChange(of: viewModel.settings.launchAtLogin) { _, enabled in
                        switch LaunchAtLogin.setEnabled(enabled) {
                        case .success:
                            launchAtLoginError = nil
                        case .failure(let error):
                            launchAtLoginError = error.localizedDescription
                            viewModel.settings.launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
            }

            group("인증") {
                Picker("인증 방식", selection: $viewModel.settings.authConfiguration.mode) {
                    ForEach(AuthConfiguration.Mode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.settings.authConfiguration.mode) { _, _ in
                    Task { await viewModel.refresh(force: true) }
                }

                Text(viewModel.settings.authConfiguration.mode.explanation)
                    .font(GlassTokens.Typography.caption)
                    .foregroundStyle(GlassPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                switch viewModel.settings.authConfiguration.mode {
                case .commandFile:
                    EmptyView()
                case .selectedFile:
                    GlassTextButton("인증 파일 선택", systemImage: "folder") {
                        Task { await viewModel.selectAuthFile() }
                    }
                case .manualKey:
                    HStack(spacing: GlassLayout.groupGap) {
                        SecureField("API 키", text: $manualKey)
                            .textFieldStyle(.roundedBorder)
                            .font(GlassTokens.Typography.body)
                        GlassTextButton("저장", systemImage: "key") {
                            let key = manualKey
                            manualKey = ""
                            Task { await viewModel.saveManualKey(key) }
                        }
                    }
                }

                if let authMessage = viewModel.authMessage {
                    Text(authMessage)
                        .font(GlassTokens.Typography.caption)
                        .foregroundStyle(GlassPalette.critical)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            group("고급") {
                TextField("API 주소", text: $viewModel.settings.apiBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .font(GlassTokens.Typography.body)

                HStack {
                    GlassTextButton("히스토리 초기화", systemImage: "trash") {
                        Task { await viewModel.resetHistory() }
                    }
                    Spacer(minLength: 0)
                    if let storeError = viewModel.storeError {
                        Text(storeError)
                            .font(GlassTokens.Typography.caption)
                            .foregroundStyle(GlassPalette.critical)
                    }
                }
            }

            if let launchAtLoginError {
                Text(launchAtLoginError)
                    .font(GlassTokens.Typography.caption)
                    .foregroundStyle(GlassPalette.critical)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .controlSize(.small)
    }

    // MARK: - 그룹

    /// 그룹 헤더 + 내용. 그룹 안 요소는 `groupGap` 만큼 띄운다.
    @ViewBuilder
    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: GlassLayout.groupGap) {
            GlassGroupHeader(title)
            VStack(alignment: .leading, spacing: GlassLayout.groupGap) {
                content()
            }
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(spacing: GlassLayout.inlineGap) {
            Button {
                showingSettings = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: GlassTokens.Size.iconSmall, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("뒤로")

            Text("설정")
                .font(GlassTokens.Typography.title)
            Spacer(minLength: 0)
        }
    }
}

import SwiftUI

/// 유리 아이콘 버튼 (새로고침, 닫기 등)
///
/// macOS 26 이상은 네이티브 글래스 버튼, 그 이하는 시스템 버튼 스타일로 그린다.
public struct GlassIconButton: View {
    private let systemImage: String
    private let help: String
    private let isBusy: Bool
    private let action: () -> Void

    @Environment(\.glassPreviewMode) private var previewMode

    public init(
        systemImage: String,
        help: String,
        isBusy: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.help = help
        self.isBusy = isBusy
        self.action = action
    }

    public var body: some View {
        if previewMode {
            previewButton
        } else {
            styledButton
        }
    }

    @ViewBuilder
    private var styledButton: some View {
        let button = Button(action: action) { label }
        if GlassEnvironment.useNativeGlass {
            if #available(macOS 26.0, *) {
                button
                    .buttonStyle(GlassButtonStyle())
                    .help(help)
                    .disabled(isBusy)
                    .accessibilityLabel(help)
            } else {
                button
                    .buttonStyle(.borderless)
                    .help(help)
                    .disabled(isBusy)
                    .accessibilityLabel(help)
            }
        } else {
            button
                .buttonStyle(.borderless)
                .help(help)
                .disabled(isBusy)
                .accessibilityLabel(help)
        }
    }

    /// 오프스크린 스냅샷용(시스템 버튼 스타일은 화면 밖 렌더링에 잡히지 않는다)
    private var previewButton: some View {
        Button(action: action) {
            label
                .padding(.horizontal, GlassLayout.buttonPaddingHorizontal)
                .padding(.vertical, GlassTokens.Space.xxs)
                .background {
                    GlassSurface(cornerRadius: GlassTokens.Radius.capsule)
                }
        }
        .buttonStyle(.plain)
        .help(help)
        .disabled(isBusy)
        .accessibilityLabel(help)
    }

    private var label: some View {
        ZStack {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: GlassTokens.Size.icon, weight: .medium))
            }
        }
        .frame(width: 20, height: 16)
        .contentShape(Rectangle())
    }
}

/// 유리 텍스트 버튼
public struct GlassTextButton: View {
    private let title: String
    private let systemImage: String?
    private let prominent: Bool
    private let action: () -> Void

    @Environment(\.glassPreviewMode) private var previewMode

    public init(
        _ title: String,
        systemImage: String? = nil,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.prominent = prominent
        self.action = action
    }

    public var body: some View {
        if previewMode {
            previewButton
        } else {
            styledButton
        }
    }

    @ViewBuilder
    private var styledButton: some View {
        let button = Button(action: action) { label }
        if GlassEnvironment.useNativeGlass {
            if #available(macOS 26.0, *) {
                if prominent {
                    button.buttonStyle(GlassProminentButtonStyle())
                } else {
                    button.buttonStyle(GlassButtonStyle())
                }
            } else if prominent {
                button.buttonStyle(.borderedProminent)
            } else {
                button.buttonStyle(.bordered)
            }
        } else if prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    /// 오프스크린 스냅샷용
    private var previewButton: some View {
        Button(action: action) {
            label
                .padding(.horizontal, GlassLayout.buttonPaddingHorizontal)
                .padding(.vertical, GlassLayout.buttonPaddingVertical)
                .background {
                    GlassSurface(
                        cornerRadius: GlassTokens.Radius.capsule,
                        style: prominent ? .regular.tint(.accentColor) : .regular
                    )
                }
        }
        .buttonStyle(.plain)
    }

    private var label: some View {
        HStack(spacing: GlassLayout.inlineGap) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: GlassTokens.Size.iconSmall, weight: .semibold))
            }
            Text(title)
                .font(GlassTokens.Typography.body.weight(.medium))
        }
    }
}

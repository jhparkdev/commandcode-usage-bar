import SwiftUI

/// 유리 아이콘 버튼 (새로고침, 닫기 등)
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
            nativeButton
        }
    }

    private var nativeButton: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.glass)
        .help(help)
        .disabled(isBusy)
        .accessibilityLabel(help)
    }

    private var previewButton: some View {
        Button(action: action) {
            label
                .padding(.horizontal, GlassLayout.buttonPaddingHorizontal)
                .padding(.vertical, GlassTokens.Space.xxs)
                .background {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.regular, in: .capsule)
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
            nativeButton
        }
    }

    @ViewBuilder
    private var nativeButton: some View {
        if prominent {
            Button(action: action) { label }
                .buttonStyle(GlassProminentButtonStyle())
        } else {
            Button(action: action) { label }
                .buttonStyle(GlassButtonStyle())
        }
    }

    private var previewButton: some View {
        Button(action: action) {
            label
                .padding(.horizontal, GlassLayout.buttonPaddingHorizontal)
                .padding(.vertical, GlassLayout.buttonPaddingVertical)
                .background {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(prominent ? .regular.tint(.accentColor) : .regular, in: .capsule)
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

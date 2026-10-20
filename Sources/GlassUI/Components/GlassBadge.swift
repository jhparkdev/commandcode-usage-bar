import SwiftUI

/// 유리 알약 배지. 상태나 범주를 짧게 표시할 때 쓴다.
public struct GlassBadge: View {
    private let text: String
    private let systemImage: String?
    private let tint: Color?
    private let glass: Glass

    public init(
        _ text: String,
        systemImage: String? = nil,
        tint: Color? = nil,
        glass: Glass = .regular
    ) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
        self.glass = glass
    }

    public var body: some View {
        HStack(spacing: GlassLayout.inlineGap) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(GlassTokens.Typography.badge)
        }
        .foregroundStyle(tint ?? .primary)
        .padding(.horizontal, GlassLayout.badgePaddingHorizontal)
        .padding(.vertical, GlassLayout.badgePaddingVertical)
        .background {
            Capsule()
                .fill(.clear)
                .glassEffect(tinted, in: .capsule)
        }
    }

    private var tinted: Glass {
        guard let tint else { return glass }
        return glass.tint(tint)
    }
}

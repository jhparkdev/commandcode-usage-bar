import SwiftUI

/// Liquid Glass 표면.
///
/// 글래스는 "콘텐츠 위에 떠 있는 컨트롤 레이어"에만 쓴다.
/// 유리는 항상 콘텐츠의 배경 레이어로 두고, 그 위에 내용을 올린다.
///
/// macOS 26 미만에서는 `Material` 기반 폴백으로 그린다.
public struct GlassSurface: View {
    private let cornerRadius: CGFloat
    private let style: GlassStyle

    public init(
        cornerRadius: CGFloat = GlassTokens.Radius.panel,
        style: GlassStyle = .regular
    ) {
        self.cornerRadius = cornerRadius
        self.style = style
    }

    public var body: some View {
        if GlassEnvironment.useNativeGlass {
            if #available(macOS 26.0, *) {
                nativeGlass
            } else {
                fallback
            }
        } else {
            fallback
        }
    }

    @available(macOS 26.0, *)
    private var nativeGlass: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(style.native, in: .rect(cornerRadius: cornerRadius))
    }

    /// 하위 버전 폴백: 재료(material) + 옅은 색으로 유리의 깊이를 흉내낸다.
    private var fallback: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tintFill)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }

    private var tintFill: Color {
        guard let tint = style.tint else { return .clear }
        return tint.opacity(0.22)
    }
}

/// 유리 표면 위에 콘텐츠를 얹는 컨테이너.
///
/// 유리 레이어는 항상 콘텐츠 뒤에 놓인다(배경 레이어). 그래서 텍스트가
/// 유리 위로 가려지지 않고, 표면 크기도 콘텐츠 크기에 정확히 맞춘다.
public struct GlassPanel<Content: View>: View {
    private let cornerRadius: CGFloat
    private let style: GlassStyle
    private let padding: CGFloat
    private let content: Content

    public init(
        cornerRadius: CGFloat = GlassTokens.Radius.panel,
        style: GlassStyle = .regular,
        padding: CGFloat = GlassLayout.panelPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.style = style
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background {
                GlassSurface(cornerRadius: cornerRadius, style: style)
            }
    }
}

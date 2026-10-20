import SwiftUI

/// Liquid Glass 표면.
///
/// 글래스는 "콘텐츠 위에 떠 있는 컨트롤 레이어"에만 쓴다.
/// 유리는 항상 콘텐츠의 배경 레이어로 두고, 그 위에 내용을 올린다.
public struct GlassSurface: View {
    private let cornerRadius: CGFloat
    private let glass: Glass

    public init(
        cornerRadius: CGFloat = GlassTokens.Radius.panel,
        glass: Glass = .regular
    ) {
        self.cornerRadius = cornerRadius
        self.glass = glass
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
    }
}

/// 유리 표면 위에 콘텐츠를 얹는 컨테이너.
///
/// 유리 레이어는 항상 콘텐츠 뒤에 놓인다(배경 레이어). 그래서 텍스트가
/// 유리 위로 가려지지 않고, 표면 크기도 콘텐츠 크기에 정확히 맞춘다.
public struct GlassPanel<Content: View>: View {
    private let cornerRadius: CGFloat
    private let glass: Glass
    private let padding: CGFloat
    private let content: Content

    public init(
        cornerRadius: CGFloat = GlassTokens.Radius.panel,
        glass: Glass = .regular,
        padding: CGFloat = GlassLayout.panelPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.glass = glass
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background {
                GlassSurface(cornerRadius: cornerRadius, glass: glass)
            }
    }
}

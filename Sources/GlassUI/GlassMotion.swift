import SwiftUI

/// 3-비트 등장 애니메이션(스케일 0.96 → 1, 투명도 0 → 1).
/// 접근성 "모션 줄이기" 설정이 켜져 있으면 즉시 표시한다.
public struct GlassEntrance: ViewModifier {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    public init(index: Int = 0) {
        self.index = index
    }

    public func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1 : (appeared ? 1 : 0))
            .scaleEffect(reduceMotion ? 1 : (appeared ? 1 : 0.96), anchor: .top)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    GlassTokens.Motion.spring.delay(Double(index) * GlassTokens.Motion.stagger)
                ) {
                    appeared = true
                }
            }
    }
}

public extension View {
    func glassEntrance(index: Int = 0) -> some View {
        modifier(GlassEntrance(index: index))
    }
}

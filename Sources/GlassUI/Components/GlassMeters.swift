import SwiftUI

/// 선형 사용률 게이지. 트랙은 반투명 캡슐, 채움은 상태색.
public struct GlassMeter: View {
    private let fraction: Double
    private let color: Color
    private let height: CGFloat

    public init(
        fraction: Double,
        color: Color,
        height: CGFloat = 5
    ) {
        self.fraction = fraction
        self.color = color
        self.height = height
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(GlassPalette.track)
                Capsule()
                    .fill(color.gradient)
                    .frame(width: geometry.size.width * clampedFraction)
            }
        }
        .frame(height: height)
        .animation(GlassTokens.Motion.value, value: fraction)
        .accessibilityHidden(true)
    }

    private var clampedFraction: Double {
        max(0, min(fraction, 1))
    }
}

/// 원형 사용률 게이지. 중앙에 숫자를 얹는다.
public struct GlassRing<Center: View>: View {
    private let fraction: Double
    private let color: Color
    private let lineWidth: CGFloat
    private let size: CGFloat
    private let center: () -> Center

    public init(
        fraction: Double,
        color: Color,
        lineWidth: CGFloat = 6,
        size: CGFloat = 64,
        @ViewBuilder center: @escaping () -> Center
    ) {
        self.fraction = fraction
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
        self.center = center
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(GlassPalette.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0, min(fraction, 1)))
                .stroke(
                    color.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(GlassTokens.Motion.value, value: fraction)
            center()
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

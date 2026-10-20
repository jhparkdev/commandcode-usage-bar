import SwiftUI

/// 한도 행.
///
/// 유리 패널 안에서 한 줄을 차지한다.
///
/// ```text
/// [제목]                        [비율 % 단위]
/// [큰 값] / [상한]      [초기화까지 남은 시간]
/// [게이지]
/// ```
///
/// - 퍼센트에는 항상 단위(“사용”/“남음”)를 붙인다. 색만으로 의미를 전달하지 않는다.
/// - 헤더에는 제목과 퍼센트만 둔다. 부제목(카운트다운)은 값 행에 붙여 좁은 곳에서도
///   제목이 잘리지 않게 한다.
public struct GlassLimitRow: View {
    private let title: String
    private let value: String
    private let valueSuffix: String
    private let caption: String?
    private let percent: Int
    private let percentLabel: String
    private let fraction: Double
    private let color: Color

    public init(
        title: String,
        value: String,
        valueSuffix: String,
        caption: String? = nil,
        percent: Int,
        percentLabel: String = "사용",
        fraction: Double,
        color: Color
    ) {
        self.title = title
        self.value = value
        self.valueSuffix = valueSuffix
        self.caption = caption
        self.percent = percent
        self.percentLabel = percentLabel
        self.fraction = fraction
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: GlassLayout.labelGap) {
            LimitHeader(
                title: title,
                percent: percent,
                percentLabel: percentLabel,
                color: color
            )
            LimitValueRow(value: value, suffix: valueSuffix, caption: caption)
            GlassMeter(fraction: fraction, color: color)
        }
    }
}

/// 히어로 한도 행. 원형 게이지를 앞에 두고 더 크게 다룬다.
public struct GlassHeroLimit: View {
    private let title: String
    private let value: String
    private let valueSuffix: String
    private let caption: String?
    private let percent: Int
    private let percentLabel: String
    private let fraction: Double
    private let color: Color

    public init(
        title: String,
        value: String,
        valueSuffix: String,
        caption: String? = nil,
        percent: Int,
        percentLabel: String = "남음",
        fraction: Double,
        color: Color
    ) {
        self.title = title
        self.value = value
        self.valueSuffix = valueSuffix
        self.caption = caption
        self.percent = percent
        self.percentLabel = percentLabel
        self.fraction = fraction
        self.color = color
    }

    public var body: some View {
        HStack(spacing: GlassLayout.heroGap) {
            GlassRing(fraction: fraction, color: color, lineWidth: 6, size: GlassTokens.Size.heroRing) {
                VStack(spacing: -1) {
                    Text("\(percent)")
                        .font(GlassTokens.Typography.hero)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("% \(percentLabel)")
                        .font(GlassTokens.Typography.caption)
                        .foregroundStyle(GlassPalette.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: GlassLayout.labelGap) {
                LimitHeader(title: title, percent: nil, percentLabel: percentLabel, color: color)
                LimitValueRow(value: value, suffix: valueSuffix, caption: caption)
                GlassMeter(fraction: fraction, color: color)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - 공유 조각

private struct LimitHeader: View {
    let title: String
    let percent: Int?
    let percentLabel: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: GlassLayout.inlineGap) {
            Text(title)
                .font(GlassTokens.Typography.title)
                .lineLimit(1)
            Spacer(minLength: GlassTokens.Space.s)
            if let percent {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(percent)")
                        .font(GlassTokens.Typography.title)
                        .foregroundStyle(color)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("% \(percentLabel)")
                        .font(GlassTokens.Typography.caption)
                        .foregroundStyle(color)
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(percent)퍼센트 \(percentLabel)")
            }
        }
    }
}

private struct LimitValueRow: View {
    let value: String
    let suffix: String
    let caption: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: GlassLayout.valueGap) {
            Text(value)
                .font(GlassTokens.Typography.numeric)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(suffix)
                .font(GlassTokens.Typography.caption)
                .foregroundStyle(GlassPalette.secondaryText)
            Spacer(minLength: GlassTokens.Space.s)
            if let caption {
                Text(caption)
                    .font(GlassTokens.Typography.caption)
                    .foregroundStyle(GlassPalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}

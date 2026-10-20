import SwiftUI

/// 라벨 + 값 한 쌍. 3단계 위계에서 디테일 단계를 담당한다.
public struct GlassStat: View {
    private let label: String
    private let value: String
    private let valueFont: Font
    private let valueColor: Color

    public init(
        label: String,
        value: String,
        valueFont: Font = GlassTokens.Typography.numeric,
        valueColor: Color = .primary
    ) {
        self.label = label
        self.value = value
        self.valueFont = valueFont
        self.valueColor = valueColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: GlassLayout.labelGap) {
            Text(label)
                .font(GlassTokens.Typography.caption)
                .foregroundStyle(GlassPalette.secondaryText)
            Text(value)
                .font(valueFont)
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}

/// 섹션 라벨. 짧은 설명과 보조 액션을 함께 담는다.
public struct GlassSectionLabel: View {
    private let title: String
    private let caption: String?

    public init(_ title: String, caption: String? = nil) {
        self.title = title
        self.caption = caption
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: GlassLayout.inlineGap) {
            Text(title)
                .font(GlassTokens.Typography.title)
            if let caption {
                Text(caption)
                    .font(GlassTokens.Typography.caption)
                    .foregroundStyle(GlassPalette.tertiaryText)
            }
            Spacer(minLength: 0)
        }
    }
}

/// 그룹 헤더. 큰 화면을 구획해 각 묶음이 따로 읽히게 한다.
public struct GlassGroupHeader: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(GlassTokens.Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(GlassPalette.secondaryText)
    }
}

/// 얇은 구분선
public struct GlassDivider: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.18))
            .frame(height: GlassTokens.Space.hairline)
    }
}

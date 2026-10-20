import CoreGraphics
import SwiftUI

/// 디자인 토큰.
///
/// 간격은 1·2·4·6·8·12·16·20·24·32 스케일만 쓴다.
/// 화면에서 임의 수치를 쓰지 않고 `GlassLayout` 의 역할 이름으로만 간격을 표현한다.
public enum GlassTokens {
    public enum Space {
        /// 1pt — 구분선 두께
        public static let hairline: CGFloat = 1
        /// 2pt — 인라인 아이콘 ↔ 텍스트
        public static let xxs: CGFloat = 2
        /// 4pt — 라벨 ↔ 값, 배지 내부 여백
        public static let xs: CGFloat = 4
        /// 6pt — 아주 좁은 여백
        public static let sm: CGFloat = 6
        /// 8pt — 같은 그룹 안 요소 간격
        public static let s: CGFloat = 8
        /// 12pt — 카드 패딩, 그룹 간격
        public static let m: CGFloat = 12
        /// 16pt — 섹션 간격
        public static let l: CGFloat = 16
        /// 20pt — 큰 섹션 간격
        public static let xl: CGFloat = 20
        /// 24pt — 여백
        public static let xxl: CGFloat = 24
        /// 32pt — 매크로 여백
        public static let huge: CGFloat = 32
    }

    public enum Radius {
        /// 작은 컨트롤(아이콘 버튼, 입력)
        public static let control: CGFloat = 10
        /// 카드
        public static let card: CGFloat = 14
        /// 패널
        public static let panel: CGFloat = 18
        /// 강조 영역
        public static let hero: CGFloat = 22
        /// 알약형
        public static let capsule: CGFloat = 999
    }

    /// 위계는 3단계로 유지한다. 훅(제목) / 브리지(설명) / 디테일(본문·수치)
    public enum Typography {
        public static let hero = Font.system(size: 30, weight: .semibold, design: .rounded)
        public static let numeric = Font.system(size: 21, weight: .semibold, design: .rounded)
        public static let title = Font.system(size: 13, weight: .semibold, design: .default)
        public static let body = Font.system(size: 12, weight: .regular, design: .default)
        public static let caption = Font.system(size: 10, weight: .regular, design: .default)
        public static let badge = Font.system(size: 10, weight: .semibold, design: .default)
    }

    public enum Motion {
        /// UI 스프링: 빠르게 반응하되 살짝 튀는 느낌
        public static let spring = Animation.spring(response: 0.34, dampingFraction: 0.82)
        /// 눌림/토글 같은 즉각 반응
        public static let quick = Animation.spring(response: 0.22, dampingFraction: 0.9)
        /// 값 변경(숫자/게이지) 전환
        public static let value = Animation.spring(response: 0.45, dampingFraction: 0.9)
        /// 스태거 간격(초)
        public static let stagger: Double = 0.025
    }

    public enum Size {
        /// 최소 포인터 타깃
        public static let hitTarget: CGFloat = 28
        public static let iconSmall: CGFloat = 11
        public static let icon: CGFloat = 13
        public static let iconLarge: CGFloat = 18
        /// 히어로 게이지 지름
        public static let heroRing: CGFloat = 66
    }
}

/// 레이아웃 역할.
///
/// 화면마다 숫자를 직접 쓰지 않고 이 역할 이름만 쓴다.
/// - 여백(padding): 공간을 감싼다
/// - 간격(gap): 형제 요소 사이에 둔다
public enum GlassLayout {
    // MARK: 여백

    /// 화면(팝오버) 바깥 여백
    public static let screenPadding = GlassTokens.Space.l
    /// 카드/패널 안쪽 여백
    public static let panelPadding = GlassTokens.Space.l
    /// 배지 안쪽 여백(가로)
    public static let badgePaddingHorizontal = GlassTokens.Space.s
    /// 배지 안쪽 여백(세로)
    public static let badgePaddingVertical = GlassTokens.Space.xs
    /// 버튼 안쪽 여백(가로)
    public static let buttonPaddingHorizontal = GlassTokens.Space.s
    /// 버튼 안쪽 여백(세로)
    public static let buttonPaddingVertical = GlassTokens.Space.xs
    /// 배너 안쪽 여백
    public static let bannerPadding = GlassTokens.Space.m
    /// 빈 상태 여백(세로)
    public static let emptyStatePadding = GlassTokens.Space.xxl

    // MARK: 간격

    /// 최상위 섹션 사이 간격(헤더 · 한도 · 관측 · 조작)
    public static let sectionGap = GlassTokens.Space.xl
    /// 한 섹션 안 하위 섹션 사이 간격
    public static let subSectionGap = GlassTokens.Space.l
    /// 같은 그룹 안 형제 요소 간격
    public static let groupGap = GlassTokens.Space.m
    /// 패널 안 한도 행 사이 간격
    public static let panelRowGap = GlassTokens.Space.m
    /// 카드 그리드 열 간격
    public static let columnGap = GlassTokens.Space.m
    /// 히어로 안 요소 간격(링 ↔ 텍스트)
    public static let heroGap = GlassTokens.Space.m
    /// 통계 값 열 간격
    public static let statGap = GlassTokens.Space.l
    /// 라벨 ↔ 값 사이 간격
    public static let labelGap = GlassTokens.Space.xs
    /// 큰 값 ↔ 상한 사이 간격
    public static let valueGap = GlassTokens.Space.xs
    /// 인라인 아이콘 ↔ 텍스트 간격
    public static let inlineGap = GlassTokens.Space.xxs
    /// 구분선 위아래 여백
    public static let dividerInset = GlassTokens.Space.xs
}

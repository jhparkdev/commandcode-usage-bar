import SwiftUI

/// 의미 기반 색상 역할.
///
/// 상태 색상은 장식이 아니라 의미를 담는다(사용률 경고). 그 외 강조는
/// 시스템 액센트 색을 그대로 써서 macOS 네이티브 감각을 유지한다.
public enum GlassPalette {
    /// 정상
    public static let good = Color(red: 0.20, green: 0.68, blue: 0.42)
    /// 주의 (사용률 60~85%)
    public static let warning = Color(red: 0.94, green: 0.62, blue: 0.16)
    /// 위험 (사용률 85% 이상 / 한도 초과)
    public static let critical = Color(red: 0.89, green: 0.27, blue: 0.25)

    /// 보조 텍스트(한 단계 아래)
    public static let secondaryText = Color.secondary
    /// 3단계 위계의 마지막 디테일
    public static let tertiaryText = Color.secondary.opacity(0.75)

    /// 표면 트랙(게이지 배경)
    public static let track = Color.secondary.opacity(0.16)

    /// 사용률에 따른 상태 색
    public static func status(for fraction: Double, exceeded: Bool = false) -> Color {
        if exceeded { return critical }
        switch fraction {
        case ..<0.6: return good
        case ..<0.85: return warning
        default: return critical
        }
    }

    /// 잔여량에 따른 상태 색(많이 남으면 초록, 바닥이면 빨강).
    /// 화면이 남은량 기준이므로 이 규칙을 기본으로 쓴다.
    public static func balanceStatus(for remainingFraction: Double, exceeded: Bool = false) -> Color {
        if exceeded { return critical }
        switch remainingFraction {
        case 0.6...: return good
        case 0.25...: return warning
        default: return critical
        }
    }
}

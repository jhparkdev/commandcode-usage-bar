import SwiftUI

/// 글래스 스타일.
///
/// macOS 26 의 `Glass` 타입을 그대로 노출하면 하위 버전에서 컴파일할 수 없다.
/// 그래서 우리만의 타입으로 추상화하고, 실제로 적용할 때 버전 분기를 한다.
///
/// - macOS 26 이상: 실제 Liquid Glass(`glassEffect`)
/// - 그 이하: `Material` 기반 폴백(비주얼만 다름)
public struct GlassStyle {
    public enum Variant {
        case regular
        case clear
    }

    public var variant: Variant
    /// 색을 약간 섞은 유리( macOS 26 의 `.tint` 대응 )
    public var tint: Color?
    /// 누르는 반응을 주는 유리( macOS 26 의 `.interactive` 대응 )
    public var isInteractive: Bool

    public init(
        variant: Variant = .regular,
        tint: Color? = nil,
        isInteractive: Bool = false
    ) {
        self.variant = variant
        self.tint = tint
        self.isInteractive = isInteractive
    }

    public static let regular = GlassStyle()
    public static let clear = GlassStyle(variant: .clear)

    public func tint(_ color: Color?) -> GlassStyle {
        var copy = self
        copy.tint = color
        return copy
    }

    public func interactive(_ isEnabled: Bool = true) -> GlassStyle {
        var copy = self
        copy.isInteractive = isEnabled
        return copy
    }
}

/// 글래스 적용 여부를 결정하는 전역 설정.
public enum GlassEnvironment {
    /// 구버전 렌더링을 확인하려고 폴백 경로를 강제한다.
    public static var forceFallback: Bool {
        ProcessInfo.processInfo.environment["CCUB_FORCE_FALLBACK"] == "1"
    }

    /// 실제 Liquid Glass 를 쓸 수 있는가?
    public static var useNativeGlass: Bool {
        if forceFallback { return false }
        if #available(macOS 26.0, *) { return true }
        return false
    }
}

@available(macOS 26.0, *)
extension GlassStyle {
    /// macOS 26 의 네이티브 글래스로 변환
    var native: Glass {
        var glass: Glass = (variant == .clear) ? .clear : .regular
        if let tint {
            glass = glass.tint(tint)
        }
        if isInteractive {
            glass = glass.interactive()
        }
        return glass
    }
}

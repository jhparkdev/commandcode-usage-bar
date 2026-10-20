import SwiftUI

/// 오프스크린 렌더링 시 글래스 버튼 스타일의 대체 경로.
///
/// macOS 26 의 네이티브 `.glass` 버튼 스타일은 시스템이 직접 그리므로
/// 화면 밖 렌더링(스냅샷)에는 잡히지 않는다. 레이아웃을 확인할 때는
/// 같은 유리 표면을 직접 얹은 버전으로 그린다.
public struct GlassPreviewKey: EnvironmentKey {
    public static let defaultValue = false
}

public extension EnvironmentValues {
    var glassPreviewMode: Bool {
        get { self[GlassPreviewKey.self] }
        set { self[GlassPreviewKey.self] = newValue }
    }
}

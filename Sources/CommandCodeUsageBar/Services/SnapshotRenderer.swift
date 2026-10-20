import AppKit
import SwiftUI
import UsageCore

/// 팝오버 화면을 실제 창에 올려 렌더링해 PNG 로 저장한다.
///
/// `CommandCodeUsageBar --snapshot <경로>` 로 실행하면 현재 사용량으로 그려진다.
/// 메뉴바 팝오버와 동일한 렌더링 경로(NSHostingView)를 쓰므로 UI 확인용으로 쓴다.
@MainActor
enum SnapshotRenderer {
    /// 스냅샷을 저장하고 실제 저장된 경로를 돌려준다.
    /// 저장할 수 없으면(샌드박스 등) 앱 컨테이너 안으로 물러간다.
    static func write(viewModel: UsageViewModel, to url: URL) -> URL? {
        let root = UsagePopoverView()
            .environmentObject(viewModel)
            .environment(\.glassPreviewMode, true)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 368, height: 400)

        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.orderFront(nil)
        hosting.layoutSubtreeIfNeeded()

        // SwiftUI 레이아웃이 끝날 시간을 준다.
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        hosting.layoutSubtreeIfNeeded()

        let fitted = hosting.fittingSize
        let size = NSSize(
            width: max(hosting.frame.width, fitted.width),
            height: min(hosting.frame.height, max(fitted.height, 1))
        )
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        guard
            let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        else {
            return nil
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return nil }

        do {
            try png.write(to: url)
            return url
        } catch {
            let fallback = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("popover-snapshot.png")
            try? png.write(to: fallback)
            return fallback
        }
    }
}

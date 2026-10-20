import AppKit
import SwiftUI
import UsageCore

@main
struct CommandCodeUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: UsageViewModel

    init() {
        let model = UsageViewModel()
        _viewModel = StateObject(wrappedValue: model)
        MainActor.assumeIsolated { model.start() }
        MainActor.assumeIsolated { runSnapshotIfRequested(model) }
    }

    /// `--snapshot <경로>` 면 팝오버를 PNG 로 저장하고 종료한다 (UI 확인용).
    private func runSnapshotIfRequested(_ model: UsageViewModel) {
        guard
            let index = CommandLine.arguments.firstIndex(of: "--snapshot"),
            index + 1 < CommandLine.arguments.count
        else { return }

        let url = URL(fileURLWithPath: CommandLine.arguments[index + 1])
        Task { @MainActor in
            await model.refresh(force: true)
            // 시작 시점의 갱신이 이미 돌고 있으면 그 결과를 기다린다.
            for _ in 0..<60 {
                if !model.isLoading && model.overview != nil { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            if let saved = SnapshotRenderer.write(viewModel: model, to: url) {
                FileHandle.standardError.write(Data("스냅샷 저장: \(saved.path)\n".utf8))
                exit(0)
            } else {
                FileHandle.standardError.write(Data("스냅샷 저장 실패\n".utf8))
                exit(1)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView()
                .environmentObject(viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}

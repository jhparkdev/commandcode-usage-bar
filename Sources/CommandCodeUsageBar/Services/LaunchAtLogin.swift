import AppKit
import Foundation
import ServiceManagement

/// 로그인 시 자동 실행.
///
/// `SMAppService` 는 코드 서명이 있어야 안정적으로 동작하므로, 실패하면
/// `~/Library/LaunchAgents` plist 방식으로 대체한다.
enum LaunchAtLogin {
    enum Mode: String {
        case serviceManagement
        case launchAgent
        case none
    }

    private static let agentLabel = "com.jhpark.commandcode-usage-bar"
    private static let modeKey = "com.jhpark.commandcode-usage-bar.launchMode"

    static var currentMode: Mode {
        if SMAppService.mainApp.status == .enabled { return .serviceManagement }
        if agentPlistURL().exists { return .launchAgent }
        return .none
    }

    static var isEnabled: Bool { currentMode != .none }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Result<Mode, Error> {
        switch currentMode {
        case .serviceManagement:
            if enabled { return .success(.serviceManagement) }
            do {
                try SMAppService.mainApp.unregister()
                return .success(.none)
            } catch {
                return .failure(error)
            }
        case .launchAgent:
            if enabled { return .success(.launchAgent) }
            do {
                try removeAgent()
                return .success(.none)
            } catch {
                return .failure(error)
            }
        case .none:
            guard enabled else { return .success(.none) }
            do {
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(Mode.serviceManagement.rawValue, forKey: modeKey)
                return .success(.serviceManagement)
            } catch {
                do {
                    try writeAgent()
                    UserDefaults.standard.set(Mode.launchAgent.rawValue, forKey: modeKey)
                    return .success(.launchAgent)
                } catch {
                    return .failure(error)
                }
            }
        }
    }

    // MARK: - LaunchAgent

    private static func agentPlistURL() -> URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentLabel).plist", isDirectory: false)
    }

    private static func writeAgent() throws {
        let url = agentPlistURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let appPath = Bundle.main.bundlePath
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": ["/usr/bin/open", "-a", appPath],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)
    }

    private static func removeAgent() throws {
        let url = agentPlistURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

private extension URL {
    var exists: Bool { FileManager.default.fileExists(atPath: path) }
}

import Foundation

public enum MenuBarMode: String, CaseIterable, Codable, Sendable {
    case fiveHourPercent
    case weeklyPercent
    case remainingCredits

    public var title: String {
        switch self {
        case .fiveHourPercent: return "5시간 한도"
        case .weeklyPercent: return "주간 한도"
        case .remainingCredits: return "월간 한도"
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var refreshInterval: Double = 60
    public var menuBarMode: MenuBarMode = .fiveHourPercent
    public var launchAtLogin: Bool = false
    public var apiBaseURL: String = CommandCodeAPIClient.defaultBaseURL.absoluteString
    public var notificationsEnabled: Bool = false
    public var authConfiguration: AuthConfiguration = AuthConfiguration()

    public init(
        refreshInterval: Double = 60,
        menuBarMode: MenuBarMode = .fiveHourPercent,
        launchAtLogin: Bool = false,
        apiBaseURL: String = CommandCodeAPIClient.defaultBaseURL.absoluteString,
        notificationsEnabled: Bool = false,
        authConfiguration: AuthConfiguration = AuthConfiguration()
    ) {
        self.refreshInterval = refreshInterval
        self.menuBarMode = menuBarMode
        self.launchAtLogin = launchAtLogin
        self.apiBaseURL = apiBaseURL
        self.notificationsEnabled = notificationsEnabled
        self.authConfiguration = authConfiguration
    }

    public static let refreshIntervalOptions: [Double] = [30, 60, 120, 300]
}

public final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "com.jhpark.commandcode-usage-bar.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard
            let data = defaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return settings
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}

import Foundation
import GlassUI
import UserNotifications
import UsageCore

/// 5시간/주간 사용 한도가 임계치를 넘으면 알린다. 한도가 초기화되면 다시 알린다.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let storageKey = "com.jhpark.commandcode-usage-bar.notifiedThresholds"
    private let thresholds: [Double] = [0.2, 0.05] // 잔여 20% 이하, 5% 이하

    private init() {}

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "com.jhpark.commandcode-usage-bar.notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "com.jhpark.commandcode-usage-bar.notificationsEnabled") }
    }

    /// 앱 번들 밖에서 실행하면 UserNotifications 가 예외를 던지므로, 번들 안일 때만 접근한다.
    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    func setEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        guard enabled, let center else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// 갱신된 사용량을 확인해 남은량이 임계치 이하로 내려가면 알린다.
    func evaluate(overview: UsageOverview) async {
        guard isEnabled else { return }
        var notified = storedThresholds()

        let limits: [(String, UsageLimit?)] = [
            ("5시간 한도", overview.limits?.fiveHour),
            ("주간 한도", overview.limits?.weekly)
        ]

        for (label, limit) in limits {
            guard let limit else { continue }
            let identity = "\(label)-\(limit.resetAt?.timeIntervalSince1970 ?? 0)"
            for threshold in thresholds where limit.remainingFraction <= threshold {
                let key = "\(identity)-\(threshold)"
                if notified[key] == nil {
                    notified[key] = threshold
                    await post(
                        title: "\(label) 남은 \(Int(threshold * 100))% 이하",
                        body: "\(GlassFormat.credits(limit.remaining)) / \(GlassFormat.credits(limit.cap)) 크레딧 남음"
                    )
                }
            }
        }
        storeThresholds(notified)
    }

    private func post(title: String, body: String) async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func storedThresholds() -> [String: Double] {
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Double] ?? [:]
    }

    private func storeThresholds(_ values: [String: Double]) {
        UserDefaults.standard.set(values, forKey: storageKey)
    }
}

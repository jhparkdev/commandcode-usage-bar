import Foundation

/// 표시용 포맷터.
///
/// 앱에서 숫자·시간 표시는 전부 여기서 한다.
/// 포매터를 만들어 쓰지 않고(스레드 안전하지 않다) 두 개의 정적 포매터만 쓴다.
public enum GlassFormat {
    private static let oneDecimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private static let twoDecimals: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter
    }()

    /// 크레딧 수치. 소수 1자리(기본) 또는 2자리.
    public static func credits(_ value: Double?, maximumFractionDigits: Int = 1) -> String {
        guard let value else { return "—" }
        let formatter = maximumFractionDigits >= 2 ? twoDecimals : oneDecimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// 0...1 비율을 퍼센트 문자열로.
    public static func percent(_ fraction: Double) -> String {
        "\(Int((max(0, min(fraction, 1)) * 100).rounded()))%"
    }

    /// 0...1 비율을 정수 퍼센트로.
    public static func percentValue(_ fraction: Double) -> Int {
        Int((max(0, min(fraction, 1)) * 100).rounded())
    }

    /// 토큰 수를 짧게(K/M).
    public static func tokens(_ value: Int) -> String {
        let absolute = abs(value)
        switch absolute {
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", Double(value) / 1_000)
        default:
            return "\(value)"
        }
    }

    /// "방금" · "3분 전" · "2시간 전"
    public static func relativeTime(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "—" }
        let interval = now.timeIntervalSince(date)
        if interval < 10 { return "방금" }
        if interval < 60 { return "\(Int(interval))초 전" }
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86_400 { return "\(Int(interval / 3600))시간 전" }
        return dayFormatter.string(from: date)
    }

    /// "2시간 14분 후" · "1일 3시간 후" · "초기화됨"
    public static func countdown(to date: Date?, now: Date = Date()) -> String {
        guard let date else { return "—" }
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return "초기화됨" }
        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let minutes = totalMinutes % 60
        if days > 0 {
            return hours > 0 ? "\(days)일 \(hours)시간 후" : "\(days)일 후"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)시간 \(minutes)분 후" : "\(hours)시간 후"
        }
        return "\(max(minutes, 1))분 후"
    }

    public static func dateTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        return dateTimeFormatter.string(from: date)
    }

    public static func day(_ date: Date?) -> String {
        guard let date else { return "—" }
        return dayFormatter.string(from: date)
    }
}

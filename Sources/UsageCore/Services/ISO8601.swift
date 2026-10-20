import Foundation

/// ISO8601 파서. 소수 초를 포함한 형식을 우선 시도하고 없으면 기본 형식을 쓴다.
public struct ISO8601 {
    public static let shared = ISO8601()

    private let withFractional: ISO8601DateFormatter
    private let plain: ISO8601DateFormatter

    private init() {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        withFractional = fractional
        plain = standard
    }

    public func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return withFractional.date(from: trimmed) ?? plain.date(from: trimmed)
    }

    public func string(from date: Date) -> String {
        withFractional.string(from: date)
    }
}

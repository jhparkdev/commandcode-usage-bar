import Foundation
import CryptoKit

public enum AuthError: LocalizedError {
    case notAuthenticated
    case noSelectedFile
    case noManualKey
    case fileAccessDenied
    case commandFileUnavailable

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Command Code 로그인이 필요합니다. Command Code 앱에서 다시 로그인해 주세요."
        case .noSelectedFile:
            return "인증 파일이 지정되지 않았습니다. 설정에서 ‘인증 파일 선택’을 눌러 auth.json 을 골라 주세요."
        case .noManualKey:
            return "API 키가 입력되지 않았습니다. 설정에서 API 키를 입력해 주세요."
        case .fileAccessDenied:
            return "인증 파일에 접근할 수 없습니다. 파일 권한을 다시 확인해 주세요."
        case .commandFileUnavailable:
            return "~/.commandcode/auth.json 을 읽을 수 없습니다. 설정에서 ‘사용자가 고른 파일’ 또는 ‘API 키 직접 입력’을 사용해 주세요."
        }
    }
}

/// `~/.commandcode/auth.json` 에서 API 키를 읽는다.
/// 키는 메모리로만 다루고, 로그/DB/디스크에는 절대 남기지 않는다.
public struct AuthKeyProvider: Sendable {
    public static let environmentKeyName = "COMMAND_CODE_API_KEY"

    public let authFileURL: URL
    /// 개발 편의를 위한 `COMMAND_CODE_API_KEY` 환경변수 사용 여부
    public let useEnvironmentOverride: Bool

    public init(
        authFileURL: URL = AuthKeyProvider.defaultAuthFileURL(),
        useEnvironmentOverride: Bool = true
    ) {
        self.authFileURL = authFileURL
        self.useEnvironmentOverride = useEnvironmentOverride
    }

    public static func defaultAuthFileURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home
            .appendingPathComponent(".commandcode", isDirectory: true)
            .appendingPathComponent("auth.json", isDirectory: false)
    }

    public func readKey() throws -> String {
        if useEnvironmentOverride,
           let env = ProcessInfo.processInfo.environment[AuthKeyProvider.environmentKeyName] {
            let trimmed = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }

        guard FileManager.default.fileExists(atPath: authFileURL.path) else {
            throw AuthError.notAuthenticated
        }
        guard let data = try? Data(contentsOf: authFileURL) else {
            throw AuthError.notAuthenticated
        }
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any],
            let key = dictionary["apiKey"] as? String
        else {
            throw AuthError.notAuthenticated
        }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AuthError.notAuthenticated }
        return trimmed
    }

    /// 로그에 남길 수 있는 키 지문 (앞 8자 해시)
    public func keyFingerprint() -> String? {
        guard let key = try? readKey() else { return nil }
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(8).description
    }
}

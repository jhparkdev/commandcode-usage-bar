import Foundation

/// 인증 방식 설정.
public struct AuthConfiguration: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, Sendable, CaseIterable {
        /// `~/.commandcode/auth.json` 을 직접 읽는다(샌드박스 밖 빌드 기본값).
        case commandFile
        /// 사용자가 직접 고른 파일에서 읽는다(샌드박스 빌드 대응).
        case selectedFile
        /// 사용자가 직접 넣은 API 키(키체인 보관).
        case manualKey

        public var title: String {
            switch self {
            case .commandFile: return "Command Code 인증 파일"
            case .selectedFile: return "사용자가 고른 파일"
            case .manualKey: return "API 키 직접 입력"
            }
        }

        public var explanation: String {
            switch self {
            case .commandFile:
                return "~/.commandcode/auth.json 을 읽습니다."
            case .selectedFile:
                return "‘인증 파일 선택’으로 auth.json 을 골라 주세요. 앱이 그 파일만 읽습니다."
            case .manualKey:
                return "Command Code API 키를 직접 입력합니다. 키체인에만 저장됩니다."
            }
        }
    }

    public var mode: Mode

    public init(mode: Mode = .commandFile) {
        self.mode = mode
    }

    /// 샌드박스 빌드에서는 기본값을 직접 지정한 파일로 바꾼다.
    public static func defaultForSandboxedApp() -> AuthConfiguration {
        AuthConfiguration(mode: .selectedFile)
    }
}

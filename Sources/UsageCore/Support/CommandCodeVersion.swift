import Foundation

/// 설치된 Command Code 데스크톱 앱의 버전을 읽어 API 헤더에 쓴다.
public enum CommandCodeVersion {
    public static let current: String? = {
        let path = "/Applications/Command Code.app"
        guard let bundle = Bundle(path: path) else { return nil }
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }()
}

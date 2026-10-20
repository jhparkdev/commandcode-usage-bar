import Foundation

/// 인증 방식에 따라 API 키를 읽어온다.
///
/// 세 가지 경로를 지원한다.
/// 1. `commandFile`  — `~/.commandcode/auth.json` 직접 읽기(샌드박스 밖)
/// 2. `selectedFile` — 사용자가 NSOpenPanel 로 고른 파일(샌드박스 대응)
/// 3. `manualKey`    — 사용자가 입력한 키(키체인 보관)
///
/// 어떤 경로든 키는 메모리로만 사용하고 로그/DB/설정 파일에 남기지 않는다.
public struct AuthKeyResolver: Sendable {
    public static let selectedFileBookmarkAccount = "selected-auth-file-bookmark"
    public static let manualKeyAccount = "manual-api-key"

    private let configuration: AuthConfiguration
    private let commandFileProvider: AuthKeyProvider
    private let keychain: KeychainStore

    public init(
        configuration: AuthConfiguration = AuthConfiguration(),
        commandFileProvider: AuthKeyProvider = AuthKeyProvider(),
        keychain: KeychainStore = KeychainStore()
    ) {
        self.configuration = configuration
        self.commandFileProvider = commandFileProvider
        self.keychain = keychain
    }

    public func readKey() throws -> String {
        switch configuration.mode {
        case .commandFile:
            do {
                return try commandFileProvider.readKey()
            } catch {
                // 샌드박스 빌드에서는 ~/.commandcode/auth.json 을 읽을 수 없다.
                throw AuthError.commandFileUnavailable
            }
        case .selectedFile:
            return try readSelectedFileKey()
        case .manualKey:
            return try readManualKey()
        }
    }

    /// 사용자가 고른 파일의 보안 범위 북마크를 키체인에 보관한다.
    public func saveSelectedFile(_ url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try keychain.set(
            bookmark.base64EncodedString(),
            for: Self.selectedFileBookmarkAccount
        )
    }

    public func hasSelectedFile() -> Bool {
        (try? keychain.value(for: Self.selectedFileBookmarkAccount)) != nil
    }

    public func saveManualKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AuthError.notAuthenticated }
        try keychain.set(trimmed, for: Self.manualKeyAccount)
    }

    public func hasManualKey() -> Bool {
        (try? keychain.value(for: Self.manualKeyAccount)) != nil
    }

    public func clearManualKey() throws {
        try keychain.remove(account: Self.manualKeyAccount)
    }

    // MARK: - 내부

    private func readSelectedFileKey() throws -> String {
        guard
            let encoded = try keychain.value(for: Self.selectedFileBookmarkAccount),
            let data = Data(base64Encoded: encoded)
        else {
            throw AuthError.noSelectedFile
        }

        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw AuthError.noSelectedFile
        }

        guard url.startAccessingSecurityScopedResource() else {
            throw AuthError.fileAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard
            let contents = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: contents),
            let dictionary = object as? [String: Any],
            let key = dictionary["apiKey"] as? String,
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AuthError.notAuthenticated
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func readManualKey() throws -> String {
        guard let key = try keychain.value(for: Self.manualKeyAccount) else {
            throw AuthError.noManualKey
        }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AuthError.noManualKey }
        return trimmed
    }
}

import Foundation
@testable import UsageCore

func registerAuthKeyProviderTests() {
    func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("auth-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func writeAuthFile(_ contents: String, in directory: URL) -> URL {
        let url = directory.appendingPathComponent("auth.json")
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    test("auth.json 에서 API 키를 읽는다") {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = writeAuthFile(#"{"apiKey":"  secret-key  ","userName":"tester"}"#, in: directory)
        let provider = AuthKeyProvider(authFileURL: url, useEnvironmentOverride: false)
        do {
            expect(try provider.readKey() == "secret-key", "공백이 잘린 키를 읽어야 합니다")
        } catch {
            expect(false, "키를 읽지 못했습니다: \(error)")
        }
    }

    test("파일이 없으면 인증 오류") {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = AuthKeyProvider(
            authFileURL: directory.appendingPathComponent("none.json"),
            useEnvironmentOverride: false
        )
        expectThrows(AuthError.self) { _ = try provider.readKey() }
    }

    test("키가 비어 있으면 인증 오류") {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = writeAuthFile(#"{"apiKey":"   "}"#, in: directory)
        let provider = AuthKeyProvider(authFileURL: url, useEnvironmentOverride: false)
        expectThrows(AuthError.self) { _ = try provider.readKey() }
    }

    test("파일이 깨져 있으면 인증 오류") {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = writeAuthFile("not json", in: directory)
        let provider = AuthKeyProvider(authFileURL: url, useEnvironmentOverride: false)
        expectThrows(AuthError.self) { _ = try provider.readKey() }
    }

    test("기본 경로는 ~/.commandcode/auth.json 이다") {
        let home = URL(fileURLWithPath: "/Users/example")
        let url = AuthKeyProvider.defaultAuthFileURL(home: home)
        expect(url.path == "/Users/example/.commandcode/auth.json", "기본 경로가 달라졌습니다")
    }
}

import Foundation

/// 최소한의 테스트 하네스.
///
/// 이 프로젝트는 Xcode 없이( Command Line Tools 만으로 ) 빌드·실행되므로
/// XCTest 나 swift-testing 런타임을 쓸 수 없다. 그래서 직접 만든 러너를 쓴다.
final class TestRegistry {
    static let shared = TestRegistry()
    private(set) var tests: [(name: String, body: () async throws -> Void)] = []

    private init() {}

    func register(_ name: String, _ body: @escaping () async throws -> Void) {
        tests.append((name, body))
    }
}

final class TestRunState {
    static let current = TestRunState()
    private(set) var failures: [String] = []

    private init() {}

    func reset() { failures.removeAll() }

    func record(_ message: String) { failures.append(message) }
}

func test(_ name: String, _ body: @escaping () async throws -> Void) {
    TestRegistry.shared.register(name, body)
}

func expect(
    _ condition: Bool,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if !condition {
        TestRunState.current.record("\(file):\(line) — \(message)")
    }
}

func expect<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ label: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if actual != expected {
        let prefix = label.isEmpty ? "" : "\(label) "
        TestRunState.current.record("\(file):\(line) — \(prefix)expected \(expected), got \(actual)")
    }
}

func expectClose(
    _ actual: Double,
    _ expected: Double,
    accuracy: Double,
    _ label: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if abs(actual - expected) > accuracy {
        let prefix = label.isEmpty ? "" : "\(label) "
        TestRunState.current.record("\(file):\(line) — \(prefix)expected \(expected) ± \(accuracy), got \(actual)")
    }
}

func expectThrows<E: Error>(
    _ type: E.Type,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () throws -> Void
) {
    do {
        try body()
        TestRunState.current.record("\(file):\(line) — \(E.self) 이 발생해야 하는데 발생하지 않았습니다")
    } catch is E {
        // 기대한 오류
    } catch {
        TestRunState.current.record("\(file):\(line) — \(E.self) 를 기대했지만 \(error) 가 발생했습니다")
    }
}

func expectThrows<E: Error>(
    _ type: E.Type,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () async throws -> Void
) async {
    do {
        try await body()
        TestRunState.current.record("\(file):\(line) — \(E.self) 이 발생해야 하는데 발생하지 않았습니다")
    } catch is E {
        // 기대한 오류
    } catch {
        TestRunState.current.record("\(file):\(line) — \(E.self) 를 기대했지만 \(error) 가 발생했습니다")
    }
}

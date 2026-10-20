import Foundation
import UsageCore

registerAPIDecodingTests()
registerAggregationTests()
registerUsageStoreTests()
registerAuthKeyProviderTests()
registerGlassFormatTests()
registerUsageLimitTests()

let total = TestRegistry.shared.tests.count
var passed = 0
var failed = 0

for testCase in TestRegistry.shared.tests {
    TestRunState.current.reset()
    do {
        try await testCase.body()
    } catch {
        TestRunState.current.record("예외: \(error)")
    }
    if TestRunState.current.failures.isEmpty {
        passed += 1
        print("✓ \(testCase.name)")
    } else {
        failed += 1
        print("✗ \(testCase.name)")
        for failure in TestRunState.current.failures {
            print("    \(failure)")
        }
    }
}

print("")
print("테스트 \(passed)/\(total) 통과")
exit(failed == 0 ? 0 : 1)

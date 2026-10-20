import Foundation
import UsageCore

func registerUsageLimitTests() {
    func makeLimit(used: Double, cap: Double, exceeded: Bool = false) -> UsageLimit {
        UsageLimit(used: used, cap: cap, exceeded: exceeded, resetAt: Date())
    }

    test("남은량은 상한에서 사용량을 뺀 값이다") {
        let limit = makeLimit(used: 3.9, cap: 14)
        expectClose(limit.remaining, 10.1, accuracy: 0.0001, "remaining")
        expectClose(limit.remainingFraction, 10.1 / 14, accuracy: 0.0001, "remainingFraction")
        expect(limit.remainingPercent == 72, "remainingPercent 는 72 이어야 합니다")
    }

    test("한도를 초과하면 남은량은 0 이다") {
        let limit = makeLimit(used: 20, cap: 14, exceeded: true)
        expectClose(limit.remaining, 0, accuracy: 0.0001, "remaining")
        expectClose(limit.remainingFraction, 0, accuracy: 0.0001, "remainingFraction")
    }

    test("상한이 없으면 잔여율은 0 이다") {
        let limit = makeLimit(used: 0, cap: 0)
        expectClose(limit.remainingFraction, 0, accuracy: 0.0001, "remainingFraction")
        expect(limit.remainingPercent == 0, "remainingPercent 는 0 이어야 합니다")
    }

    test("사용률과 잔여율은 서로 반대다") {
        let limit = makeLimit(used: 7, cap: 35)
        expectClose(limit.fraction + limit.remainingFraction, 1, accuracy: 0.0001, "합")
    }
}

import Foundation
@testable import UsageCore

func registerUsageStoreTests() {
    func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("usage-store-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func makeOverview(
        totalCost: Double,
        totalCount: Int,
        at date: Date,
        periodStart: Date = Date(timeIntervalSince1970: 1_792_461_873)
    ) -> UsageOverview {
        UsageOverview(
            planId: "individual-goat",
            periodStart: periodStart,
            monthlyCredits: 70 - totalCost,
            summary: UsageSummary(
                totalCount: totalCount,
                totalTokensIn: totalCount * 100,
                totalTokensOut: totalCount * 20,
                totalCost: totalCost
            ),
            fetchedAt: date
        )
    }

    test("첫 기록은 baseline, 두 번째 기록부터 증가분이 쌓인다") {
        do {
            let directory = makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try UsageStore(path: directory.appendingPathComponent("usage.sqlite"))
            let now = Date()

            let first = try await store.record(makeOverview(totalCost: 5, totalCount: 10, at: now), at: now)
            expect(first.isBaseline, "첫 기록은 baseline 이어야 합니다")

            let second = try await store.record(
                makeOverview(totalCost: 7, totalCount: 12, at: now.addingTimeInterval(60)),
                at: now.addingTimeInterval(60)
            )
            expect(!second.isBaseline, "두 번째 기록은 baseline 이 아니어야 합니다")
            expectClose(second.spent, 2, accuracy: 0.0001, "spent")
            expect(second.requests == 2, "requests 는 2 이어야 합니다")

            let daily = try await store.dailyUsage(days: 7)
            expect(daily.count == 1, "일별 집계는 1건이어야 합니다")
            expectClose(daily.first?.spent ?? 0, 2, accuracy: 0.0001, "daily.spent")
            expect(daily.first?.requests == 2, "daily.requests 는 2 이어야 합니다")
        } catch {
            expect(false, "저장에 실패했습니다: \(error)")
        }
    }

    test("여러 관측의 증가분이 누적된다") {
        do {
            let directory = makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try UsageStore(path: directory.appendingPathComponent("usage.sqlite"))
            let now = Date()

            _ = try await store.record(makeOverview(totalCost: 1, totalCount: 1, at: now), at: now)
            _ = try await store.record(makeOverview(totalCost: 3, totalCount: 3, at: now.addingTimeInterval(60)), at: now.addingTimeInterval(60))
            _ = try await store.record(makeOverview(totalCost: 6, totalCount: 6, at: now.addingTimeInterval(120)), at: now.addingTimeInterval(120))

            let daily = try await store.dailyUsage(days: 7)
            expect(daily.count == 1, "일별 집계는 1건이어야 합니다")
            // 첫 관측(1)이 baseline 이므로 1 이전 사용량은 알 수 없다.
            // 이후 1→3→6 증가분(2 + 3)만 기록된다.
            expectClose(daily.first?.spent ?? 0, 5, accuracy: 0.0001, "daily.spent")
            expect(daily.first?.requests == 5, "daily.requests 는 5 이어야 합니다")
        } catch {
            expect(false, "저장에 실패했습니다: \(error)")
        }
    }

    test("스냅샷이 저장된다") {
        do {
            let directory = makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try UsageStore(path: directory.appendingPathComponent("usage.sqlite"))
            let now = Date()
            _ = try await store.record(makeOverview(totalCost: 2.5, totalCount: 4, at: now), at: now)

            let snapshot = try await store.latestSnapshot()
            expect(snapshot != nil, "스냅샷이 있어야 합니다")
            expectClose(snapshot?.totalSpent ?? 0, 2.5, accuracy: 0.0001, "totalSpent")
            expect(snapshot?.totalCount == 4, "totalCount 는 4 이어야 합니다")
            expect(snapshot?.planId == "individual-goat", "planId 가 individual-goat 여야 합니다")
        } catch {
            expect(false, "조회에 실패했습니다: \(error)")
        }
    }

    test("히스토리를 지울 수 있다") {
        do {
            let directory = makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try UsageStore(path: directory.appendingPathComponent("usage.sqlite"))
            let now = Date()
            _ = try await store.record(makeOverview(totalCost: 2, totalCount: 2, at: now), at: now)
            expect(try await store.dailyUsage(days: 7).isEmpty == false, "기록이 있어야 합니다")

            try await store.resetHistory()
            expect(try await store.dailyUsage(days: 7).isEmpty, "비워져야 합니다")
            expect(try await store.latestSnapshot() == nil, "스냅샷도 없어야 합니다")
        } catch {
            expect(false, "초기화에 실패했습니다: \(error)")
        }
    }

    test("DB 파일은 소유자만 읽을 수 있게 만든다") {
        do {
            let directory = makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let path = directory.appendingPathComponent("usage.sqlite")
            let store = try UsageStore(path: path)
            let now = Date()
            _ = try await store.record(makeOverview(totalCost: 1, totalCount: 1, at: now), at: now)

            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
            let permissions = attributes[.posixPermissions] as? NSNumber
            expect(permissions?.int16Value == 0o600, "권한이 600 이어야 합니다")
        } catch {
            expect(false, "검증에 실패했습니다: \(error)")
        }
    }

    test("일별 조회는 요청한 기간 밖의 기록을 제외한다") {
        do {
            let directory = makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try UsageStore(path: directory.appendingPathComponent("usage.sqlite"))
            let now = Date()
            let longAgo = now.addingTimeInterval(-10 * 24 * 3600)

            _ = try await store.record(makeOverview(totalCost: 1, totalCount: 1, at: longAgo), at: longAgo)
            _ = try await store.record(makeOverview(totalCost: 2, totalCount: 2, at: now), at: now)

            let recent = try await store.dailyUsage(days: 7)
            expect(recent.count == 1, "최근 7일만 남아야 합니다")
            expect(recent.first?.day != dayKey(longAgo), "오래된 날짜는 제외되어야 합니다")
        } catch {
            expect(false, "조회에 실패했습니다: \(error)")
        }
    }

    test("오래된 기록은 하루에 한 번 정리된다") {
        do {
            let directory = makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try UsageStore(path: directory.appendingPathComponent("usage.sqlite"))
            let pruneKey = "usage-store-tests-\(UUID().uuidString).lastPrunedAt"
            let defaults = UserDefaults.standard
            defer { defaults.removeObject(forKey: pruneKey) }

            let now = Date()
            let longAgo = now.addingTimeInterval(-40 * 24 * 3600)
            _ = try await store.record(makeOverview(totalCost: 1, totalCount: 1, at: longAgo), at: longAgo)

            try await store.pruneIfNeeded(now: now, defaults: defaults, key: pruneKey)
            let afterPrune = try await store.latestSnapshot()
            expect(afterPrune == nil, "40일 지난 스냅샷은 제거되어야 합니다")

            // 같은 날 다시 호출해도 정리만 반복하지 않는다.
            try await store.pruneIfNeeded(now: now.addingTimeInterval(60), defaults: defaults, key: pruneKey)
        } catch {
            expect(false, "정리에 실패했습니다: \(error)")
        }
    }
}

/// 로컬 날짜 키(yyyy-MM-dd)
private func dayKey(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

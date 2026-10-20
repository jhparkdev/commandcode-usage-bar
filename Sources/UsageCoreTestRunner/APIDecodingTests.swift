import Foundation
@testable import UsageCore

func registerAPIDecodingTests() {
    test("크레딧과 사용 한도를 읽는다") {
        do {
            let response = try JSONDecoder().decode(CreditsResponse.self, from: Data(APIDecodingFixtures.creditsJSON.utf8))

            expectClose(response.credits?.monthlyCredits ?? 0, 68.3939255104, accuracy: 0.0001, "monthlyCredits")
            expect(response.credits?.planId == "individual-goat", "planId 가 individual-goat 여야 합니다")

            guard let fiveHour = response.limits?.fiveHour?.asDomain() else {
                expect(false, "fiveHour 한도가 있어야 합니다")
                return
            }
            expectClose(fiveHour.used, 1.6060744896, accuracy: 0.0001, "fiveHour.used")
            expectClose(fiveHour.cap, 14, accuracy: 0.0001, "fiveHour.cap")
            expect(fiveHour.exceeded == false, "fiveHour.exceeded 가 false 여야 합니다")

            // resetAt 은 epoch 밀리초
            let expected = Date(timeIntervalSince1970: 1_792_480_066.091)
            expectClose(fiveHour.resetAt?.timeIntervalSince1970 ?? 0, expected.timeIntervalSince1970, accuracy: 0.001, "resetAt")
        } catch {
            expect(false, "디코딩이 실패했습니다: \(error)")
        }
    }

    test("구독 기간을 읽는다") {
        do {
            let response = try JSONDecoder().decode(SubscriptionResponse.self, from: Data(APIDecodingFixtures.subscriptionJSON.utf8))
            expect(response.data?.planId == "individual-goat", "planId 가 individual-goat 여야 합니다")
            expect(response.data?.status == "active", "status 가 active 여야 합니다")
            expect(response.data?.currentPeriodStart != nil, "currentPeriodStart 가 있어야 합니다")
            expect(response.data?.currentPeriodEnd != nil, "currentPeriodEnd 가 있어야 합니다")
        } catch {
            expect(false, "디코딩이 실패했습니다: \(error)")
        }
    }

    test("사용량 요약을 읽는다") {
        do {
            let response = try JSONDecoder().decode(UsageSummaryResponse.self, from: Data(APIDecodingFixtures.summaryJSON.utf8))
            let summary = response.asDomain()
            expect(summary.totalCount == 419, "totalCount 가 419 여야 합니다")
            expect(summary.totalTokensIn == 35_846_791, "totalTokensIn 이 35,846,791 이어야 합니다")
            expectClose(summary.totalCost, 1.5589734804, accuracy: 0.0001, "totalCost")
        } catch {
            expect(false, "디코딩이 실패했습니다: \(error)")
        }
    }

    test("숫자가 문자열로 내려와도 읽는다") {
        do {
            let json = """
            { "credits": { "monthlyCredits": "12.5", "planId": "individual-goat" },
              "windowLimits": { "fiveHour": { "used": "3", "cap": "14" } } }
            """
            let response = try JSONDecoder().decode(CreditsResponse.self, from: Data(json.utf8))
            expectClose(response.credits?.monthlyCredits ?? 0, 12.5, accuracy: 0.0001, "monthlyCredits")
            expectClose(response.limits?.fiveHour?.asDomain().used ?? 0, 3, accuracy: 0.0001, "used")
        } catch {
            expect(false, "디코딩이 실패했습니다: \(error)")
        }
    }

    test("응답들을 합쳐 하나의 사용량으로 만든다") {
        do {
            let session = makeSession()
            MockURLProtocol.handler = { request in
                let path = request.url?.path ?? ""
                switch path {
                case "/alpha/whoami":
                    return (jsonResponse(url: request.url), Data(APIDecodingFixtures.whoamiJSON.utf8))
                case "/alpha/billing/credits":
                    return (jsonResponse(url: request.url), Data(APIDecodingFixtures.creditsJSON.utf8))
                case "/alpha/billing/subscriptions":
                    return (jsonResponse(url: request.url), Data(APIDecodingFixtures.subscriptionJSON.utf8))
                case "/alpha/usage/summary":
                    return (jsonResponse(url: request.url), Data(APIDecodingFixtures.summaryJSON.utf8))
                default:
                    return (jsonResponse(url: request.url, status: 404), Data())
                }
            }
            defer { MockURLProtocol.handler = nil }

            let client = CommandCodeAPIClient(baseURL: URL(string: "https://api.example.test")!, session: session)
            let overview = try await client.fetchOverview(apiKey: "test-key")

            expect(overview.user?.userName == "tester", "userName 이 tester 여야 합니다")
            expect(overview.org?.id == "org-1", "org.id 가 org-1 여야 합니다")
            expect(overview.planId == "individual-goat", "planId 가 individual-goat 여야 합니다")
            expect(overview.planTotalCredits == 70, "GOAT 플랜 총 크레딧은 70 이어야 합니다")
            expectClose(overview.monthlyCredits ?? 0, 68.3939255104, accuracy: 0.0001, "monthlyCredits")
            expectClose(overview.limits?.fiveHour?.cap ?? 0, 14, accuracy: 0.0001, "fiveHour.cap")
            expect(overview.summary?.totalCount == 419, "summary.totalCount 가 419 여야 합니다")
            expect(overview.warnings.isEmpty, "경고가 없어야 합니다")
        } catch {
            expect(false, "조회가 실패했습니다: \(error)")
        }
    }

    test("401 이면 인증 오류로 알린다") {
        do {
            let session = makeSession()
            MockURLProtocol.handler = { request in
                (jsonResponse(url: request.url, status: 401), Data())
            }
            defer { MockURLProtocol.handler = nil }

            let client = CommandCodeAPIClient(baseURL: URL(string: "https://api.example.test")!, session: session)
            do {
                _ = try await client.fetchOverview(apiKey: "bad-key")
                expect(false, "401 이면 실패해야 합니다")
            } catch let error as APIError {
                expect(error == .notAuthenticated, "notAuthenticated 여야 합니다")
            }
        } catch {
            expect(false, "예상하지 못한 오류: \(error)")
        }
    }

    test("요약 조회가 실패해도 나머지는 표시한다") {
        do {
            let session = makeSession()
            MockURLProtocol.handler = { request in
                let path = request.url?.path ?? ""
                switch path {
                case "/alpha/whoami":
                    return (jsonResponse(url: request.url), Data(APIDecodingFixtures.whoamiJSON.utf8))
                case "/alpha/billing/credits":
                    return (jsonResponse(url: request.url), Data(APIDecodingFixtures.creditsJSON.utf8))
                case "/alpha/billing/subscriptions":
                    return (jsonResponse(url: request.url), Data(APIDecodingFixtures.subscriptionJSON.utf8))
                default:
                    return (jsonResponse(url: request.url, status: 500), Data())
                }
            }
            defer { MockURLProtocol.handler = nil }

            let client = CommandCodeAPIClient(baseURL: URL(string: "https://api.example.test")!, session: session)
            let overview = try await client.fetchOverview(apiKey: "test-key")

            expect(overview.summary == nil, "요약이 없어야 합니다")
            expect(!overview.warnings.isEmpty, "경고가 기록되어야 합니다")
            expectClose(overview.monthlyCredits ?? 0, 68.3939255104, accuracy: 0.0001, "monthlyCredits")
        } catch {
            expect(false, "조회가 실패했습니다: \(error)")
        }
    }
}

// MARK: - 픽스처/헬퍼

private enum APIDecodingFixtures {
    static let whoamiJSON = """
    { "user": { "id": "u1", "name": "테스터", "email": "t@example.com", "userName": "tester" },
      "org": { "id": "org-1", "name": "Logbase", "login": "logbase" } }
    """

    static let creditsJSON = """
    {
      "credits": { "monthlyCredits": 68.3939255104, "purchasedCredits": 0, "freeCredits": 0, "planId": "individual-goat" },
      "windowLimits": {
        "fiveHour": { "used": 1.6060744896, "cap": 14, "exceeded": false, "resetAt": 1792480066091 },
        "weekly": { "used": 1.6060744896, "cap": 35, "exceeded": false, "resetAt": 1793066866091 }
      }
    }
    """

    static let subscriptionJSON = """
    { "data": { "planId": "individual-goat", "status": "active",
      "currentPeriodStart": "2026-10-20T02:04:33.000Z", "currentPeriodEnd": "2026-11-20T02:04:33.000Z" } }
    """

    static let summaryJSON = """
    { "totalCount": 419, "totalTokensIn": 35846791, "totalTokensOut": 353482,
      "totalCredits": 1.5589734804, "totalCost": 1.5589734804, "averageCost": 0.0037207, "successRate": 100 }
    """
}

private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}

private func jsonResponse(url: URL?, status: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(url: url ?? URL(string: "https://api.example.test")!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
}

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

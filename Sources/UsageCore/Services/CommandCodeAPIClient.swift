import Foundation

public enum APIError: LocalizedError, Equatable {
    case notAuthenticated
    case rateLimited(retryAfter: TimeInterval?)
    case server(status: Int)
    case network(String)
    case contractChanged(String)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "인증이 만료되었습니다. Command Code 앱에서 다시 로그인해 주세요."
        case .rateLimited:
            return "요청이 일시적으로 제한되었습니다. 잠시 후 다시 시도합니다."
        case .server(let status):
            return "Command Code 서버 오류 (HTTP \(status))"
        case .network(let message):
            return "네트워크 오류: \(message)"
        case .contractChanged:
            return "Command Code API 응답 형식이 변경되었습니다. 앱 업데이트가 필요할 수 있습니다."
        case .invalidConfiguration(let message):
            return message
        }
    }
}

/// Command Code 내부(alpha) 사용량 API 클라이언트.
///
/// 계약을 이 한 곳에 격리한다. 엔드포인트나 필드가 바뀌면 이 파일과 픽스처만 수정하면 된다.
public struct CommandCodeAPIClient: Sendable {
    public static let defaultBaseURL = URL(string: "https://api.commandcode.ai")!

    public var baseURL: URL
    public var timeout: TimeInterval
    public var userAgent: String
    public var commandCodeVersion: String?

    private let session: URLSession

    public init(
        baseURL: URL = CommandCodeAPIClient.defaultBaseURL,
        timeout: TimeInterval = 10,
        userAgent: String = "CommandCodeUsageBar",
        commandCodeVersion: String? = nil,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.userAgent = userAgent
        self.commandCodeVersion = commandCodeVersion
        self.session = session
    }

    /// whoami → credits/subscription → usage summary 순서로 조회한다.
    /// 일부 호출이 실패해도 나머지는 살려 두고 `warnings` 로 보고한다.
    public func fetchOverview(apiKey: String) async throws -> UsageOverview {
        var warnings: [String] = []

        let whoami: WhoAmIResponse
        do {
            whoami = try await get("/alpha/whoami", query: [URLQueryItem(name: "limits", value: "1")], apiKey: apiKey)
        } catch let error as APIError {
            if error == .notAuthenticated { throw error }
            warnings.append("계정 조회 실패: \(error.localizedDescription)")
            return try await fetchWithoutIdentity(
                apiKey: apiKey,
                orgId: nil,
                warnings: warnings
            )
        } catch {
            warnings.append("계정 조회 실패: \(error.localizedDescription)")
            return try await fetchWithoutIdentity(apiKey: apiKey, orgId: nil, warnings: warnings)
        }

        let orgId = whoami.org?.id
        return try await fetchWithoutIdentity(apiKey: apiKey, orgId: orgId, warnings: warnings, identity: whoami)
    }

    private func fetchWithoutIdentity(
        apiKey: String,
        orgId: String?,
        warnings: [String],
        identity: WhoAmIResponse? = nil
    ) async throws -> UsageOverview {
        var warnings = warnings
        let orgQuery: [URLQueryItem] = orgId.map { [URLQueryItem(name: "orgId", value: $0)] } ?? []

        async let creditsResult: Result<CreditsResponse, Error> = getResult("/alpha/billing/credits", query: orgQuery, apiKey: apiKey)
        async let subscriptionResult: Result<SubscriptionResponse, Error> = getResult("/alpha/billing/subscriptions", query: orgQuery, apiKey: apiKey)
        let (credits, subscription) = await (creditsResult, subscriptionResult)

        var creditsResponse: CreditsResponse?
        switch credits {
        case .success(let value):
            creditsResponse = value
        case .failure(let error):
            if isAuthFailure(error) { throw error }
            warnings.append("크레딧 조회 실패: \(error.localizedDescription)")
        }

        var subscriptionResponse: SubscriptionResponse?
        switch subscription {
        case .success(let value):
            subscriptionResponse = value
        case .failure(let error):
            if isAuthFailure(error) { throw error }
            warnings.append("구독 조회 실패: \(error.localizedDescription)")
        }

        let periodStart = subscriptionResponse?.data?.currentPeriodStart
        var summaryResponse: UsageSummaryResponse?
        if let periodStart {
            let query = orgQuery + [URLQueryItem(name: "since", value: ISO8601.shared.string(from: periodStart))]
            switch await getResult("/alpha/usage/summary", query: query, apiKey: apiKey) as Result<UsageSummaryResponse, Error> {
            case .success(let value):
                summaryResponse = value
            case .failure(let error):
                if isAuthFailure(error) { throw error }
                warnings.append("사용량 요약 실패: \(error.localizedDescription)")
            }
        } else {
            warnings.append("구독 기간을 확인할 수 없어 사용량 요약은 건너뛰었습니다.")
        }

        let planId = creditsResponse?.credits?.planId ?? subscriptionResponse?.data?.planId
        let overview = UsageOverview(
            user: identity?.user.map { UserInfo(id: $0.id, name: $0.name, email: $0.email, userName: $0.userName) },
            org: identity?.org.map { OrgInfo(id: $0.id, name: $0.name, login: $0.login) },
            planId: planId,
            subscriptionStatus: subscriptionResponse?.data?.status,
            periodStart: periodStart,
            periodEnd: subscriptionResponse?.data?.currentPeriodEnd,
            monthlyCredits: creditsResponse?.credits?.monthlyCredits,
            purchasedCredits: creditsResponse?.credits?.purchasedCredits,
            freeCredits: creditsResponse?.credits?.freeCredits,
            planTotalCredits: PlanCatalog.total(for: planId),
            limits: creditsResponse?.limits.map { $0.asDomain() },
            summary: summaryResponse?.asDomain(),
            warnings: warnings,
            fetchedAt: Date()
        )

        if overview.monthlyCredits == nil && overview.limits == nil && overview.summary == nil {
            throw APIError.contractChanged("사용량 정보를 확인할 수 없습니다.")
        }
        return overview
    }

    private func isAuthFailure(_ error: Error) -> Bool {
        if let apiError = error as? APIError, apiError == .notAuthenticated { return true }
        if error is AuthError { return true }
        return false
    }

    private func getResult<T: Decodable>(
        _ path: String,
        query: [URLQueryItem],
        apiKey: String
    ) async -> Result<T, Error> {
        do {
            return .success(try await get(path, query: query, apiKey: apiKey))
        } catch {
            return .failure(error)
        }
    }

    private func get<T: Decodable>(
        _ path: String,
        query: [URLQueryItem],
        apiKey: String
    ) async throws -> T {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidConfiguration("잘못된 API 주소입니다: \(baseURL.absoluteString)")
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else {
            throw APIError.invalidConfiguration("잘못된 API 주소입니다: \(baseURL.absoluteString)")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let version = commandCodeVersion, !version.isEmpty {
            request.setValue(version, forHTTPHeaderField: "x-command-code-version")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("HTTP 응답이 아닙니다.")
        }
        switch http.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw APIError.notAuthenticated
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            throw APIError.server(status: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.contractChanged(String(describing: error))
        }
    }
}

// MARK: - 응답 DTO

struct WhoAmIResponse: Decodable {
    let user: UserDTO?
    let org: OrgDTO?

    enum CodingKeys: String, CodingKey {
        case user, org
    }

    struct UserDTO: Decodable {
        let id: String?
        let name: String?
        let email: String?
        let userName: String?

        enum CodingKeys: String, CodingKey {
            case id, name, email, userName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.lossyString(forKey: .id)
            name = try container.lossyString(forKey: .name)
            email = try container.lossyString(forKey: .email)
            userName = try container.lossyString(forKey: .userName)
        }
    }

    struct OrgDTO: Decodable {
        let id: String?
        let name: String?
        let login: String?

        enum CodingKeys: String, CodingKey {
            case id, name, login
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.lossyString(forKey: .id)
            name = try container.lossyString(forKey: .name)
            login = try container.lossyString(forKey: .login)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decodeIfPresent(UserDTO.self, forKey: .user)
        org = try container.decodeIfPresent(OrgDTO.self, forKey: .org)
    }
}

struct CreditsResponse: Decodable {
    struct CreditsDTO: Decodable {
        let monthlyCredits: Double?
        let purchasedCredits: Double?
        let freeCredits: Double?
        let planId: String?
        let belowThreshold: Bool?
        let creditThreshold: Double?

        enum CodingKeys: String, CodingKey {
            case monthlyCredits, purchasedCredits, freeCredits, planId, belowThreshold, creditThreshold
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            monthlyCredits = try container.lossyDouble(forKey: .monthlyCredits)
            purchasedCredits = try container.lossyDouble(forKey: .purchasedCredits)
            freeCredits = try container.lossyDouble(forKey: .freeCredits)
            planId = try container.lossyString(forKey: .planId)
            belowThreshold = try container.lossyBool(forKey: .belowThreshold)
            creditThreshold = try container.lossyDouble(forKey: .creditThreshold)
        }
    }

    struct LimitDTO: Decodable {
        let used: Double?
        let cap: Double?
        let exceeded: Bool?
        let resetAt: Double?

        enum CodingKeys: String, CodingKey {
            case used, cap, exceeded, resetAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            used = try container.lossyDouble(forKey: .used)
            cap = try container.lossyDouble(forKey: .cap)
            exceeded = try container.lossyBool(forKey: .exceeded)
            resetAt = try container.lossyDouble(forKey: .resetAt)
        }

        func asDomain() -> UsageLimit {
            UsageLimit(
                used: used ?? 0,
                cap: cap ?? 0,
                exceeded: exceeded ?? false,
                resetAt: resetAt.map { Date(timeIntervalSince1970: $0 > 1_000_000_000_000 ? $0 / 1000 : $0) }
            )
        }
    }

    struct LimitsDTO: Decodable {
        let limited: Bool?
        let exceeded: Bool?
        let fiveHour: LimitDTO?
        let weekly: LimitDTO?
        let daily: LimitDTO?

        enum CodingKeys: String, CodingKey {
            case limited, exceeded, fiveHour, weekly, daily
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            limited = try container.lossyBool(forKey: .limited)
            exceeded = try container.lossyBool(forKey: .exceeded)
            fiveHour = try container.decodeIfPresent(LimitDTO.self, forKey: .fiveHour)
            weekly = try container.decodeIfPresent(LimitDTO.self, forKey: .weekly)
            daily = try container.decodeIfPresent(LimitDTO.self, forKey: .daily)
        }

        func asDomain() -> LimitSet {
            LimitSet(
                limited: limited ?? false,
                exceeded: exceeded,
                fiveHour: fiveHour?.asDomain(),
                weekly: weekly?.asDomain(),
                daily: daily?.asDomain()
            )
        }
    }

    let credits: CreditsDTO?
    /// API 의 `windowLimits` 필드. 도메인 용어와 맞추기 위해 `limits` 로 부른다.
    let limits: LimitsDTO?

    enum CodingKeys: String, CodingKey {
        case credits
        case limits = "windowLimits"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        credits = try container.decodeIfPresent(CreditsDTO.self, forKey: .credits)
        limits = try container.decodeIfPresent(LimitsDTO.self, forKey: .limits)
    }
}

struct SubscriptionResponse: Decodable {
    struct SubscriptionDTO: Decodable {
        let planId: String?
        let status: String?
        let currentPeriodStart: Date?
        let currentPeriodEnd: Date?

        enum CodingKeys: String, CodingKey {
            case planId, status, currentPeriodStart, currentPeriodEnd
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            planId = try container.lossyString(forKey: .planId)
            status = try container.lossyString(forKey: .status)
            currentPeriodStart = try container.lossyString(forKey: .currentPeriodStart).flatMap(ISO8601.shared.date(from:))
            currentPeriodEnd = try container.lossyString(forKey: .currentPeriodEnd).flatMap(ISO8601.shared.date(from:))
        }
    }

    let data: SubscriptionDTO?

    enum CodingKeys: String, CodingKey {
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent(SubscriptionDTO.self, forKey: .data)
    }
}

struct UsageSummaryResponse: Decodable {
    let totalCount: Int?
    let completedCount: Int?
    let failedCount: Int?
    let totalTokensIn: Int?
    let totalTokensOut: Int?
    let totalTokens: Int?
    let totalCredits: Double?
    let totalCost: Double?
    let averageCost: Double?
    let successRate: Double?

    enum CodingKeys: String, CodingKey {
        case totalCount, completedCount, failedCount
        case totalTokensIn, totalTokensOut, totalTokens
        case totalCredits, totalCost, averageCost, successRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalCount = try container.lossyInt(forKey: .totalCount)
        completedCount = try container.lossyInt(forKey: .completedCount)
        failedCount = try container.lossyInt(forKey: .failedCount)
        totalTokensIn = try container.lossyInt(forKey: .totalTokensIn)
        totalTokensOut = try container.lossyInt(forKey: .totalTokensOut)
        totalTokens = try container.lossyInt(forKey: .totalTokens)
        totalCredits = try container.lossyDouble(forKey: .totalCredits)
        totalCost = try container.lossyDouble(forKey: .totalCost)
        averageCost = try container.lossyDouble(forKey: .averageCost)
        successRate = try container.lossyDouble(forKey: .successRate)
    }

    func asDomain() -> UsageSummary {
        UsageSummary(
            totalCount: totalCount ?? 0,
            completedCount: completedCount ?? 0,
            failedCount: failedCount ?? 0,
            totalTokensIn: totalTokensIn ?? 0,
            totalTokensOut: totalTokensOut ?? 0,
            totalTokens: totalTokens ?? 0,
            totalCredits: totalCredits ?? 0,
            totalCost: totalCost ?? 0,
            averageCost: averageCost ?? 0,
            successRate: successRate ?? 0
        )
    }
}

// MARK: - 느슨한 디코딩

extension KeyedDecodingContainer {
    func lossyDouble(forKey key: Key) throws -> Double? {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key),
           let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        return nil
    }

    func lossyInt(forKey key: Key) throws -> Int? {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(Double.self, forKey: key) { return Int(value) }
        if let value = try? decode(String.self, forKey: key),
           let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return Int(parsed)
        }
        return nil
    }

    func lossyBool(forKey key: Key) throws -> Bool? {
        if let value = try? decode(Bool.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key) {
            switch value.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        if let value = try? decode(Int.self, forKey: key) { return value != 0 }
        return nil
    }

    func lossyString(forKey key: Key) throws -> String? {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        if let value = try? decode(Bool.self, forKey: key) { return String(value) }
        return nil
    }
}

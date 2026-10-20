import Foundation

/// Command Code 플랜 메타데이터.
/// 실제 사용 한도(cap)는 서버가 알려주지만, "전체 몇 크레딧" 같은 표시는 여기 매핑을 쓴다.
public enum PlanCatalog {
    public static let totalCredits: [String: Double] = [
        "individual-go": 10,
        "individual-go-v1": 10,
        "individual-goat": 70,
        "individual-pro": 30,
        "individual-pro-v1": 80,
        "individual-provider": 15,
        "individual-max": 150,
        "individual-ultra": 300,
        "teams-pro": 40
    ]

    public static let names: [String: String] = [
        "individual-go": "Go",
        "individual-go-v1": "Go",
        "individual-goat": "GOAT",
        "individual-pro": "Pro",
        "individual-pro-v1": "Pro",
        "individual-provider": "Provider",
        "individual-max": "Max",
        "individual-ultra": "Ultra",
        "teams-pro": "Teams Pro"
    ]

    public static func name(for planId: String?) -> String? {
        guard let planId, !planId.isEmpty else { return nil }
        if let exact = names[planId] { return exact }
        // longest-first 접두 매칭 (individual-goat 가 individual-go 로 잡히지 않게)
        let match = names.keys
            .filter { planId.lowercased().hasPrefix($0.lowercased()) }
            .max(by: { $0.count < $1.count })
        return match.flatMap { names[$0] }
    }

    public static func total(for planId: String?) -> Double? {
        guard let planId, !planId.isEmpty else { return nil }
        if let exact = totalCredits[planId] { return exact }
        let match = totalCredits.keys
            .filter { planId.lowercased().hasPrefix($0.lowercased()) }
            .max(by: { $0.count < $1.count })
        return match.flatMap { totalCredits[$0] }
    }
}

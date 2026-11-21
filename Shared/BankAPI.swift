import Foundation

/// Typed read-only endpoints of the bank-tracking API. Space-scoped routes live under `/spaces/:spaceId`.
extension APIClient {
    func authStatus() async throws -> AuthStatus {
        try await get("/auth/status")
    }

    func login(email: String, password: String) async throws {
        try await post("/auth/login", body: LoginBody(email: email, password: password))
    }

    func logout() async throws {
        try await post("/auth/logout")
    }

    func health() async throws -> Health {
        try await get("/health")
    }

    func spaces() async throws -> [Space] {
        try await get("/spaces")
    }

    func accounts(space: String) async throws -> [Account] {
        try await get("/spaces/\(space)/accounts")
    }

    func categories(space: String) async throws -> [Category] {
        try await get("/spaces/\(space)/categories")
    }

    /// `categoryId` is a category id or "none" (uncategorized).
    func transactions(space: String, month: MonthKey, query: String, accountId: String?, categoryId: String?, page: Int) async throws -> TransactionPage {
        var params: [String: String] = ["month": month.key, "page": String(page), "pageSize": "50"]
        if !query.isEmpty { params["q"] = query }
        if let accountId: String = accountId { params["accountId"] = accountId }
        if let categoryId: String = categoryId { params["categoryId"] = categoryId }
        return try await get("/spaces/\(space)/transactions", query: params)
    }

    func monthSummary(space: String, month: MonthKey) async throws -> MonthSummary {
        try await get("/spaces/\(space)/stats/months/\(month.key)")
    }

    /// Oldest first, ending with `until`.
    func monthlyStats(space: String, months: Int, until: MonthKey) async throws -> [MonthlyStat] {
        try await get("/spaces/\(space)/stats/monthly", query: ["months": String(months), "until": until.key])
    }

    func goals(space: String) async throws -> [Goal] {
        try await get("/spaces/\(space)/goals")
    }

    func splitMonth(space: String, month: MonthKey) async throws -> SplitMonth {
        try await get("/spaces/\(space)/split/months/\(month.key)")
    }

    /// Saved months, most recent first.
    func splitHistory(space: String) async throws -> [SplitHistoryItem] {
        try await get("/spaces/\(space)/split/months")
    }
}

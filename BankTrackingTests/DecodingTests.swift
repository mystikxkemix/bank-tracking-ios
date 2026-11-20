import XCTest
@testable import BankTracking

/// Payloads shaped like the real API responses (see packages/shared/src/schemas in bank-tracking).
final class DecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testAuthStatusLoggedOut() throws {
        let status: AuthStatus = try decode(AuthStatus.self, #"{"configured":true,"user":null}"#)
        XCTAssertTrue(status.configured)
        XCTAssertNil(status.user)
    }

    func testMonthSummary() throws {
        let json: String = #"""
        {"month":"2026-11","incomeCents":560000,"expenseCents":312345,"netCents":247655,"savingsRate":0.44,
         "byCategory":[{"categoryId":null,"totalCents":-1200,"count":2},{"categoryId":"aaaaaaaaaaaaaaaaaaaaaaaa","totalCents":-50000,"count":4}],
         "budgets":[{"categoryId":"aaaaaaaaaaaaaaaaaaaaaaaa","monthlyLimitCents":40000,"spentCents":50000}],
         "uncategorizedCount":2}
        """#
        let summary: MonthSummary = try decode(MonthSummary.self, json)
        XCTAssertEqual(summary.netCents, 247_655)
        XCTAssertNil(summary.byCategory[0].categoryId)
        XCTAssertEqual(summary.budgets.first?.spentCents, 50_000)
    }

    func testTransactionPageWithNullables() throws {
        let json: String = #"""
        {"items":[{"id":"bbbbbbbbbbbbbbbbbbbbbbbb","accountId":"cccccccccccccccccccccccc","date":"2026-11-02","label":"Boulangerie",
          "rawLabel":"CB BOULANGERIE 02/11","amountCents":-450,"categoryId":null,"note":null,"importId":null,"createdAt":"2026-11-03T10:00:00.000Z"}],
         "total":1,"page":1,"pageSize":50}
        """#
        let page: TransactionPage = try decode(TransactionPage.self, json)
        XCTAssertEqual(page.items.first?.amountCents, -450)
        XCTAssertNil(page.items.first?.categoryId)
    }

    func testSplitMonthDraft() throws {
        let json: String = #"""
        {"month":"2026-11","saved":false,"copiedFrom":"2026-10",
         "plan":{"persons":[{"id":"p1","name":"Alex","sharePercent":60},{"id":"p2","name":"Sam","sharePercent":40}],
                 "incomes":[{"id":"i1","personId":"p1","label":"Salaire","amountCents":320000}],
                 "lines":[{"id":"l1","label":"Taxe foncière","kind":"charge","amountCents":130000,"frequency":"yearly"}],"note":null},
         "result":{"totalIncomeCents":320000,"monthlyChargesCents":10833,"monthlySavingsCents":0,"keepOnJointCents":10833,"provisionCents":10833,
                   "persons":[{"personId":"p1","incomeCents":320000,"contributionCents":6500,"returnCents":313500}]},
         "updatedAt":null}
        """#
        let split: SplitMonth = try decode(SplitMonth.self, json)
        XCTAssertFalse(split.saved)
        XCTAssertEqual(split.plan.persons[0].sharePercent, 60)
        XCTAssertEqual(split.result.persons[0].returnCents, 313_500)
    }

    func testGoalWithContributions() throws {
        let json: String = #"""
        [{"id":"dddddddddddddddddddddddd","name":"Vacances","targetCents":200000,"deadline":"2027-07-01","color":"teal","emoji":"🏖️",
          "contributions":[{"id":"eeeeeeeeeeeeeeeeeeeeeeee","date":"2026-11-01","amountCents":-5000,"note":"retrait"}],
          "savedCents":45000,"createdAt":"2026-01-01T00:00:00.000Z"}]
        """#
        let goals: [Goal] = try decode([Goal].self, json)
        XCTAssertEqual(goals.first?.contributions.first?.amountCents, -5_000)
    }

    func testErrorPayload() throws {
        let payload: APIErrorPayload = try decode(APIErrorPayload.self, #"{"error":{"code":"unauthorized","message":"Connexion requise"}}"#)
        XCTAssertEqual(payload.error.message, "Connexion requise")
    }

    func testClientBuildsUrlsWithPrefix() {
        let client: APIClient = APIClient(baseURL: URL(string: "https://exemple.fr/comptes/")!)
        let url: URL = client.url("/spaces/x/transactions", query: ["month": "2026-11", "q": "café crème"])
        XCTAssertEqual(url.absoluteString, "https://exemple.fr/comptes/api/spaces/x/transactions?month=2026-11&q=caf%C3%A9%20cr%C3%A8me")
    }

    func testParseServerDefaultsToHttps() {
        XCTAssertEqual(SessionStore.parseServer("comptes.exemple.fr")?.absoluteString, "https://comptes.exemple.fr")
        XCTAssertEqual(SessionStore.parseServer(" http://localhost:8095 ")?.absoluteString, "http://localhost:8095")
        XCTAssertNil(SessionStore.parseServer("ftp://x"))
        XCTAssertNil(SessionStore.parseServer(""))
    }
}

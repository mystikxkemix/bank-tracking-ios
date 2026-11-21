import XCTest
@testable import BankTracking

final class WidgetSnapshotTests: XCTestCase {
    private func summary(budgets: [BudgetStatus], net: Int = 188_781) -> MonthSummary {
        MonthSummary(month: "2026-10", incomeCents: 562_340, expenseCents: 373_559, netCents: net, savingsRate: 0.34,
                     byCategory: [], budgets: budgets, uncategorizedCount: 0)
    }

    func testBudgetLeftSumsAllBudgets() {
        let snapshot: WidgetSnapshot = WidgetSnapshot(summary: summary(budgets: [
            BudgetStatus(categoryId: "a", monthlyLimitCents: 60_000, spentCents: 40_550),
            BudgetStatus(categoryId: "b", monthlyLimitCents: 10_000, spentCents: 18_990),
        ]), spaceName: "Foyer")
        // (60 000 + 10 000) - (40 550 + 18 990): an overspent budget eats into the others.
        XCTAssertEqual(snapshot.budgetLeftCents, 10_460)
        XCTAssertEqual(snapshot.savingsCents, 188_781)
        XCTAssertEqual(snapshot.month, "2026-10")
    }

    func testOverspentTotalIsNegative() {
        let snapshot: WidgetSnapshot = WidgetSnapshot(summary: summary(budgets: [
            BudgetStatus(categoryId: "a", monthlyLimitCents: 10_000, spentCents: 12_500),
        ]), spaceName: "Foyer")
        XCTAssertEqual(snapshot.budgetLeftCents, -2_500)
    }

    func testNoBudgetGivesNil() {
        XCTAssertNil(WidgetSnapshot(summary: summary(budgets: []), spaceName: "Foyer").budgetLeftCents)
    }

    func testSnapshotRoundTripsThroughJson() throws {
        let snapshot: WidgetSnapshot = WidgetSnapshot(month: "2026-11", spaceName: "Foyer", savingsCents: -1_200, budgetLeftCents: nil,
                                                      updatedAt: Date(timeIntervalSince1970: 1_795_000_000))
        let data: Data = try JSONEncoder().encode(snapshot)
        XCTAssertEqual(try JSONDecoder().decode(WidgetSnapshot.self, from: data), snapshot)
    }
}

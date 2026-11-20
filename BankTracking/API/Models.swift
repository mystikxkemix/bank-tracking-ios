import Foundation

// Swift mirrors of the zod schemas in bank-tracking `packages/shared/src/schemas/*`.
// Field names match the JSON exactly (camelCase), so the default decoder needs no key mapping.
// Money is always integer cents (`Int`), never a floating point amount.

struct CurrentUser: Decodable, Equatable {
    let id: String
    let email: String
    let name: String
    let isAdmin: Bool
}

struct AuthStatus: Decodable {
    /// false until the first (admin) user has been created on the website.
    let configured: Bool
    /// nil when not logged in.
    let user: CurrentUser?
}

struct LoginBody: Encodable {
    let email: String
    let password: String
}

struct Health: Decodable {
    let ok: Bool
    let version: String?
}

struct Space: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    /// "owner", "editor" or "viewer".
    let role: String
    let memberCount: Int
    let createdAt: String
}

struct Account: Decodable, Identifiable {
    let id: String
    let name: String
    /// "checking", "savings" or "other".
    let kind: String
    let currency: String
    let transactionCount: Int
    let balanceCents: Int
}

struct Category: Decodable, Identifiable {
    let id: String
    let name: String
    /// "expense", "income" or "transfer" (transfers are excluded from stats).
    let kind: String
    /// Radix Themes color name, mapped by `CategoryColor`.
    let color: String
    let emoji: String?
}

struct Transaction: Decodable, Identifiable {
    let id: String
    let accountId: String
    /// Calendar day "YYYY-MM-DD".
    let date: String
    let label: String
    let rawLabel: String
    let amountCents: Int
    let categoryId: String?
    let note: String?
}

struct TransactionPage: Decodable {
    let items: [Transaction]
    let total: Int
    let page: Int
    let pageSize: Int
}

struct MonthlyStat: Decodable, Identifiable {
    /// "YYYY-MM".
    let month: String
    let incomeCents: Int
    /// Positive number.
    let expenseCents: Int
    let netCents: Int
    /// netCents / incomeCents, nil without income. Can be negative.
    let savingsRate: Double?

    var id: String { month }
}

struct CategoryTotal: Decodable {
    /// nil = uncategorized.
    let categoryId: String?
    /// Signed sum (expenses negative).
    let totalCents: Int
    let count: Int
}

struct BudgetStatus: Decodable {
    let categoryId: String
    let monthlyLimitCents: Int
    /// Positive number.
    let spentCents: Int
}

struct MonthSummary: Decodable {
    let month: String
    let incomeCents: Int
    let expenseCents: Int
    let netCents: Int
    let savingsRate: Double?
    let byCategory: [CategoryTotal]
    let budgets: [BudgetStatus]
    let uncategorizedCount: Int
}

struct Contribution: Decodable, Identifiable {
    let id: String
    let date: String
    /// Negative for a withdrawal.
    let amountCents: Int
    let note: String?
}

struct Goal: Decodable, Identifiable {
    let id: String
    let name: String
    let targetCents: Int
    let deadline: String?
    let color: String
    let emoji: String?
    /// Sorted by date descending.
    let contributions: [Contribution]
    let savedCents: Int
}

struct SplitPerson: Decodable, Identifiable {
    let id: String
    let name: String
    let sharePercent: Double
}

struct SplitIncome: Decodable, Identifiable {
    let id: String
    let personId: String
    let label: String
    let amountCents: Int
}

struct SplitLine: Decodable, Identifiable {
    let id: String
    let label: String
    /// "charge" or "savings".
    let kind: String
    /// Amount per occurrence.
    let amountCents: Int
    /// "monthly", "quarterly" or "yearly".
    let frequency: String
}

struct SplitPlan: Decodable {
    let persons: [SplitPerson]
    let incomes: [SplitIncome]
    let lines: [SplitLine]
    let note: String?
}

struct SplitPersonResult: Decodable {
    let personId: String
    let incomeCents: Int
    let contributionCents: Int
    /// Negative = the person must top up the joint account.
    let returnCents: Int
}

struct SplitResult: Decodable {
    let totalIncomeCents: Int
    let monthlyChargesCents: Int
    let monthlySavingsCents: Int
    let keepOnJointCents: Int
    let provisionCents: Int
    let persons: [SplitPersonResult]
}

struct SplitMonth: Decodable {
    let month: String
    /// false = not saved yet: the plan is a copy of the latest saved month (or empty).
    let saved: Bool
    let copiedFrom: String?
    let plan: SplitPlan
    let result: SplitResult
    let updatedAt: String?
}

struct SplitHistoryPerson: Decodable {
    let personId: String
    let name: String
    let returnCents: Int
}

struct SplitHistoryItem: Decodable, Identifiable {
    let month: String
    let keepOnJointCents: Int
    let totalIncomeCents: Int
    let persons: [SplitHistoryPerson]

    var id: String { month }
}

/// Error payload returned by every failing API call: `{ "error": { "code", "message" } }`.
struct APIErrorPayload: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
    }

    let error: Body
}

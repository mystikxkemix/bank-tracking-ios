import Charts
import SwiftUI

struct DashboardView: View {
    @Environment(SessionStore.self) private var session: SessionStore
    @State private var month: MonthKey = MonthKey.initial
    @State private var state: LoadState<Dashboard> = .loading

    struct Dashboard {
        let summary: MonthSummary
        /// Last 6 months, oldest first.
        let history: [MonthlyStat]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthSwitcher(month: $month)
                }
                LoadView(state: state, retry: load) { (dashboard: Dashboard) in
                    content(dashboard)
                }
            }
            .navigationTitle(session.selectedSpace?.name ?? "Accueil")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SpaceMenuButton() } }
            .refreshable { await load() }
            .task(id: "\(session.selectedSpaceId ?? "")-\(month.key)") { await load() }
        }
    }

    @ViewBuilder
    private func content(_ dashboard: Dashboard) -> some View {
        let summary: MonthSummary = dashboard.summary
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Épargne du mois")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Money.format(summary.netCents, signed: true))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(summary.netCents >= 0 ? Color.green : Color.red)
                if let rate: Double = summary.savingsRate {
                    Text("\(Money.percent(rate)) de tes revenus")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            HStack {
                StatTile(title: "Revenus", cents: summary.incomeCents, systemImage: "arrow.down.circle", tint: .green)
                StatTile(title: "Dépenses", cents: summary.expenseCents, systemImage: "arrow.up.circle", tint: .orange)
            }
            if summary.uncategorizedCount > 0 {
                Label("\(summary.uncategorizedCount) transaction\(summary.uncategorizedCount > 1 ? "s" : "") à catégoriser sur le site", systemImage: "tag")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }

        if dashboard.history.count > 1 {
            Section("6 derniers mois") {
                HistoryChart(history: dashboard.history)
                    .frame(height: 180)
                    .padding(.vertical, 6)
            }
        }

        let expenses: [CategoryTotal] = topExpenses(summary.byCategory)
        if !expenses.isEmpty {
            Section("Dépenses par catégorie") {
                let largest: Int = expenses.map { (total: CategoryTotal) -> Int in -total.totalCents }.max() ?? 1
                ForEach(expenses, id: \.categoryId) { (total: CategoryTotal) in
                    CategorySpendRow(category: session.category(total.categoryId), cents: -total.totalCents, largest: largest)
                }
            }
        }

        if !session.accounts.isEmpty {
            Section("Comptes") {
                ForEach(session.accounts) { (account: Account) in
                    HStack {
                        Image(systemName: account.kind == "savings" ? "banknote" : "creditcard")
                            .foregroundStyle(.tint)
                            .frame(width: 28)
                        Text(account.name)
                        Spacer()
                        Text(Money.format(account.balanceCents))
                            .monospacedDigit()
                            .foregroundStyle(account.balanceCents < 0 ? Color.red : Color.primary)
                    }
                }
            }
        }
    }

    /// Expense categories only (transfers are not spending), biggest first.
    private func topExpenses(_ totals: [CategoryTotal]) -> [CategoryTotal] {
        var result: [CategoryTotal] = []
        for total in totals where total.totalCents < 0 {
            if session.category(total.categoryId)?.kind == "transfer" { continue }
            result.append(total)
        }
        result.sort { (left: CategoryTotal, right: CategoryTotal) -> Bool in left.totalCents < right.totalCents }
        return Array(result.prefix(8))
    }

    private func load() async {
        guard let client: APIClient = session.client, let space: String = session.selectedSpaceId else { return }
        if state.value == nil { state = .loading }
        do {
            async let summary: MonthSummary = client.monthSummary(space: space, month: month)
            async let history: [MonthlyStat] = client.monthlyStats(space: space, months: 6, until: month)
            state = .loaded(Dashboard(summary: try await summary, history: try await history))
        } catch is CancellationError {
            return
        } catch {
            state = .failed(session.handle(error))
        }
    }
}

private struct StatTile: View {
    let title: String
    let cents: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
            Text(Money.format(cents))
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CategorySpendRow: View {
    let category: Category?
    /// Positive amount spent.
    let cents: Int
    let largest: Int

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: category)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category?.name ?? "Sans catégorie")
                    Spacer()
                    Text(Money.format(cents)).monospacedDigit()
                }
                ProgressView(value: Double(cents), total: Double(max(largest, 1)))
                    .tint(CategoryColor.color(category?.color ?? "gray"))
            }
        }
    }
}

private struct HistoryChart: View {
    let history: [MonthlyStat]

    var body: some View {
        Chart {
            ForEach(history) { (stat: MonthlyStat) in
                let label: String = MonthKey(stat.month)?.shortTitle ?? stat.month
                BarMark(x: .value("Mois", label), y: .value("Montant", Double(stat.incomeCents) / 100))
                    .foregroundStyle(by: .value("Type", "Revenus"))
                    .position(by: .value("Type", "Revenus"))
                BarMark(x: .value("Mois", label), y: .value("Montant", Double(stat.expenseCents) / 100))
                    .foregroundStyle(by: .value("Type", "Dépenses"))
                    .position(by: .value("Type", "Dépenses"))
            }
        }
        .chartForegroundStyleScale(["Revenus": Color.green, "Dépenses": Color.orange])
        .chartYAxis {
            AxisMarks { (value: AxisValue) in
                AxisGridLine()
                AxisValueLabel {
                    if let euros: Double = value.as(Double.self) {
                        Text("\(Int(euros / 1000)) k€")
                    }
                }
            }
        }
    }
}

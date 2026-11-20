import SwiftUI

struct BudgetsGoalsView: View {
    enum Segment: String {
        case budgets, goals
    }

    @State private var segment: Segment = Segment(rawValue: DebugLaunch.segment ?? "") ?? .budgets

    var body: some View {
        NavigationStack {
            Group {
                switch segment {
                case .budgets:
                    BudgetsList()
                case .goals:
                    GoalsList()
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Vue", selection: $segment) {
                    Text("Budgets").tag(Segment.budgets)
                    Text("Objectifs").tag(Segment.goals)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 6)
                .background(.bar)
            }
            .navigationTitle(segment == .budgets ? "Budgets" : "Objectifs")
            // Inline title: a large title would sit under the segmented control.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SpaceMenuButton() } }
        }
    }
}

private struct BudgetsList: View {
    @Environment(SessionStore.self) private var session: SessionStore
    @State private var month: MonthKey = MonthKey.initial
    @State private var state: LoadState<[BudgetStatus]> = .loading

    var body: some View {
        List {
            Section {
                MonthSwitcher(month: $month)
            }
            LoadView(state: state, retry: load) { (budgets: [BudgetStatus]) in
                if budgets.isEmpty {
                    ContentUnavailableView("Aucun budget", systemImage: "chart.bar", description: Text("Crée tes budgets sur le site."))
                } else {
                    let limit: Int = budgets.reduce(0) { (sum: Int, budget: BudgetStatus) -> Int in sum + budget.monthlyLimitCents }
                    let spent: Int = budgets.reduce(0) { (sum: Int, budget: BudgetStatus) -> Int in sum + budget.spentCents }
                    Section {
                        BudgetRow(title: "Total", category: nil, spent: spent, limit: limit)
                    }
                    Section("Par catégorie") {
                        ForEach(budgets, id: \.categoryId) { (budget: BudgetStatus) in
                            let category: Category? = session.category(budget.categoryId)
                            BudgetRow(title: category?.name ?? "Catégorie", category: category, spent: budget.spentCents, limit: budget.monthlyLimitCents)
                        }
                    }
                }
            }
        }
        .refreshable { await load() }
        .task(id: "\(session.selectedSpaceId ?? "")-\(month.key)") { await load() }
    }

    private func load() async {
        guard let client: APIClient = session.client, let space: String = session.selectedSpaceId else { return }
        if state.value == nil { state = .loading }
        do {
            let summary: MonthSummary = try await client.monthSummary(space: space, month: month)
            // Most used budget first: what needs attention is on top.
            let sorted: [BudgetStatus] = summary.budgets.sorted { (left: BudgetStatus, right: BudgetStatus) -> Bool in
                left.spentCents * right.monthlyLimitCents > right.spentCents * left.monthlyLimitCents
            }
            state = .loaded(sorted)
        } catch is CancellationError {
            return
        } catch {
            state = .failed(session.handle(error))
        }
    }
}

private struct BudgetRow: View {
    let title: String
    let category: Category?
    let spent: Int
    let limit: Int

    var body: some View {
        let over: Bool = spent > limit
        let left: Int = limit - spent
        HStack(spacing: 12) {
            if category != nil {
                CategoryBadge(category: category)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).bold(category == nil)
                    Spacer()
                    Text("\(Money.format(spent)) / \(Money.format(limit))")
                        .font(.subheadline)
                        .monospacedDigit()
                }
                ProgressView(value: Double(min(spent, limit)), total: Double(max(limit, 1)))
                    .tint(over ? Color.red : spent * 10 >= limit * 8 ? Color.orange : Color.accentColor)
                Text(over ? "Dépassé de \(Money.format(-left))" : "Reste \(Money.format(left))")
                    .font(.caption)
                    .foregroundStyle(over ? Color.red : Color.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct GoalsList: View {
    @Environment(SessionStore.self) private var session: SessionStore
    @State private var state: LoadState<[Goal]> = .loading

    var body: some View {
        List {
            LoadView(state: state, retry: load) { (goals: [Goal]) in
                if goals.isEmpty {
                    ContentUnavailableView("Aucun objectif", systemImage: "target", description: Text("Crée tes objectifs d'épargne sur le site."))
                } else {
                    ForEach(goals) { (goal: Goal) in
                        NavigationLink {
                            GoalDetailView(goal: goal)
                        } label: {
                            GoalRow(goal: goal)
                        }
                    }
                }
            }
        }
        .refreshable { await load() }
        .task(id: session.selectedSpaceId ?? "") { await load() }
    }

    private func load() async {
        guard let client: APIClient = session.client, let space: String = session.selectedSpaceId else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await client.goals(space: space))
        } catch is CancellationError {
            return
        } catch {
            state = .failed(session.handle(error))
        }
    }
}

private struct GoalRow: View {
    let goal: Goal

    var body: some View {
        let tint: Color = CategoryColor.color(goal.color)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(goal.emoji ?? "🎯") \(goal.name)").bold()
                Spacer()
                Text(Money.percent(Double(goal.savedCents) / Double(max(goal.targetCents, 1))))
                    .font(.subheadline)
                    .foregroundStyle(tint)
            }
            ProgressView(value: Double(min(max(goal.savedCents, 0), goal.targetCents)), total: Double(max(goal.targetCents, 1)))
                .tint(tint)
            HStack {
                Text("\(Money.format(goal.savedCents)) sur \(Money.format(goal.targetCents))")
                Spacer()
                if let deadline: String = goal.deadline {
                    Text("avant le \(DayFormat.medium(deadline))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct GoalDetailView: View {
    let goal: Goal

    var body: some View {
        List {
            Section {
                GoalRow(goal: goal)
                LabeledContent("Reste à épargner", value: Money.format(max(goal.targetCents - goal.savedCents, 0)))
            }
            Section("Versements") {
                if goal.contributions.isEmpty {
                    Text("Aucun versement pour l'instant.")
                        .foregroundStyle(.secondary)
                }
                ForEach(goal.contributions) { (contribution: Contribution) in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DayFormat.medium(contribution.date))
                            if let note: String = contribution.note, !note.isEmpty {
                                Text(note).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        AmountText(cents: contribution.amountCents)
                    }
                }
            }
        }
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

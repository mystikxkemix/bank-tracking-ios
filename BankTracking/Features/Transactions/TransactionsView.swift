import SwiftUI

/// Read-only list of one month's transactions, grouped by day, with search and filters.
/// Pages of 50 are appended when the last row appears.
struct TransactionsView: View {
    @Environment(SessionStore.self) private var session: SessionStore
    @State private var month: MonthKey = MonthKey.initial
    @State private var search: String = ""
    @State private var accountId: String?
    /// A category id, or "none" for uncategorized.
    @State private var categoryId: String?
    @State private var items: [Transaction] = []
    @State private var total: Int = 0
    @State private var page: Int = 1
    @State private var phase: LoadState<Void> = .loading
    @State private var isLoadingMore: Bool = false
    @State private var selected: Transaction?

    private var filterKey: String {
        "\(session.selectedSpaceId ?? "")|\(month.key)|\(search)|\(accountId ?? "")|\(categoryId ?? "")"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthSwitcher(month: $month)
                    if hasFilter {
                        Button("Effacer les filtres", systemImage: "xmark.circle") {
                            accountId = nil
                            categoryId = nil
                        }
                    }
                }
                LoadView(state: phase, retry: { await reload() }) { (_: Void) in
                    rows
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $search, prompt: "Libellé ou note")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { filterMenu }
                ToolbarItem(placement: .topBarTrailing) { SpaceMenuButton() }
            }
            .refreshable { await reload() }
            .task(id: filterKey) {
                // Debounce typing in the search field.
                try? await Task.sleep(for: .milliseconds(search.isEmpty ? 0 : 300))
                if Task.isCancelled { return }
                await reload()
            }
            .sheet(item: $selected) { (transaction: Transaction) in
                TransactionDetailView(transaction: transaction)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var hasFilter: Bool {
        accountId != nil || categoryId != nil
    }

    @ViewBuilder
    private var rows: some View {
        if items.isEmpty {
            ContentUnavailableView("Aucune transaction", systemImage: "tray", description: Text("Rien pour ce mois avec ces filtres."))
        } else {
            ForEach(groupedByDay(), id: \.day) { (group: DayGroup) in
                Section(DayFormat.long(group.day)) {
                    ForEach(group.items) { (transaction: Transaction) in
                        Button {
                            selected = transaction
                        } label: {
                            TransactionRow(transaction: transaction, category: session.category(transaction.categoryId))
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if transaction.id == items.last?.id { Task { await loadMore() } }
                        }
                    }
                }
            }
            Section {
                HStack {
                    Spacer()
                    if isLoadingMore {
                        ProgressView()
                    } else {
                        Text("\(items.count) sur \(total)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Compte", selection: $accountId) {
                Text("Tous les comptes").tag(String?.none)
                ForEach(session.accounts) { (account: Account) in
                    Text(account.name).tag(Optional(account.id))
                }
            }
            Picker("Catégorie", selection: $categoryId) {
                Text("Toutes les catégories").tag(String?.none)
                Text("Sans catégorie").tag(Optional("none"))
                ForEach(sortedCategories) { (category: Category) in
                    Text("\(category.emoji ?? "") \(category.name)").tag(Optional(category.id))
                }
            }
        } label: {
            Label("Filtres", systemImage: hasFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    private var sortedCategories: [Category] {
        session.categoriesById.values.sorted { (left: Category, right: Category) -> Bool in
            left.name.localizedCompare(right.name) == .orderedAscending
        }
    }

    private struct DayGroup {
        let day: String
        let items: [Transaction]
    }

    /// The API returns transactions newest first: consecutive rows share a day.
    private func groupedByDay() -> [DayGroup] {
        var groups: [DayGroup] = []
        var currentDay: String = ""
        var current: [Transaction] = []
        for transaction in items {
            if transaction.date != currentDay, !current.isEmpty {
                groups.append(DayGroup(day: currentDay, items: current))
                current = []
            }
            currentDay = transaction.date
            current.append(transaction)
        }
        if !current.isEmpty {
            groups.append(DayGroup(day: currentDay, items: current))
        }
        return groups
    }

    private func reload() async {
        guard let client: APIClient = session.client, let space: String = session.selectedSpaceId else { return }
        if phase.value == nil { phase = .loading }
        do {
            let result: TransactionPage = try await client.transactions(
                space: space, month: month, query: search, accountId: accountId, categoryId: categoryId, page: 1)
            items = result.items
            total = result.total
            page = 1
            phase = .loaded(())
        } catch is CancellationError {
            return
        } catch let error as APIError {
            phase = .failed(session.handle(error))
        } catch {
            // URLSession reports a cancelled request (new filter typed) as URLError.cancelled.
            if (error as? URLError)?.code == .cancelled { return }
            phase = .failed(session.handle(error))
        }
    }

    private func loadMore() async {
        guard !isLoadingMore, items.count < total, let client: APIClient = session.client, let space: String = session.selectedSpaceId else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result: TransactionPage = try await client.transactions(
                space: space, month: month, query: search, accountId: accountId, categoryId: categoryId, page: page + 1)
            items.append(contentsOf: result.items)
            total = result.total
            page += 1
        } catch {
            _ = session.handle(error)
        }
    }
}

private struct TransactionRow: View {
    let transaction: Transaction
    let category: Category?

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: category)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.label)
                    .lineLimit(1)
                Text(category?.name ?? "Sans catégorie")
                    .font(.caption)
                    .foregroundStyle(category == nil ? Color.orange : Color.secondary)
            }
            Spacer()
            AmountText(cents: transaction.amountCents)
        }
        .contentShape(Rectangle())
    }
}

struct TransactionDetailView: View {
    @Environment(SessionStore.self) private var session: SessionStore
    let transaction: Transaction

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transaction.label)
                            .font(.title3.bold())
                        AmountText(cents: transaction.amountCents)
                            .font(.title.bold())
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    LabeledContent("Date", value: DayFormat.medium(transaction.date))
                    LabeledContent("Compte", value: session.accountName(transaction.accountId))
                    LabeledContent("Catégorie") {
                        let category: Category? = session.category(transaction.categoryId)
                        Text(category.map { (value: Category) -> String in "\(value.emoji ?? "") \(value.name)" } ?? "Sans catégorie")
                    }
                }
                if let note: String = transaction.note, !note.isEmpty {
                    Section("Note") {
                        Text(note)
                    }
                }
                Section("Libellé de la banque") {
                    Text(transaction.rawLabel)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Détail")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

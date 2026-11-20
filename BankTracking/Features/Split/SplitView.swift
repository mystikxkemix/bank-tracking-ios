import SwiftUI

/// "Répartition du foyer" of one month, read-only: what stays on the joint account and what goes
/// back to each person. Editing stays on the website.
struct SplitView: View {
    @Environment(SessionStore.self) private var session: SessionStore
    @State private var month: MonthKey = MonthKey.initial
    @State private var state: LoadState<SplitData> = .loading

    struct SplitData {
        let month: SplitMonth
        let history: [SplitHistoryItem]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthSwitcher(month: $month)
                }
                LoadView(state: state, retry: load) { (data: SplitData) in
                    content(data)
                }
            }
            .navigationTitle("Répartition")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SpaceMenuButton() } }
            .refreshable { await load() }
            .task(id: "\(session.selectedSpaceId ?? "")-\(month.key)") { await load() }
        }
    }

    @ViewBuilder
    private func content(_ data: SplitData) -> some View {
        let split: SplitMonth = data.month
        let result: SplitResult = split.result
        if split.plan.persons.isEmpty {
            ContentUnavailableView("Pas de répartition", systemImage: "circle.lefthalf.filled", description: Text("Prépare la répartition du foyer sur le site."))
        } else {
            if !split.saved {
                Section {
                    Label(draftMessage(split), systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("À garder sur le compte commun")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Money.format(result.keepOnJointCents))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .padding(.vertical, 4)
            }
            Section("À virer à chacun") {
                ForEach(result.persons, id: \.personId) { (person: SplitPersonResult) in
                    PersonResultRow(name: personName(person.personId, in: split.plan), result: person)
                }
            }
            Section("Détail du mois") {
                LabeledContent("Revenus du foyer", value: Money.format(result.totalIncomeCents))
                LabeledContent("Charges lissées", value: Money.format(result.monthlyChargesCents))
                LabeledContent("Épargne commune", value: Money.format(result.monthlySavingsCents))
                if result.provisionCents > 0 {
                    LabeledContent("Dont provision", value: Money.format(result.provisionCents))
                }
            }
            if !split.plan.lines.isEmpty {
                Section("Charges et épargne") {
                    ForEach(split.plan.lines) { (line: SplitLine) in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.label)
                                Text(frequencyLabel(line))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Money.format(line.amountCents)).monospacedDigit()
                        }
                    }
                }
            }
            if let note: String = split.plan.note, !note.isEmpty {
                Section("Note") {
                    Text(note)
                }
            }
        }
        if !data.history.isEmpty {
            Section("Historique") {
                ForEach(data.history) { (item: SplitHistoryItem) in
                    Button {
                        if let key: MonthKey = MonthKey(item.month) { month = key }
                    } label: {
                        HStack {
                            Text(MonthKey(item.month)?.title ?? item.month)
                            Spacer()
                            Text(Money.format(item.keepOnJointCents))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func draftMessage(_ split: SplitMonth) -> String {
        if let from: String = split.copiedFrom, let key: MonthKey = MonthKey(from) {
            return "Pas encore enregistrée : copie de \(key.title.lowercased()). Valide-la sur le site."
        }
        return "Pas encore enregistrée pour ce mois."
    }

    private func personName(_ id: String, in plan: SplitPlan) -> String {
        plan.persons.first { (person: SplitPerson) -> Bool in person.id == id }?.name ?? "Personne"
    }

    private func frequencyLabel(_ line: SplitLine) -> String {
        let kind: String = line.kind == "savings" ? "Épargne" : "Charge"
        switch line.frequency {
        case "quarterly": return "\(kind), par trimestre"
        case "yearly": return "\(kind), par an"
        default: return "\(kind), par mois"
        }
    }

    private func load() async {
        guard let client: APIClient = session.client, let space: String = session.selectedSpaceId else { return }
        if state.value == nil { state = .loading }
        do {
            async let split: SplitMonth = client.splitMonth(space: space, month: month)
            async let history: [SplitHistoryItem] = client.splitHistory(space: space)
            state = .loaded(SplitData(month: try await split, history: try await history))
        } catch is CancellationError {
            return
        } catch {
            state = .failed(session.handle(error))
        }
    }
}

private struct PersonResultRow: View {
    let name: String
    let result: SplitPersonResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).bold()
                Spacer()
                Text(Money.format(result.returnCents))
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(result.returnCents < 0 ? Color.red : Color.primary)
            }
            if result.returnCents < 0 {
                Text("Doit compléter le compte commun de \(Money.format(-result.returnCents))")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Revenus \(Money.format(result.incomeCents)), laisse \(Money.format(result.contributionCents)) au commun")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

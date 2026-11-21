import SwiftUI
import WidgetKit

@main
struct BankTrackingWidgetBundle: WidgetBundle {
    var body: some Widget {
        SavingsWidget()
    }
}

struct SavingsEntry: TimelineEntry {
    let date: Date
    let outcome: WidgetLoader.Outcome
}

/// Fetches the month summary itself with the login shared by the app, every hour.
/// When the server cannot be reached it shows the last known figures.
struct SavingsProvider: TimelineProvider {
    private static let sample: WidgetSnapshot = WidgetSnapshot(
        month: MonthKey.current().key, spaceName: "Foyer", savingsCents: 188_781, budgetLeftCents: 33_811, updatedAt: Date())

    func placeholder(in context: Context) -> SavingsEntry {
        SavingsEntry(date: Date(), outcome: .fresh(SavingsProvider.sample))
    }

    func getSnapshot(in context: Context, completion: @escaping (SavingsEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            completion(SavingsEntry(date: Date(), outcome: await WidgetLoader.load()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavingsEntry>) -> Void) {
        Task {
            let now: Date = Date()
            let entry: SavingsEntry = SavingsEntry(date: now, outcome: await WidgetLoader.load(now: now))
            let next: Date = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct SavingsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SavingsWidget", provider: SavingsProvider()) { (entry: SavingsEntry) in
            SavingsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Épargne du mois")
        .description("L'épargne du mois et ce qu'il reste de tes budgets.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

private struct SavingsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family: WidgetFamily
    let entry: SavingsEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            SavingsAccessoryView(outcome: entry.outcome)
        default:
            SavingsWidgetView(outcome: entry.outcome)
        }
    }
}

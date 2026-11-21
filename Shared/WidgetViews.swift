import SwiftUI
import WidgetKit

/// Brand teal (#12A594), also the app's accent color. Hard-coded because the widget has no asset catalog.
extension Color {
    static let brandTeal: Color = Color(red: 0x12 / 255, green: 0xA5 / 255, blue: 0x94 / 255)
}

/// Content of the home screen widget for every state of `WidgetLoader.Outcome`.
struct SavingsWidgetView: View {
    let outcome: WidgetLoader.Outcome

    var body: some View {
        Group {
            switch outcome {
            case .fresh(let snapshot):
                SavingsSmallView(snapshot: snapshot, isStale: false)
            case .cached(let snapshot):
                SavingsSmallView(snapshot: snapshot, isStale: true)
            case .signedOut:
                WidgetMessage(systemImage: "person.crop.circle.badge.questionmark", text: "Ouvre Comptes pour te connecter")
            case .failed:
                WidgetMessage(systemImage: "wifi.exclamationmark", text: "Serveur injoignable")
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

struct SavingsSmallView: View {
    let snapshot: WidgetSnapshot
    /// true when the figures come from the cache (server unreachable).
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(MonthKey(snapshot.month)?.title ?? snapshot.month)
                    .font(.caption.bold())
                    .foregroundStyle(Color.brandTeal)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isStale {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Données en cache")
                }
            }
            Spacer(minLength: 4)
            Text("Épargne")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(Money.format(snapshot.savingsCents, signed: true))
                .font(.title3.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(snapshot.savingsCents >= 0 ? Color.green : Color.red)
            Spacer(minLength: 4)
            Text(budgetTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(budgetValue)
                .font(.headline)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle((snapshot.budgetLeftCents ?? 0) < 0 ? Color.red : Color.primary)
        }
        .privacySensitive()
    }

    private var budgetTitle: String {
        guard let left: Int = snapshot.budgetLeftCents else { return "Budgets" }
        return left < 0 ? "Budget dépassé de" : "Budget restant"
    }

    private var budgetValue: String {
        guard let left: Int = snapshot.budgetLeftCents else { return "Aucun" }
        return Money.format(abs(left))
    }
}

/// Lock screen version: two short lines.
struct SavingsAccessoryView: View {
    let outcome: WidgetLoader.Outcome

    var body: some View {
        Group {
            switch outcome {
            case .fresh(let snapshot), .cached(let snapshot):
                VStack(alignment: .leading, spacing: 0) {
                    Text("Épargne \(Money.format(snapshot.savingsCents, signed: true))")
                        .font(.headline)
                    if let left: Int = snapshot.budgetLeftCents {
                        // Short wording: the lock screen slot fits two lines.
                        Text(left < 0 ? "Dépassé de \(Money.format(-left))" : "Reste \(Money.format(left))")
                    }
                }
                .minimumScaleFactor(0.6)
                .privacySensitive()
            case .signedOut, .failed:
                Text("Comptes")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct WidgetMessage: View {
    let systemImage: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.brandTeal)
            Text(text)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

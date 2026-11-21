import SwiftUI

/// Debug only (`BT_WIDGET=1`): runs the widget's loader with the shared login and draws the widget
/// views at their real sizes, so the widget can be checked in a screenshot.
struct WidgetPreviewScreen: View {
    @State private var outcome: WidgetLoader.Outcome?

    var body: some View {
        VStack(spacing: 24) {
            Text("Aperçu du widget").font(.headline)
            if let outcome: WidgetLoader.Outcome = outcome {
                SavingsWidgetView(outcome: outcome)
                    .padding(16)
                    .frame(width: 170, height: 170)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 22))
                    .shadow(radius: 4)
                SavingsAccessoryView(outcome: outcome)
                    .padding(8)
                    .frame(width: 172, height: 76, alignment: .leading)
                    .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                Text(describe(outcome)).font(.caption).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
        .task { outcome = await WidgetLoader.load() }
    }

    private func describe(_ outcome: WidgetLoader.Outcome) -> String {
        switch outcome {
        case .fresh: return "Chargé depuis le serveur"
        case .cached: return "Depuis le cache"
        case .signedOut: return "Non connecté"
        case .failed(let message): return message
        }
    }
}

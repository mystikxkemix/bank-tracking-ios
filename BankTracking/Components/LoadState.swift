import SwiftUI

/// State of one screen's data. Screens keep the last value while reloading (pull to refresh).
enum LoadState<Value> {
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

/// Shows a spinner, an error with a retry button, or the content.
struct LoadView<Value, Content: View>: View {
    let state: LoadState<Value>
    let retry: () async -> Void
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Chargement impossible", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Réessayer") {
                    Task { await retry() }
                }
                .buttonStyle(.borderedProminent)
            }
        case .loaded(let value):
            content(value)
        }
    }
}

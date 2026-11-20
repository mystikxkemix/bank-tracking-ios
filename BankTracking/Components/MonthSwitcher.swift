import SwiftUI

/// "< Novembre 2026 >" header. The next button stops at the current month.
struct MonthSwitcher: View {
    @Binding var month: MonthKey

    var body: some View {
        let current: MonthKey = MonthKey.current()
        HStack {
            Button {
                month = month.adding(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Mois précédent")
            Spacer()
            Text(month.title)
                .font(.headline)
            Spacer()
            Button {
                month = month.adding(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(month >= current)
            .accessibilityLabel("Mois suivant")
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 4)
    }
}

import SwiftUI

/// Signed amount: money in is green with a "+", money out stays primary.
/// The sign is always written, so color is never the only signal.
struct AmountText: View {
    let cents: Int

    var body: some View {
        Text(Money.format(cents, signed: true))
            .monospacedDigit()
            .foregroundStyle(cents > 0 ? Color.green : Color.primary)
    }
}

/// Emoji in a tinted circle, or a colored dot when the category has no emoji.
struct CategoryBadge: View {
    let category: Category?

    var body: some View {
        let tint: Color = CategoryColor.color(category?.color ?? "gray")
        ZStack {
            Circle().fill(tint.opacity(0.18))
            if let emoji: String = category?.emoji, !emoji.isEmpty {
                Text(emoji).font(.system(size: 16))
            } else {
                Circle().fill(tint).frame(width: 10, height: 10)
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}

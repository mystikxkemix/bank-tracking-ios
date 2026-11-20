import Foundation

/// Formats integer cents as French euros ("1 234,56 €"). Goes through `Decimal`, never `Double`,
/// so the amount shown is exactly the amount stored.
enum Money {
    private static let formatter: NumberFormatter = {
        let formatter: NumberFormatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter
    }()

    static func format(_ cents: Int, signed: Bool = false) -> String {
        let value: Decimal = Decimal(cents) / Decimal(100)
        let text: String = formatter.string(from: value as NSDecimalNumber) ?? "\(value) €"
        return signed && cents > 0 ? "+" + text : text
    }

    /// "42 %" from a ratio (0.42). Display only.
    static func percent(_ ratio: Double) -> String {
        let rounded: Int = Int((ratio * 100).rounded())
        return "\(rounded) %"
    }
}

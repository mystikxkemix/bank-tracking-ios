import Foundation

/// A calendar month, "YYYY-MM" over the API (same format as `monthKeySchema`).
struct MonthKey: Hashable, Comparable, Identifiable {
    let year: Int
    /// 1...12
    let month: Int

    var id: String { key }

    var key: String {
        String(format: "%04d-%02d", year, month)
    }

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    /// Parses "YYYY-MM", nil when malformed.
    init?(_ key: String) {
        let parts: [Substring] = key.split(separator: "-")
        guard parts.count == 2, let year: Int = Int(parts[0]), let month: Int = Int(parts[1]), (1...12).contains(month) else {
            return nil
        }
        self.init(year: year, month: month)
    }

    static func current(calendar: Calendar = .current, now: Date = Date()) -> MonthKey {
        let components: DateComponents = calendar.dateComponents([.year, .month], from: now)
        return MonthKey(year: components.year ?? 2000, month: components.month ?? 1)
    }

    func adding(_ months: Int) -> MonthKey {
        let index: Int = year * 12 + (month - 1) + months
        return MonthKey(year: index / 12, month: index % 12 + 1)
    }

    /// "Novembre 2026".
    var title: String {
        let name: String = MonthKey.monthNames[month - 1]
        return "\(name.prefix(1).uppercased())\(name.dropFirst()) \(year)"
    }

    /// "nov. 26", for chart axes.
    var shortTitle: String {
        "\(MonthKey.shortNames[month - 1]) \(String(format: "%02d", year % 100))"
    }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    // Fixed French names: the UI is French whatever the phone language.
    private static let monthNames: [String] = [
        "janvier", "février", "mars", "avril", "mai", "juin",
        "juillet", "août", "septembre", "octobre", "novembre", "décembre",
    ]
    private static let shortNames: [String] = [
        "janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc.",
    ]
}

/// Calendar days "YYYY-MM-DD" from the API, shown in French.
enum DayFormat {
    private static let parser: DateFormatter = {
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let long: DateFormatter = {
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
    }()

    private static let medium: DateFormatter = {
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    /// "Lundi 3 novembre".
    static func long(_ day: String) -> String {
        guard let date: Date = parser.date(from: day) else { return day }
        let text: String = long.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "3 nov. 2026".
    static func medium(_ day: String) -> String {
        guard let date: Date = parser.date(from: day) else { return day }
        return medium.string(from: date)
    }
}

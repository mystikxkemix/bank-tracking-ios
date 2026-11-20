import SwiftUI

/// Maps the Radix Themes color names used by categories and goals (`COLORS` in the shared package)
/// to the closest SwiftUI system color.
enum CategoryColor {
    static func color(_ name: String) -> Color {
        switch name {
        case "tomato", "red", "ruby", "crimson": return .red
        case "pink": return .pink
        case "plum", "purple", "violet": return .purple
        case "iris", "indigo": return .indigo
        case "blue": return .blue
        case "cyan", "sky": return .cyan
        case "teal", "jade": return .teal
        case "mint": return .mint
        case "green", "grass", "lime": return .green
        case "brown", "bronze": return .brown
        case "orange": return .orange
        case "amber", "yellow", "gold": return .yellow
        default: return .gray
        }
    }
}

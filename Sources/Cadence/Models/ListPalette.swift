import SwiftUI

/// Resolves a TaskList's stored `colorKey` to a concrete color from Tokens.
/// Keys are stable strings (not raw hex) so the visual palette can evolve
/// without rewriting persisted data.
enum ListPalette {

    static let allKeys: [String] = ["violet", "amber", "teal", "mint", "rose", "pink", "indigo", "orange", "neutral"]

    static func color(for key: String) -> Color {
        switch key {
        case "violet":  return Tokens.Color.accent
        case "amber":   return Tokens.Color.amber
        case "teal":    return Tokens.Color.teal
        case "mint":    return Tokens.Color.mint
        case "rose":    return Tokens.Color.rose
        case "pink":    return Tokens.Color.pink
        case "indigo":  return Tokens.Color.indigo
        case "orange":  return Tokens.Color.orange
        case "neutral": return Tokens.Color.text3
        default:        return Tokens.Color.accent
        }
    }

    /// Soft chip background tint (low-opacity version of the same hue).
    static func chipFill(for key: String) -> Color {
        color(for: key).opacity(0.14)
    }
}

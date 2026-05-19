import SwiftUI

/// Build 24: every chrome color in Cadence reads its accent from one of
/// seven themes. Surface colors (bg, surface, text) keep their existing
/// Light/Dark adaptive treatment from Tokens.swift — themes only restyle
/// the accent palette so the app feels different without re-engineering
/// every surface for every theme. Two specials (`mono` + `highContrast`)
/// flip surfaces too because they're fundamentally different aesthetics.
enum AppTheme: String, CaseIterable, Identifiable {
    case violet
    case mint
    case warm
    case ocean
    case forest
    case mono
    case highContrast

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .violet:        return "Violet"
        case .mint:          return "Mint"
        case .warm:          return "Warm"
        case .ocean:         return "Ocean"
        case .forest:        return "Forest"
        case .mono:          return "Mono"
        case .highContrast:  return "High Contrast"
        }
    }

    var subtitle: String {
        switch self {
        case .violet:        return "Calm. The Cadence default."
        case .mint:          return "Fresh, productive."
        case .warm:          return "Cozy, hearth-y."
        case .ocean:         return "Deep and steady."
        case .forest:        return "Natural, grounding."
        case .mono:          return "Minimal. Pure black + white."
        case .highContrast:  return "AAA contrast for readability."
        }
    }

    // MARK: Accent palette (drives Tokens.Color.accent / accent2 / accentDeep / accentGlow)

    /// Primary brand accent (buttons, rings, selected chips).
    var accent: SwiftUI.Color {
        switch self {
        case .violet:        return SwiftUI.Color(hex: 0x7C5CFF)
        case .mint:          return SwiftUI.Color(hex: 0x34D399)
        case .warm:          return SwiftUI.Color(hex: 0xFB923C)
        case .ocean:         return SwiftUI.Color(hex: 0x06B6D4)
        case .forest:        return SwiftUI.Color(hex: 0x16A34A)
        case .mono:          return SwiftUI.Color(hex: 0xE8EAF0)
        case .highContrast:  return SwiftUI.Color(hex: 0xFFFF00)
        }
    }

    /// Slightly lighter / softer (subtitles, secondary chips).
    var accent2: SwiftUI.Color {
        switch self {
        case .violet:        return SwiftUI.Color(hex: 0xB794FF)
        case .mint:          return SwiftUI.Color(hex: 0x6EE7B7)
        case .warm:          return SwiftUI.Color(hex: 0xFDBA74)
        case .ocean:         return SwiftUI.Color(hex: 0x67E8F9)
        case .forest:        return SwiftUI.Color(hex: 0x4ADE80)
        case .mono:          return SwiftUI.Color(hex: 0xC0C4D0)
        case .highContrast:  return SwiftUI.Color(hex: 0xFFFF80)
        }
    }

    /// Deeper end of the gradient (button shadows, glow base).
    var accentDeep: SwiftUI.Color {
        switch self {
        case .violet:        return SwiftUI.Color(hex: 0x5B3CFA)
        case .mint:          return SwiftUI.Color(hex: 0x10B981)
        case .warm:          return SwiftUI.Color(hex: 0xEA580C)
        case .ocean:         return SwiftUI.Color(hex: 0x0891B2)
        case .forest:        return SwiftUI.Color(hex: 0x166534)
        case .mono:          return SwiftUI.Color(hex: 0x8A8E9F)
        case .highContrast:  return SwiftUI.Color(hex: 0xCCCC00)
        }
    }

    /// 35%-opacity accent for shadow glow effects.
    var accentGlow: SwiftUI.Color { accent.opacity(0.35) }

    /// True for themes that should override the system Light/Dark color
    /// scheme. `mono` and `highContrast` are intentional aesthetic
    /// statements that don't bend to system appearance.
    var prefersForceDark: Bool {
        switch self {
        case .mono, .highContrast: return true
        default: return false
        }
    }

    // MARK: Preview swatches (used by the picker card thumbnails)

    /// 3-color thumbnail: bg / surface / accent.
    var previewSwatches: [SwiftUI.Color] {
        switch self {
        case .violet:
            return [SwiftUI.Color(hex: 0x07080C), SwiftUI.Color(hex: 0x14171F), accent]
        case .mint:
            return [SwiftUI.Color(hex: 0x07090C), SwiftUI.Color(hex: 0x14191F), accent]
        case .warm:
            return [SwiftUI.Color(hex: 0xFAF7F1), SwiftUI.Color(hex: 0xF6F2EA), accent]
        case .ocean:
            return [SwiftUI.Color(hex: 0x05131F), SwiftUI.Color(hex: 0x0B1E2E), accent]
        case .forest:
            return [SwiftUI.Color(hex: 0x081008), SwiftUI.Color(hex: 0x0F1B0F), accent]
        case .mono:
            return [SwiftUI.Color(hex: 0x000000), SwiftUI.Color(hex: 0x1A1A1A), accent]
        case .highContrast:
            return [SwiftUI.Color(hex: 0x000000), SwiftUI.Color(hex: 0x1A1A00), accent]
        }
    }
}

/// Build 24: singleton that owns the currently-selected theme. Static
/// `Tokens.Color.accent` (etc.) reads from `ThemeManager.shared.current`
/// at render time, so picking a new theme + bumping the @AppStorage
/// key in the root view forces a tree re-render and every Tokens
/// callsite returns the new color.
///
/// Reads are intentionally cheap (no UserDefaults round-trip per access)
/// so re-rendering a complex view tree on theme switch stays smooth.
final class ThemeManager {
    static let shared = ThemeManager()
    /// Hardcoded here (rather than referencing PrefsKey.themeKey) so this
    /// file can be shared with widget / capture / watch extension targets
    /// without dragging in Preferences.swift's iOS-only symbols.
    static let storageKey = "themeKey"

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
            ?? AppTheme.violet.rawValue
        self.current = AppTheme(rawValue: raw) ?? .violet
    }

    private(set) var current: AppTheme

    func apply(_ theme: AppTheme) {
        current = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
    }
}

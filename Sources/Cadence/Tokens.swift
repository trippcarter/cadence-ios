import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Cadence design tokens — single source of truth for colors, type, spacing, and radii.
/// Mirrors the dark-UI palette in docs/Cadence_Mockups.html.
enum Tokens {

    // MARK: Color

    enum Color {
        // Surfaces (darkest → lightest in dark mode; lightest → darkest in light mode).
        // Build 13: now adaptive — each token resolves to its dark or light
        // variant based on the current colorScheme so the Settings → Theme
        // picker actually changes the look (previously all Tokens.Color values
        // were hex-coded dark-only).
        static let bg = SwiftUI.Color.dynamic(
            light: SwiftUI.Color(hex: 0xFAF7F1),    // warm off-white / cream
            dark:  SwiftUI.Color(hex: 0x07080C)
        )
        static let bg2 = SwiftUI.Color.dynamic(
            light: SwiftUI.Color(hex: 0xF2EEE6),
            dark:  SwiftUI.Color(hex: 0x0B0D14)
        )
        static let surface = SwiftUI.Color.dynamic(
            light: SwiftUI.Color(hex: 0xFFFFFF),
            dark:  SwiftUI.Color(hex: 0x14171F)
        )
        static let surface2 = SwiftUI.Color.dynamic(
            light: SwiftUI.Color(hex: 0xF6F2EA),
            dark:  SwiftUI.Color(hex: 0x1A1E29)
        )
        static let surface3 = SwiftUI.Color.dynamic(
            light: SwiftUI.Color(hex: 0xEEE9DE, opacity: 0.78),
            dark:  SwiftUI.Color(hex: 0x212633, opacity: 0.59)
        )
        static let border = SwiftUI.Color.dynamic(
            light: SwiftUI.Color(hex: 0xDED8C9),
            dark:  SwiftUI.Color(hex: 0x252A38)
        )
        static let borderSoft = SwiftUI.Color.dynamic(
            light: SwiftUI.Color(hex: 0xEAE5D8),
            dark:  SwiftUI.Color(hex: 0x1B1F2B)
        )

        // Text (brightest → dimmest)
        static let text = SwiftUI.Color.dynamic(
            light: SwiftUI.Color(hex: 0x1A1C24),
            dark:  SwiftUI.Color(hex: 0xE8EAF0)
        )
        static let text2 = SwiftUI.Color.dynamic(
            light: SwiftUI.Color(hex: 0x4B4F60),
            dark:  SwiftUI.Color(hex: 0xA9AEC1)
        )
        static let text3 = SwiftUI.Color.dynamic(
            light: SwiftUI.Color(hex: 0x8A8E9F),
            dark:  SwiftUI.Color(hex: 0x6E7388)
        )

        // Brand — Build 24: now theme-driven. The four accent tokens read
        // from ThemeManager.shared.current.* at render time. Pick a new
        // theme in Settings → Appearance and the entire app re-renders
        // because the @AppStorage(themeKey) at the root invalidates the
        // tree, which re-evaluates these computed properties.
        static var accent: SwiftUI.Color      { ThemeManager.shared.current.accent }
        static var accent2: SwiftUI.Color     { ThemeManager.shared.current.accent2 }
        static var accentDeep: SwiftUI.Color  { ThemeManager.shared.current.accentDeep }
        static var accentGlow: SwiftUI.Color  { ThemeManager.shared.current.accentGlow }

        // Accent palette (lists, chips, statuses)
        static let indigo = SwiftUI.Color(hex: 0x6366F1)
        static let mint   = SwiftUI.Color(hex: 0x34D399)
        static let amber  = SwiftUI.Color(hex: 0xF59E0B)
        static let rose   = SwiftUI.Color(hex: 0xFB7185)
        static let teal   = SwiftUI.Color(hex: 0x2DD4BF)
        static let pink   = SwiftUI.Color(hex: 0xF472B6)
        static let orange = SwiftUI.Color(hex: 0xFB923C)
    }

    // MARK: Spacing (4-pt scale)

    enum Space {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: Radius

    enum Radius {
        static let chip: CGFloat = 999    // pill
        static let sm: CGFloat   = 10
        static let md: CGFloat   = 12
        static let lg: CGFloat   = 14
        static let card: CGFloat = 16
        static let sheet: CGFloat = 22
        static let phone: CGFloat = 44    // device-frame mockups
    }

    // MARK: Typography
    //
    // Sizes mirror the mockup CSS. SF (system) is used here; switch to Inter
    // by bundling the font and replacing `.system` with `.custom("Inter-…")`.

    enum Font {
        static let displayLarge  = SwiftUI.Font.system(size: 30, weight: .bold).leading(.tight)
        static let title         = SwiftUI.Font.system(size: 22, weight: .semibold)
        static let headline      = SwiftUI.Font.system(size: 18, weight: .semibold)
        static let body          = SwiftUI.Font.system(size: 15, weight: .regular)
        static let bodyEmphasis  = SwiftUI.Font.system(size: 15, weight: .medium)
        static let taskTitle     = SwiftUI.Font.system(size: 14, weight: .medium)
        static let caption       = SwiftUI.Font.system(size: 12, weight: .regular)
        static let chip          = SwiftUI.Font.system(size: 10, weight: .semibold)
        static let label         = SwiftUI.Font.system(size: 11, weight: .semibold) // uppercase eyebrows
    }

    // MARK: Animation

    enum Motion {
        static let spring   = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.78)
        static let snappy   = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.82)
        static let smooth   = SwiftUI.Animation.easeInOut(duration: 0.25)
    }
}

// MARK: - SwiftUI.Color hex helper

extension SwiftUI.Color {
    /// Initialize a color from a 0xRRGGBB hex value.
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Resolve `light` or `dark` based on the active interface style. Build 13:
    /// powers the adaptive Tokens.Color palette so the theme picker actually
    /// changes the UI. Uses UIKit's UIColor(dynamicProvider:) under the hood,
    /// which SwiftUI re-evaluates whenever the colorScheme environment changes.
    /// watchOS doesn't have `UIColor(dynamicProvider:)` or `userInterfaceStyle`
    /// (the entire watchOS UI is dark), so we return the dark variant there.
    static func dynamic(light: SwiftUI.Color, dark: SwiftUI.Color) -> SwiftUI.Color {
        #if canImport(UIKit) && !os(watchOS)
        return SwiftUI.Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        return dark
        #endif
    }
}

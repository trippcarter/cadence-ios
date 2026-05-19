import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Build 24: grid of alternate app icons. Tap a tile → calls
/// `UIApplication.shared.setAlternateIconName(_:)` which prompts the
/// system "Cadence icon was changed" alert and replaces the home-screen
/// icon. nil = default.
///
/// Build 29 fix: previous implementation called `UIImage(named:)` on
/// the `.appiconset` asset name, which returns nil because Xcode
/// compiles iconsets into a separate icon-bundle format — they aren't
/// reachable via the regular image lookup. Result was every tile
/// rendering the violet fallback.
///
/// New approach: render each preview programmatically with the same
/// gradient + glyph as the actual home-screen PNG. No asset lookup,
/// no cache to go stale, and the preview literally matches the
/// rendering recipe.
struct AppIconPicker: View {
    @AppStorage(PrefsKey.alternateIconName) private var currentIconName: String = ""

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: Tokens.Space.md),
            GridItem(.flexible(), spacing: Tokens.Space.md),
            GridItem(.flexible(), spacing: Tokens.Space.md)
        ]
        return LazyVGrid(columns: columns, spacing: Tokens.Space.md) {
            ForEach(IconStyle.all) { style in
                tile(for: style)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func tile(for style: IconStyle) -> some View {
        let isSelected = currentIconName == style.alternateName
        return Button {
            Haptics.tap()
            apply(style.alternateName)
        } label: {
            VStack(spacing: 6) {
                IconPreview(style: style)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Tokens.Color.accent : Color.clear, lineWidth: 2.5)
                            .padding(-2)
                    )
                    .scaleEffect(isSelected ? 1.04 : 1.0)
                    .accessibilityLabel(style.displayName)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                Text(style.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Tokens.Color.accent2 : Tokens.Color.text3)
                    .lineLimit(1)
            }
            .animation(.bouncy(duration: 0.35), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func apply(_ identifier: String) {
        #if canImport(UIKit)
        let target: String? = identifier.isEmpty ? nil : identifier
        guard UIApplication.shared.supportsAlternateIcons else {
            NSLog("[Cadence-Icon] device doesn't support alternate icons")
            return
        }
        guard UIApplication.shared.alternateIconName != target else {
            currentIconName = identifier
            return
        }
        UIApplication.shared.setAlternateIconName(target) { error in
            if let error {
                NSLog("[Cadence-Icon] setAlternateIconName failed: %@", error.localizedDescription)
            } else {
                currentIconName = identifier
                NSLog("[Cadence-Icon] applied %@", target ?? "<default>")
            }
        }
        #endif
    }
}

// MARK: - IconStyle (single source of truth for preview rendering)

/// Mirrors each AlternateAppIcons/<Name>.appiconset/<PNG> entry so the
/// SwiftUI preview reproduces the home-screen icon. Colors picked to
/// match the PNG renders I verified visually in Build 27.
struct IconStyle: Identifiable {
    /// The string passed to `UIApplication.setAlternateIconName(_:)`.
    /// "" = default (no alternate; reverts to AppIcon).
    let alternateName: String
    let displayName: String
    let colors: [Color]
    /// Optional accent decoration drawn in the lower-right (Outdoors
    /// has a small leaf, Family has a heart, etc.).
    let accentSymbol: String?
    let accentColor: Color

    var id: String { alternateName.isEmpty ? "default" : alternateName }

    static let all: [IconStyle] = [
        IconStyle(alternateName: "",         displayName: "Violet",
                  colors: [Color(hex: 0x7C5CFF), Color(hex: 0x5B3CFA)],
                  accentSymbol: nil, accentColor: .clear),
        IconStyle(alternateName: "Mint",     displayName: "Mint",
                  colors: [Color(hex: 0x34D399), Color(hex: 0x059669)],
                  accentSymbol: nil, accentColor: .clear),
        IconStyle(alternateName: "Warm",     displayName: "Warm",
                  colors: [Color(hex: 0xFB923C), Color(hex: 0xD97706)],
                  accentSymbol: nil, accentColor: .clear),
        IconStyle(alternateName: "Ocean",    displayName: "Ocean",
                  colors: [Color(hex: 0x06B6D4), Color(hex: 0x0E7490)],
                  accentSymbol: nil, accentColor: .clear),
        IconStyle(alternateName: "Forest",   displayName: "Forest",
                  colors: [Color(hex: 0x16A34A), Color(hex: 0x065F46)],
                  accentSymbol: nil, accentColor: .clear),
        IconStyle(alternateName: "Mono",     displayName: "Mono",
                  colors: [Color(hex: 0xE5E7EB), Color(hex: 0xCBD5E1)],
                  accentSymbol: nil, accentColor: .clear),
        IconStyle(alternateName: "Outdoors", displayName: "Outdoors",
                  colors: [Color(hex: 0x6E4A1F), Color(hex: 0x3F2A11)],
                  accentSymbol: "j.circle.fill", accentColor: Color(hex: 0xF1E4C7)),
        IconStyle(alternateName: "Family",   displayName: "Family",
                  colors: [Color(hex: 0xF472B6), Color(hex: 0xBE185D)],
                  accentSymbol: "heart.fill", accentColor: .white)
    ]
}

/// Programmatic preview of a single icon. Drawn at any size — the
/// gradient + "C" glyph + optional decoration scale together so the
/// 76pt tile and the larger lock-screen previews share one recipe.
struct IconPreview: View {
    let style: IconStyle

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let glyphSize = side * 0.55
            let isLight = style.alternateName == "Mono"
            let glyphColor: Color = isLight ? Color(hex: 0x111827) : .white

            ZStack {
                LinearGradient(
                    colors: style.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text("C")
                    .font(.system(size: glyphSize, weight: .bold, design: .rounded))
                    .foregroundStyle(glyphColor)
                if let symbol = style.accentSymbol {
                    Image(systemName: symbol)
                        .font(.system(size: side * 0.18, weight: .semibold))
                        .foregroundStyle(style.accentColor)
                        .offset(x: side * 0.22, y: side * 0.22)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Build 24: grid of alternate app icons. Tap a tile → calls
/// `UIApplication.shared.setAlternateIconName(_:)` which prompts the
/// system "Cadence icon was changed" alert and replaces the home-screen
/// icon. nil = default.
///
/// The tile preview shows the actual PNG asset compiled into the bundle,
/// not a SwiftUI-rendered facsimile, so the preview always matches what
/// the user will see on their home screen.
struct AppIconPicker: View {
    @AppStorage(PrefsKey.alternateIconName) private var currentIconName: String = ""

    private struct Option: Identifiable {
        let id: String      // "" for default, else asset name (Mint, Warm, etc.)
        let displayName: String
        let assetName: String  // Asset catalog name for the preview image
    }

    private let options: [Option] = [
        Option(id: "",         displayName: "Violet",   assetName: "AppIcon-1024"),
        Option(id: "Mint",     displayName: "Mint",     assetName: "AppIcon-Mint-1024"),
        Option(id: "Warm",     displayName: "Warm",     assetName: "AppIcon-Warm-1024"),
        Option(id: "Ocean",    displayName: "Ocean",    assetName: "AppIcon-Ocean-1024"),
        Option(id: "Forest",   displayName: "Forest",   assetName: "AppIcon-Forest-1024"),
        Option(id: "Mono",     displayName: "Mono",     assetName: "AppIcon-Mono-1024"),
        Option(id: "Outdoors", displayName: "Outdoors", assetName: "AppIcon-Outdoors-1024"),
        Option(id: "Family",   displayName: "Family",   assetName: "AppIcon-Family-1024"),
    ]

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: Tokens.Space.md),
            GridItem(.flexible(), spacing: Tokens.Space.md),
            GridItem(.flexible(), spacing: Tokens.Space.md)
        ]
        return LazyVGrid(columns: columns, spacing: Tokens.Space.md) {
            ForEach(options) { option in
                tile(for: option)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func tile(for option: AppIconPicker.Option) -> some View {
        let isSelected = currentIconName == option.id
        return Button {
            Haptics.tap()
            apply(option.id)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.gray.opacity(0.18))
                        .frame(width: 84, height: 84)
                    // Use the actual compiled asset as the preview. If the
                    // asset doesn't load (e.g. the bundle isn't built yet),
                    // fall back to a placeholder gradient.
                    if let uiImage = previewImage(for: option) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 76, height: 76)
                            .overlay(
                                Text("C")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            )
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? Tokens.Color.accent : Color.clear, lineWidth: 2.5)
                )
                .scaleEffect(isSelected ? 1.04 : 1.0)
                Text(option.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Tokens.Color.accent2 : Tokens.Color.text3)
                    .lineLimit(1)
            }
            .animation(.bouncy(duration: 0.35), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func previewImage(for option: AppIconPicker.Option) -> UIImage? {
        UIImage(named: option.assetName)
    }

    private func apply(_ identifier: String) {
        #if canImport(UIKit)
        let target: String? = identifier.isEmpty ? nil : identifier
        guard UIApplication.shared.supportsAlternateIcons else {
            NSLog("[Cadence-Icon] device doesn't support alternate icons")
            return
        }
        guard UIApplication.shared.alternateIconName != target else {
            currentIconName = identifier  // already there, just sync storage
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

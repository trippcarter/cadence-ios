import SwiftUI

/// Build 24: grid of theme cards reachable from Settings → Appearance.
/// Each card shows a 3-stripe preview (bg / surface / accent) plus the
/// theme name + subtitle. Tap = apply live across the entire app.
struct AppearanceThemePicker: View {
    @AppStorage(PrefsKey.themeKey) private var themeKey: String = AppTheme.violet.rawValue

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: Tokens.Space.sm),
            GridItem(.flexible(), spacing: Tokens.Space.sm)
        ]
        return LazyVGrid(columns: columns, spacing: Tokens.Space.sm) {
            ForEach(AppTheme.allCases) { theme in
                card(for: theme)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func card(for theme: AppTheme) -> some View {
        let isSelected = themeKey == theme.rawValue
        return Button {
            Haptics.tap()
            withAnimation(.smooth(duration: 0.3)) {
                themeKey = theme.rawValue
            }
            ThemeManager.shared.apply(theme)
        } label: {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                preview(for: theme)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(theme.displayName)
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.text)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.accent)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    Text(theme.subtitle)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                        .lineLimit(1)
                }
            }
            .padding(Tokens.Space.md)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(isSelected ? theme.accent : Tokens.Color.borderSoft,
                            lineWidth: isSelected ? 1.4 : 0.5)
            )
            .animation(.bouncy(duration: 0.35), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    /// Three-stripe preview thumbnail (bg / surface / accent) — gives the
    /// user a real sense of what each theme looks like before applying.
    private func preview(for theme: AppTheme) -> some View {
        let swatches = theme.previewSwatches
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(swatches[0])
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(swatches[1])
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(swatches[1])
                        .frame(width: 24, height: 8)
                }
                HStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(swatches[1])
                        .frame(height: 14)
                    Spacer()
                    Capsule()
                        .fill(swatches[2])
                        .frame(width: 24, height: 14)
                }
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(swatches[1])
                    .frame(height: 12)
            }
            .padding(8)
        }
        .frame(height: 76)
    }
}

import SwiftUI

/// One row in the Lists screen — works for both real and smart lists.
struct ListRow: View {
    let source: ListSource
    let subtitle: String
    let taskCount: Int
    var sharedAvatars: Int = 0

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            iconBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(subtitle)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
            if sharedAvatars > 0 {
                avatarCluster
            }
            Text("\(taskCount)")
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text2)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Tokens.Color.text3)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .fill(ListPalette.color(for: source.colorKey).opacity(0.18))
                .frame(width: 34, height: 34)
            Image(systemName: source.iconKey)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ListPalette.color(for: source.colorKey))
        }
    }

    private var avatarCluster: some View {
        HStack(spacing: -7) {
            ForEach(0..<min(sharedAvatars, 3), id: \.self) { idx in
                let gradient: [Color] = idx == 0
                    ? [Tokens.Color.indigo, Tokens.Color.accent]
                    : [Tokens.Color.amber, Tokens.Color.rose]
                Circle()
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Tokens.Color.surface, lineWidth: 2))
            }
        }
        .padding(.trailing, 4)
    }
}

import SwiftUI

/// Empty-state view for tabs we haven't built yet (Week, Lists, You).
struct PlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()
            VStack(spacing: Tokens.Space.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Tokens.Color.accent2)
                Text(title)
                    .font(Tokens.Font.title)
                    .foregroundStyle(Tokens.Color.text)
                Text(subtitle)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.xxl)
            }
        }
    }
}

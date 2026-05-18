import SwiftUI

/// Transient overlay shown when AuthSession transitions to .signedIn for
/// the first time this launch. Self-dismisses after ~1.5 seconds.
///
/// Copy: "Welcome, X" on a first-ever sign-in for this Apple ID;
/// "Welcome back, X" if the per-identifier name cache had a `firstSeenAt`
/// entry before this sign-in.
struct WelcomeSplashView: View {
    let firstName: String
    let isReturning: Bool
    var onDismiss: () -> Void

    @State private var iconScale: CGFloat = 0.4
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Tokens.Color.bg, Tokens.Color.accent.opacity(0.18), Tokens.Color.bg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: Tokens.Space.lg) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: Tokens.Color.accentGlow, radius: 18, x: 0, y: 8)
                    Image(systemName: "checkmark")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                VStack(spacing: 6) {
                    Text(isReturning ? "Welcome back," : "Welcome,")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Tokens.Color.text3)
                    Text(firstName)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Tokens.Color.text)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.bouncy(duration: 0.55)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.smooth(duration: 0.5).delay(0.25)) {
                textOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onDismiss()
            }
        }
    }
}

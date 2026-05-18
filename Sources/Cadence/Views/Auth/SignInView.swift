import SwiftUI
import AuthenticationServices

/// Full-screen view shown after onboarding completes but before the user
/// signs in. The system `SignInWithAppleButton` handles the entire dialog
/// + 2FA dance — we just receive the result and hand it to AuthSession.
struct SignInView: View {
    @EnvironmentObject private var authSession: AuthSession
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // Subtle Cadence gradient — matches onboarding backdrop.
            LinearGradient(
                colors: [
                    Tokens.Color.bg,
                    Tokens.Color.accent.opacity(0.12),
                    Tokens.Color.bg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: Tokens.Space.lg) {
                Spacer(minLength: 0)
                logoBlock
                Spacer()
                ctaBlock
                Spacer(minLength: Tokens.Space.xl)
            }
            .padding(.horizontal, Tokens.Space.lg)
        }
    }

    // MARK: Sections

    private var logoBlock: some View {
        VStack(spacing: Tokens.Space.lg) {
            ZStack {
                Circle()
                    .fill(Tokens.Color.accent.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
            }
            VStack(spacing: 8) {
                Text(authSession.promptingSwitchAccount ? "Sign in again" : "Welcome to Cadence")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Tokens.Color.text)
                Text(authSession.promptingSwitchAccount
                     ? "Tap below and pick the Apple ID you want to use."
                     : "Daily tasks. Real life. One calm surface.")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.accent2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var ctaBlock: some View {
        VStack(spacing: Tokens.Space.lg) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleResult(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .shadow(color: Tokens.Color.accentGlow, radius: 8, x: 0, y: 4)

            VStack(spacing: 6) {
                Text("Cadence uses your Apple ID to keep your data private and synced. No password required.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.lg)

                HStack(spacing: 6) {
                    Button("Privacy Policy") { /* TODO: link out once we have a URL */ }
                        .font(Tokens.Font.chip)
                        .foregroundStyle(Tokens.Color.accent2)
                    Text("·")
                        .font(Tokens.Font.chip)
                        .foregroundStyle(Tokens.Color.text3)
                    Button("Terms") { /* TODO */ }
                        .font(Tokens.Font.chip)
                        .foregroundStyle(Tokens.Color.accent2)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.rose)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.lg)
            }
        }
    }

    // MARK: Result handler

    private func handleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Couldn't read Apple credential."
                return
            }
            errorMessage = nil
            Haptics.success()
            authSession.handleAppleAuthorization(credential)
        case .failure(let error as NSError):
            // Cancellation is not an error from the user's perspective.
            if error.domain == ASAuthorizationError.errorDomain,
               error.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = "Sign-in failed: \(error.localizedDescription)"
        }
    }
}

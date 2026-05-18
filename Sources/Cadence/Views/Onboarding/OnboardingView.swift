import SwiftUI

struct OnboardingView: View {
    @AppStorage(PrefsKey.hasOnboarded) private var hasOnboarded: Bool = false
    @State private var pageIndex: Int = 0

    private let pageCount = 3

    var body: some View {
        ZStack {
            // Gradient backdrop
            LinearGradient(
                colors: [
                    Tokens.Color.bg,
                    Tokens.Color.accent.opacity(0.10),
                    Tokens.Color.bg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                skipBar
                TabView(selection: $pageIndex) {
                    WelcomePage().tag(0)
                    ListsPage().tag(1)
                    NotificationsPage().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                pageIndicator
                actionButton
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.bottom, Tokens.Space.xxl)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Sub-views

    private var skipBar: some View {
        HStack {
            Spacer()
            Button("Skip") {
                Haptics.tap()
                finish()
            }
            .font(Tokens.Font.bodyEmphasis)
            .foregroundStyle(Tokens.Color.text3)
            .padding(.trailing, Tokens.Space.lg)
            .padding(.top, Tokens.Space.lg)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { idx in
                Capsule()
                    .fill(pageIndex == idx ? Tokens.Color.accent : Tokens.Color.text3.opacity(0.3))
                    .frame(width: pageIndex == idx ? 22 : 6, height: 6)
                    .animation(.bouncy(duration: 0.35), value: pageIndex)
            }
        }
        .padding(.bottom, Tokens.Space.lg)
    }

    private var actionButton: some View {
        Button {
            Haptics.tap()
            if pageIndex < pageCount - 1 {
                withAnimation(.bouncy(duration: 0.4)) {
                    pageIndex += 1
                }
            } else {
                finish()
            }
        } label: {
            Text(pageIndex == pageCount - 1 ? "Get started" : "Continue")
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Space.md + 2)
                .background(
                    LinearGradient(
                        colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                .shadow(color: Tokens.Color.accentGlow, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func finish() {
        withAnimation(.smooth) {
            hasOnboarded = true
        }
    }
}

// MARK: - Pages

private struct WelcomePage: View {
    var body: some View {
        OnboardingPage(
            iconName: "moon.stars.fill",
            iconColor: Tokens.Color.accent,
            title: "Welcome to Cadence",
            subtitle: "Daily tasks. Real life. One calm surface.",
            bodyText: "Your tasks and your calendar meet in one Today view. Roll-over by default — incomplete work never falls off the radar."
        )
    }
}

private struct ListsPage: View {
    private let lists: [(String, String, Color)] = [
        ("Personal", "person.fill", Tokens.Color.accent),
        ("Family", "house.fill", Tokens.Color.pink),
        ("Boat", "sailboat.fill", Tokens.Color.teal),
        ("Projects", "hammer.fill", Tokens.Color.amber),
        ("Side hustle", "lightbulb.fill", Tokens.Color.indigo),
    ]

    var body: some View {
        VStack(spacing: Tokens.Space.lg) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(Tokens.Color.accent.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
            }
            VStack(spacing: 8) {
                Text("Lists for every context")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Tokens.Color.text)
                    .multilineTextAlignment(.center)
                Text("Personal, family, business, boat, projects — anything you want. Create as many as you need, share any of them.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.xl)
            }
            VStack(spacing: Tokens.Space.sm) {
                ForEach(lists, id: \.0) { name, icon, tint in
                    HStack(spacing: Tokens.Space.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                                .fill(tint.opacity(0.18))
                                .frame(width: 30, height: 30)
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(tint)
                        }
                        Text(name)
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.text)
                        Spacer()
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, Tokens.Space.sm)
                    .background(Tokens.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                            .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal, Tokens.Space.xl)
            Spacer(minLength: 0)
        }
    }
}

private struct NotificationsPage: View {
    var body: some View {
        OnboardingPage(
            iconName: "bell.badge.fill",
            iconColor: Tokens.Color.amber,
            title: "Gentle reminders",
            subtitle: "A morning brief, plus per-task nudges.",
            bodyText: "You'll be asked for notification permission the first time you set a reminder — not now."
        )
    }
}

private struct OnboardingPage: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let bodyText: String

    var body: some View {
        VStack(spacing: Tokens.Space.lg) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: iconName)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Tokens.Color.text)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.accent2)
                    .multilineTextAlignment(.center)
            }
            Text(bodyText)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xl)
            Spacer(minLength: 0)
        }
    }
}

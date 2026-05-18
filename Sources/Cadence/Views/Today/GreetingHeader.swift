import SwiftUI

/// Time-aware greeting row at the top of the Today screen (Build 13).
/// Combines the greeting copy, the date subtitle, and the daily-progress
/// ring on the trailing edge. Designed to feel premium without being noisy.
///
/// Greeting buckets (per spec):
///   5:00–11:59 → "Good morning"
///   12:00–16:59 → "Good afternoon"
///   17:00–21:59 → "Good evening"
///   22:00– 4:59 → "Late night"
struct GreetingHeader: View {
    let date: Date
    let completedCount: Int
    let totalCount: Int
    var onTapAvatar: () -> Void = {}

    @EnvironmentObject private var authSession: AuthSession
    @State private var hasAppeared = false

    private var greetingPhrase: String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Late night"
        }
    }

    private var firstName: String {
        let resolved = authSession.state.user?.firstNameOrFallback ?? "there"
        return resolved
    }

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(greetingPhrase), \(firstName)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(date, format: .dateTime.weekday(.wide).day().month())
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer(minLength: 0)
            DailyProgressRing(completedCount: completedCount, totalCount: totalCount)
                .onTapGesture { onTapAvatar() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Today's progress: \(completedCount) of \(totalCount) complete. Tap to open profile.")
        }
        .offset(y: hasAppeared ? 0 : -10)
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.bouncy(duration: 0.55).delay(0.05)) {
                hasAppeared = true
            }
        }
    }
}

/// 44pt circular progress ring that tracks completion of today's tasks.
/// Filled arc = completed / total; center text = "5 of 8" ratio.
struct DailyProgressRing: View {
    let completedCount: Int
    let totalCount: Int

    @State private var animatedProgress: Double = 0
    @State private var didCelebrate: Bool = false

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var isComplete: Bool {
        totalCount > 0 && completedCount >= totalCount
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Tokens.Color.surface2, lineWidth: 4)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Tokens.Color.accent, Tokens.Color.accentDeep]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Tokens.Color.accentGlow, radius: isComplete ? 8 : 0)

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Tokens.Color.mint)
                    .transition(.scale.combined(with: .opacity))
            } else if totalCount > 0 {
                VStack(spacing: 0) {
                    Text("\(completedCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Tokens.Color.text)
                        .monospacedDigit()
                    Text("of \(totalCount)")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Color.text3)
                        .monospacedDigit()
                }
            } else {
                Image(systemName: "moon.stars")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
        }
        .frame(width: 44, height: 44)
        .onAppear {
            withAnimation(.smooth(duration: 0.8)) {
                animatedProgress = progress
            }
            if isComplete, !didCelebrate {
                didCelebrate = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    Haptics.success()
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.smooth(duration: 0.6)) {
                animatedProgress = newValue
            }
            if isComplete, !didCelebrate {
                didCelebrate = true
                Haptics.success()
            } else if !isComplete {
                didCelebrate = false
            }
        }
    }
}

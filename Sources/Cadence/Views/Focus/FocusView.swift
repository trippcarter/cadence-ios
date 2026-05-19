import SwiftUI
import SwiftData
import AudioToolbox

/// Build 18: full-screen Pomodoro session anchored to a specific task.
/// Owns a Timer that ticks every 0.25s while running, drives a violet
/// gradient progress ring, plays a bell + success haptic on natural
/// completion, and persists a `FocusSession` row for stats.
///
/// Entry points: TaskDetailSheet "Focus" button, TaskRowActions context
/// menu "Start Focus session".
///
/// Skipped per spec: ActivityKit Live Activity / Dynamic Island. Adding
/// either needs a separate widget extension target + entitlement work.
struct FocusView: View {
    let task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage(PrefsKey.focusDurationMinutes) private var durationMinutes: Int = 25
    @AppStorage(PrefsKey.focusBreakMinutes)    private var breakMinutes: Int = 5
    @AppStorage(PrefsKey.focusPlaySound)       private var playSound: Bool = true
    @AppStorage(PrefsKey.focusPlayHaptic)      private var playHaptic: Bool = true

    @State private var session: FocusSession?
    @State private var totalSeconds: Int = 1500
    @State private var remaining: Int = 1500
    @State private var isPaused: Bool = false
    @State private var timer: Timer?
    @State private var showingEndConfirm: Bool = false
    @State private var showingBreakSuggestion: Bool = false

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1 - Double(remaining) / Double(totalSeconds)
    }

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: Tokens.Space.xl) {
                Spacer(minLength: 0)
                timerRing
                taskBlock
                Spacer(minLength: 0)
                controls
                    .padding(.bottom, Tokens.Space.xxl)
            }
            .padding(.horizontal, Tokens.Space.lg)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear { startSession() }
        .onDisappear { stopTimer() }
        .alert("End focus session early?", isPresented: $showingEndConfirm) {
            Button("End", role: .destructive) {
                endSession(naturally: false)
            }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("Your progress so far will still be recorded.")
        }
        .sheet(isPresented: $showingBreakSuggestion) {
            breakSuggestionSheet
                .presentationDetents([.medium])
        }
    }

    // MARK: Layout

    private var backdrop: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Tokens.Color.accent.opacity(0.20), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Tokens.Color.accentDeep.opacity(0.16), .clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Tokens.Color.accent, Tokens.Color.accentDeep]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Tokens.Color.accentGlow, radius: 16, x: 0, y: 0)
                .animation(.smooth(duration: 0.3), value: progress)
            VStack(spacing: 4) {
                Text(formattedRemaining)
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(isPaused ? "PAUSED" : "FOCUS")
                    .font(Tokens.Font.label)
                    .kerning(2.0)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: 240, height: 240)
    }

    private var taskBlock: some View {
        VStack(spacing: Tokens.Space.sm) {
            Text(task.title)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, Tokens.Space.lg)
            if let list = task.list {
                let tint = ListPalette.color(for: list.colorKey)
                HStack(spacing: 6) {
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(list.name)
                        .font(Tokens.Font.chip)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: Tokens.Space.xl) {
            controlButton(systemImage: "xmark", label: "End", tint: Tokens.Color.rose) {
                showingEndConfirm = true
            }
            primaryButton
            controlButton(systemImage: "goforward.5", label: "+5", tint: .white.opacity(0.7)) {
                extend(byMinutes: 5)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            togglePause()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .shadow(color: Tokens.Color.accentGlow, radius: 14, x: 0, y: 6)
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPaused ? "Resume" : "Pause")
    }

    private func controlButton(systemImage: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 52, height: 52)
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .kerning(0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var breakSuggestionSheet: some View {
        VStack(spacing: Tokens.Space.lg) {
            ZStack {
                Circle()
                    .fill(Tokens.Color.mint.opacity(0.18))
                    .frame(width: 88, height: 88)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Tokens.Color.mint)
            }
            VStack(spacing: 6) {
                Text("Nice work.")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                Text("Take a \(breakMinutes)-minute break before the next session.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.lg)
            }
            HStack(spacing: Tokens.Space.md) {
                Button("Skip break") {
                    showingBreakSuggestion = false
                    dismiss()
                }
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text2)
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.vertical, Tokens.Space.md)

                Button {
                    showingBreakSuggestion = false
                    dismiss()
                } label: {
                    Text("Done")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Tokens.Space.xl)
                        .padding(.vertical, Tokens.Space.md)
                        .background(
                            LinearGradient(
                                colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Tokens.Color.accentGlow, radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, Tokens.Space.md)
        }
        .padding(.vertical, Tokens.Space.xxl)
    }

    // MARK: Lifecycle + timing

    private func startSession() {
        let seconds = max(durationMinutes, 1) * 60
        totalSeconds = seconds
        remaining = seconds

        let newSession = FocusSession(
            task: task,
            startedAt: .now,
            plannedDuration: TimeInterval(seconds)
        )
        modelContext.insert(newSession)
        try? modelContext.save()
        session = newSession

        Haptics.tap()
        startTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !isPaused else { return }
        // Reduce by 0.25s each tick; flip a whole-second boundary every 4
        // ticks so the UI digits update once per second.
        let currentRemaining = Double(remaining) - 0.25
        if currentRemaining <= 0 {
            remaining = 0
            endSession(naturally: true)
        } else {
            remaining = Int(currentRemaining.rounded())
        }
    }

    private func togglePause() {
        Haptics.tap()
        isPaused.toggle()
    }

    private func extend(byMinutes minutes: Int) {
        Haptics.tap()
        let extra = minutes * 60
        totalSeconds += extra
        remaining += extra
        session?.plannedDuration += TimeInterval(extra)
        try? modelContext.save()
    }

    private func endSession(naturally: Bool) {
        stopTimer()
        let elapsed = totalSeconds - remaining
        session?.endedAt = .now
        session?.actualDuration = TimeInterval(elapsed)
        session?.wasCompleted = naturally
        try? modelContext.save()

        if naturally {
            if playHaptic { Haptics.success() }
            if playSound {
                // AudioServicesPlaySystemSound uses an iOS system sound ID;
                // 1322 is the gentle "Tweet" sound — short, pleasant, fits
                // the "calm completion" vibe.
                AudioServicesPlaySystemSound(1322)
            }
            showingBreakSuggestion = true
        } else {
            Haptics.warning()
            dismiss()
        }
    }

    // MARK: Helpers

    private var formattedRemaining: String {
        let mm = remaining / 60
        let ss = remaining % 60
        return String(format: "%02d:%02d", mm, ss)
    }
}

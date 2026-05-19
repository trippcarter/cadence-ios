import SwiftUI
import SwiftData

/// Build 18: the evening reflection sheet. Fired by the daily-review
/// notification at the user's configured time, or manually via You tab →
/// "Run today's review".
///
/// Four sections (top to bottom):
///   1. Completed today — auto-populated, read-only
///   2. Carried over — interactive chips per task (Done / Tomorrow /
///      Snooze 3d / Pick date)
///   3. Tomorrow's intention — single-line TextField
///   4. Win of the day — multi-line TextField
///
/// On "Save & close": writes a ReviewLog (always) plus a TomorrowIntention
/// and/or DailyWin if their text fields are non-empty. Drives the review-
/// streak stat on the You tab.
struct DailyReviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSession

    @Query private var allTasks: [TaskItem]
    @Query private var allFocusSessions: [FocusSession]

    @State private var tomorrowIntention: String = ""
    @State private var winOfTheDay: String = ""

    private let today = Calendar.current.startOfDay(for: .now)

    private var completedToday: [TaskItem] {
        allTasks.filter { task in
            guard task.parent == nil, task.status == .completed,
                  let completedAt = task.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }
    }

    private var carriedOver: [TaskItem] {
        allTasks.filter { task in
            guard task.parent == nil, task.status == .open,
                  let due = task.dueDate else { return false }
            // Open + due today or earlier (i.e. unfinished due-today + overdue).
            return due <= .now && (Calendar.current.isDateInToday(due) || due < today)
        }
    }

    private var focusMinutesToday: Int {
        let secondsToday = allFocusSessions
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .reduce(0.0) { $0 + $1.actualDuration }
        return Int(secondsToday / 60)
    }

    private var focusSessionsToday: Int {
        allFocusSessions.filter { Calendar.current.isDateInToday($0.startedAt) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                        header
                        completedSection
                        if !carriedOver.isEmpty {
                            carriedOverSection
                        }
                        intentionSection
                        winSection
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.top, Tokens.Space.md)
                }
            }
            .navigationTitle("Today's review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Tokens.Color.text2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save & close") { save() }
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.accent2)
                }
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Color.text)
            Text("Take a minute. How did today go?")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text3)
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            sectionHeader(icon: "checkmark.seal.fill", title: "Completed today", tint: Tokens.Color.mint)
            VStack(spacing: 0) {
                if completedToday.isEmpty {
                    Text("Quiet day. That's okay.")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Color.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Tokens.Space.lg)
                } else {
                    statBar
                    Divider().background(Tokens.Color.borderSoft)
                    ForEach(Array(completedToday.enumerated()), id: \.element.id) { idx, task in
                        completedRow(task: task)
                        if idx < completedToday.count - 1 {
                            Divider().background(Tokens.Color.borderSoft)
                        }
                    }
                }
            }
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
        }
    }

    private var statBar: some View {
        HStack(spacing: Tokens.Space.lg) {
            statPill(value: "\(completedToday.count)", label: completedToday.count == 1 ? "task" : "tasks")
            statPill(value: "\(focusSessionsToday)", label: focusSessionsToday == 1 ? "focus" : "focus")
            statPill(value: "\(focusMinutesToday)", label: "min")
        }
        .padding(Tokens.Space.md)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Tokens.Color.text)
                .monospacedDigit()
            Text(label.uppercased())
                .font(Tokens.Font.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.Color.text3)
        }
        .frame(maxWidth: .infinity)
    }

    private func completedRow(task: TaskItem) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tokens.Color.mint)
            Text(task.title)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text)
                .strikethrough(true, color: Tokens.Color.text3)
                .lineLimit(2)
            Spacer()
            if let list = task.list {
                Circle()
                    .fill(ListPalette.color(for: list.colorKey))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.sm + 2)
    }

    private var carriedOverSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            sectionHeader(icon: "calendar.badge.clock", title: "Carried over", tint: Tokens.Color.amber)
            VStack(spacing: 0) {
                ForEach(Array(carriedOver.enumerated()), id: \.element.id) { idx, task in
                    carriedOverRow(task: task)
                    if idx < carriedOver.count - 1 {
                        Divider().background(Tokens.Color.borderSoft)
                    }
                }
            }
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.amber.opacity(0.25), lineWidth: 0.5)
            )
        }
    }

    private func carriedOverRow(task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(task.title)
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
                .lineLimit(2)
            HStack(spacing: 6) {
                quickChip(label: "Done", icon: "checkmark.circle.fill", tint: Tokens.Color.mint) {
                    markComplete(task)
                }
                quickChip(label: "Tomorrow", icon: "calendar", tint: Tokens.Color.accent2) {
                    snooze(task, byDays: 1)
                }
                quickChip(label: "3 days", icon: "calendar.badge.plus", tint: Tokens.Color.text2) {
                    snooze(task, byDays: 3)
                }
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private func quickChip(label: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(Tokens.Font.chip)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var intentionSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            sectionHeader(icon: "leaf.fill", title: "Tomorrow's intention", tint: Tokens.Color.teal)
            TextField("One thing you want to do tomorrow", text: $tomorrowIntention, axis: .vertical)
                .font(Tokens.Font.body)
                .lineLimit(1...3)
                .padding(Tokens.Space.lg)
                .background(Tokens.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                        .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
                )
        }
    }

    private var winSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            sectionHeader(icon: "star.fill", title: "Win of the day", tint: Tokens.Color.amber)
            TextField("Something good that happened — however small", text: $winOfTheDay, axis: .vertical)
                .font(Tokens.Font.body)
                .lineLimit(1...4)
                .padding(Tokens.Space.lg)
                .background(Tokens.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                        .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
                )
        }
    }

    private func sectionHeader(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(Tokens.Font.label)
                .kerning(0.8)
                .foregroundStyle(Tokens.Color.text2)
        }
    }

    // MARK: Actions

    private func markComplete(_ task: TaskItem) {
        withAnimation(Tokens.Motion.spring) {
            task.status = .completed
            task.completedAt = .now
            task.modifiedAt = .now
        }
        HabitTracker.recordCompletionIfNeeded(for: task, in: modelContext)
        try? modelContext.save()
        Task { await SharedListMirror.shared.taskChanged(task) }
    }

    private func snooze(_ task: TaskItem, byDays days: Int) {
        let cal = Calendar.current
        guard let newDate = cal.date(byAdding: .day, value: days, to: task.dueDate ?? .now) else { return }
        task.dueDate = newDate
        task.allDay = true
        task.status = .open
        task.modifiedAt = .now
        try? modelContext.save()
        Task { await SharedListMirror.shared.taskChanged(task) }
    }

    private func save() {
        Haptics.success()
        let userID = authSession.state.user?.appleUserIdentifier ?? ""
        let trimmedIntention = tomorrowIntention.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWin = winOfTheDay.trimmingCharacters(in: .whitespacesAndNewlines)

        // Always log the review (even if intention + win are blank — the act
        // of opening + closing the sheet still counts toward the streak).
        let log = ReviewLog(
            date: today,
            completedAt: .now,
            hasIntention: !trimmedIntention.isEmpty,
            hasWin: !trimmedWin.isEmpty
        )
        modelContext.insert(log)

        if !trimmedIntention.isEmpty {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? .now
            let intention = TomorrowIntention(date: tomorrow, text: trimmedIntention, userIdentifier: userID)
            modelContext.insert(intention)
        }
        if !trimmedWin.isEmpty {
            let win = DailyWin(date: today, text: trimmedWin, userIdentifier: userID)
            modelContext.insert(win)
        }
        try? modelContext.save()
        dismiss()
    }
}

import SwiftUI
import SwiftData

/// Build 25: review all completed tasks grouped by day. Time-period picker
/// at the top (Week / Month / Year / All), plus a small stats strip
/// showing completed count + focus minutes for the selected window.
///
/// Reachable from Lists → smart filter "Completed". CSV export deferred
/// to a follow-up build.
struct CompletedHistoryView: View {
    @Query(sort: [SortDescriptor(\TaskItem.completedAt, order: .reverse)])
    private var allTasks: [TaskItem]
    @Query(sort: [SortDescriptor(\FocusSession.startedAt, order: .reverse)])
    private var focusSessions: [FocusSession]

    @State private var period: Period = .week
    @State private var detailTask: TaskItem?

    enum Period: String, CaseIterable, Identifiable {
        case week  = "This week"
        case month = "This month"
        case year  = "This year"
        case all   = "All time"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Tokens.Color.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    periodPicker
                    statsCard
                    groupedList
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.top, Tokens.Space.md)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Completed")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $detailTask) { task in
            TaskDetailSheet(task: task)
        }
    }

    // MARK: Period picker

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(Period.allCases) { p in
                Text(p.rawValue).tag(p)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Stats card

    private var statsCard: some View {
        let completed = filteredTasks.count
        let focusMin = Int(filteredFocusMinutes)
        let sessions = filteredFocusSessions.count
        return HStack(spacing: Tokens.Space.md) {
            statPill(value: "\(completed)", label: completed == 1 ? "task" : "tasks", accent: Tokens.Color.mint)
            statPill(value: "\(sessions)", label: sessions == 1 ? "session" : "sessions", accent: Tokens.Color.accent)
            statPill(value: "\(focusMin)", label: "min focused", accent: Tokens.Color.amber)
        }
        .padding(Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
    }

    private func statPill(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Tokens.Color.text)
                .monospacedDigit()
            Text(label.uppercased())
                .font(Tokens.Font.label)
                .kerning(0.6)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Grouped list

    @ViewBuilder
    private var groupedList: some View {
        if filteredTasks.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 38))
                    .foregroundStyle(Tokens.Color.text3)
                Text("Nothing to look back on yet")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text(emptyHint)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.xxl)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Tokens.Space.xl)
        } else {
            ForEach(groupedByDay, id: \.0) { (day, tasks) in
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Text(dayHeader(day))
                        .font(Tokens.Font.label)
                        .kerning(0.6)
                        .foregroundStyle(Tokens.Color.text3)
                    VStack(spacing: 0) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
                            row(task)
                            if idx < tasks.count - 1 {
                                Divider().background(Tokens.Color.borderSoft)
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
        }
    }

    private func row(_ task: TaskItem) -> some View {
        Button {
            detailTask = task
        } label: {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Color.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Color.text)
                        .strikethrough(true, color: Tokens.Color.text3)
                        .lineLimit(1)
                    if let list = task.list {
                        Text(list.name)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Color.text3)
                    }
                }
                Spacer()
                if let completedAt = task.completedAt {
                    Text(completedAt, format: .dateTime.hour().minute())
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                        .monospacedDigit()
                }
                if let list = task.list {
                    Circle()
                        .fill(ListPalette.color(for: list.colorKey))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.sm + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayHeader(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        let formatter = DateFormatter()
        if cal.isDate(day, equalTo: .now, toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
        } else {
            formatter.dateFormat = "EEEE, MMM d"
        }
        return formatter.string(from: day)
    }

    private var emptyHint: String {
        switch period {
        case .week:  return "Complete some tasks this week to see them here."
        case .month: return "No completed tasks this month yet."
        case .year:  return "No completed tasks this year yet."
        case .all:   return "Complete your first task to start your history."
        }
    }

    // MARK: Filter math

    private var windowStart: Date? {
        let cal = Calendar.current
        switch period {
        case .week:
            return cal.date(byAdding: .day, value: -7, to: .now)
        case .month:
            return cal.date(byAdding: .day, value: -30, to: .now)
        case .year:
            return cal.date(byAdding: .day, value: -365, to: .now)
        case .all:
            return nil
        }
    }

    private var filteredTasks: [TaskItem] {
        allTasks.filter { task in
            guard task.parent == nil,
                  task.status == .completed,
                  let completedAt = task.completedAt else { return false }
            if let start = windowStart, completedAt < start { return false }
            return true
        }
    }

    private var filteredFocusSessions: [FocusSession] {
        focusSessions.filter { session in
            guard let endedAt = session.endedAt else { return false }
            if let start = windowStart, endedAt < start { return false }
            return true
        }
    }

    private var filteredFocusMinutes: Double {
        filteredFocusSessions.reduce(0.0) { $0 + $1.actualDuration / 60.0 }
    }

    private var groupedByDay: [(Date, [TaskItem])] {
        let cal = Calendar.current
        let buckets = Dictionary(grouping: filteredTasks) { task in
            cal.startOfDay(for: task.completedAt ?? .now)
        }
        return buckets
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }) }
    }
}

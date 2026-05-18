import SwiftUI
import SwiftData

struct TaskRow: View {
    @Bindable var task: TaskItem
    /// When true, the row shows the "was Mon" carried-over chip.
    var showsCarriedOverChip: Bool = false
    /// Tapping the row body (everything except the complete circle) fires this.
    var onTitleTap: (() -> Void)? = nil
    /// When provided and `.isActive == true`, the row swaps its normal
    /// tap behavior for a checkmark column + selection toggle. Build 12,
    /// Upgrade 3 (multi-select mode).
    var selection: TaskSelectionState? = nil
    @Environment(\.modelContext) private var modelContext
    @Query private var cachedEvents: [CachedEvent]

    /// True when the task's mirrored event has been edited externally.
    private var isMirrorDiverged: Bool {
        MirrorDivergence.divergedStart(for: task, among: cachedEvents) != nil
    }

    private var isInSelectionMode: Bool {
        selection?.isActive ?? false
    }

    private var isSelected: Bool {
        selection?.contains(task) ?? false
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            if isInSelectionMode {
                selectionCircle
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                completeButton
            }
            Button(action: handleTap) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if task.isPinned {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Tokens.Color.amber)
                                .accessibilityLabel("Pinned")
                        }
                        Text(task.title)
                            .font(Tokens.Font.taskTitle)
                            .foregroundStyle(task.status == .completed ? Tokens.Color.text3 : Tokens.Color.text)
                            .strikethrough(task.status == .completed, color: Tokens.Color.text3)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    meta
                    if !task.subtaskList.isEmpty {
                        subtaskSummary
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onTitleTap == nil && !isInSelectionMode)
        }
        .padding(.vertical, Tokens.Space.md)
        .padding(.horizontal, Tokens.Space.lg)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(isSelected ? Tokens.Color.accent : Tokens.Color.borderSoft,
                        lineWidth: isSelected ? 1.4 : 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(task.status == .completed ? "Double-tap to mark incomplete" : "Double-tap to mark complete")
    }

    private var accessibilityLabel: String {
        var parts: [String] = ["Task: \(task.title)"]
        if let due = task.dueDate {
            if task.allDay {
                parts.append("due today")
            } else {
                parts.append("due " + due.formatted(.dateTime.hour().minute()))
            }
        }
        if let list = task.list {
            parts.append("in \(list.name)")
        }
        if task.status == .completed {
            parts.append("completed")
        } else if task.isCarriedOver {
            parts.append("carried over")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: Selection circle (multi-select mode)

    private var selectionCircle: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Tokens.Color.accent : Tokens.Color.text3.opacity(0.5),
                              lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(Tokens.Color.accent)
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.top, 1)
        .accessibilityLabel(isSelected ? "Selected" : "Not selected")
    }

    private func handleTap() {
        if isInSelectionMode {
            selection?.toggle(task)
        } else {
            onTitleTap?()
        }
    }

    // MARK: Complete circle

    private var completeButton: some View {
        Button(action: toggleComplete) {
            ZStack {
                Circle()
                    .strokeBorder(checkBorderColor, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if task.status == .completed {
                    Circle()
                        .fill(Tokens.Color.accent)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.status == .completed ? "Mark task incomplete" : "Mark task complete")
    }

    private var checkBorderColor: Color {
        switch task.priority {
        case .high:   return Tokens.Color.rose
        case .medium: return Tokens.Color.amber
        case .low, .none: return Tokens.Color.text3
        }
    }

    private func toggleComplete() {
        withAnimation(Tokens.Motion.spring) {
            if task.status == .completed {
                task.status = .open
                task.completedAt = nil
            } else {
                task.status = .completed
                task.completedAt = .now
                Haptics.success()
            }
        }
        try? modelContext.save()
        Task { await SharedListMirror.shared.taskChanged(task) }
    }

    // MARK: Meta row (time + list chip + carried-over chip)

    @ViewBuilder
    private var meta: some View {
        let chips = metaChips
        if !chips.isEmpty {
            HStack(spacing: Tokens.Space.sm) {
                ForEach(0..<chips.count, id: \.self) { idx in
                    chips[idx]
                }
            }
            .padding(.top, 2)
        }
    }

    private var metaChips: [AnyView] {
        var result: [AnyView] = []
        if let due = task.dueDate, !task.allDay, task.status != .completed {
            result.append(AnyView(timeChip(for: due)))
        }
        if task.isRecurring {
            result.append(AnyView(recurrenceIcon))
        }
        if showsCarriedOverChip, let due = task.dueDate {
            result.append(AnyView(carriedChip(for: due)))
        }
        if let list = task.list {
            result.append(AnyView(listChip(for: list)))
        }
        if isMirrorDiverged {
            result.append(AnyView(divergedChip))
        } else if task.hasActiveMirror {
            result.append(AnyView(mirroredChip))
        }
        return result
    }

    private var recurrenceIcon: some View {
        Image(systemName: "repeat")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Tokens.Color.accent2)
            .accessibilityLabel("Recurring task")
    }

    private var mirroredChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 9, weight: .semibold))
            Text("Blocked")
                .font(Tokens.Font.chip)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Tokens.Color.teal.opacity(0.12))
        .foregroundStyle(Tokens.Color.teal)
        .clipShape(Capsule())
    }

    private var divergedChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .font(.system(size: 9, weight: .semibold))
            Text("Modified in Google")
                .font(Tokens.Font.chip)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Tokens.Color.amber.opacity(0.18))
        .foregroundStyle(Tokens.Color.amber)
        .clipShape(Capsule())
    }

    private func timeChip(for date: Date) -> some View {
        Text(date, format: .dateTime.hour().minute())
            .font(Tokens.Font.chip)
            .foregroundStyle(Tokens.Color.text2)
    }

    private func carriedChip(for due: Date) -> some View {
        let dayName = due.formatted(.dateTime.weekday(.abbreviated))
        return Text("was \(dayName)")
            .font(Tokens.Font.chip)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Tokens.Color.rose.opacity(0.12))
            .foregroundStyle(Tokens.Color.rose)
            .clipShape(Capsule())
    }

    private func listChip(for list: TaskList) -> some View {
        HStack(spacing: 4) {
            Image(systemName: list.iconKey)
                .font(.system(size: 9, weight: .semibold))
            Text(list.name)
                .font(Tokens.Font.chip)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(ListPalette.chipFill(for: list.colorKey))
        .foregroundStyle(ListPalette.color(for: list.colorKey))
        .clipShape(Capsule())
    }

    // MARK: Subtask summary

    private var subtaskSummary: some View {
        let done = task.subtaskList.filter { $0.status == .completed }.count
        let total = task.subtaskList.count
        return HStack(spacing: 4) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 9, weight: .semibold))
            Text("\(done)/\(total) subtasks")
                .font(Tokens.Font.chip)
        }
        .foregroundStyle(Tokens.Color.text3)
        .padding(.top, 2)
    }

    // MARK: Row background — subtle gradient for "first row" style on carried/today

    private var rowBackground: some View {
        LinearGradient(
            colors: [Tokens.Color.surface2, Tokens.Color.surface],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

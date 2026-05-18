import SwiftUI
import SwiftData

/// Compact two-column-grid card for an "Anytime today" task (Build 12,
/// Upgrade 1). Used when the Anytime bucket has more than 5 tasks — keeps
/// the visual rhythm tight without dropping any information.
///
/// Layout: small 18pt complete circle on the left, title (1 line truncated),
/// list-color chip below; priority indicator overlays the complete circle
/// when set. Tap the title area → opens TaskDetailSheet (caller-provided).
/// The full-row context menu + swipe actions wire through `TaskRowActionContainer`.
struct AnytimeGridCard: View {
    let task: TaskItem
    var onTap: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var isPressed: Bool = false

    private var tint: Color {
        ListPalette.color(for: task.list?.colorKey ?? "violet")
    }

    var body: some View {
        Button { onTap() } label: {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack(spacing: 6) {
                    completeCircle
                    if task.isPinned {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Tokens.Color.amber)
                    }
                    Spacer()
                    priorityBadge
                }
                Text(task.title)
                    .font(Tokens.Font.taskTitle)
                    .foregroundStyle(task.status == .completed ? Tokens.Color.text3 : Tokens.Color.text)
                    .lineLimit(2)
                    .strikethrough(task.status == .completed)
                    .multilineTextAlignment(.leading)
                listChip
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.md)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.bouncy(duration: 0.35), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isPressed { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("\(task.title), in \(task.list?.name ?? "Inbox")")
    }

    private var completeCircle: some View {
        Button { toggleComplete() } label: {
            ZStack {
                Circle()
                    .stroke(checkBorderColor, lineWidth: 1.6)
                    .frame(width: 18, height: 18)
                if task.status == .completed {
                    Circle()
                        .fill(Tokens.Color.mint)
                        .frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var checkBorderColor: Color {
        switch task.priority {
        case .high:   return Tokens.Color.rose
        case .medium: return Tokens.Color.amber
        case .low, .none: return Tokens.Color.text3
        }
    }

    @ViewBuilder
    private var priorityBadge: some View {
        if task.priority != .none {
            Text(priorityLabel)
                .font(Tokens.Font.chip)
                .kerning(0.5)
                .foregroundStyle(priorityColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(priorityColor.opacity(0.14))
                .clipShape(Capsule())
        }
    }

    private var priorityLabel: String {
        switch task.priority {
        case .high:   return "HIGH"
        case .medium: return "MED"
        case .low:    return "LOW"
        case .none:   return ""
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high:   return Tokens.Color.rose
        case .medium: return Tokens.Color.amber
        case .low:    return Tokens.Color.text2
        case .none:   return Tokens.Color.text3
        }
    }

    private var listChip: some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(task.list?.name ?? "Inbox")
                .font(Tokens.Font.chip)
                .foregroundStyle(Tokens.Color.text2)
                .lineLimit(1)
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
}

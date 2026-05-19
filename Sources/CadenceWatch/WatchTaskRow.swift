import SwiftUI
import SwiftData
#if canImport(WatchKit)
import WatchKit
#endif

/// Build 21: compact task row sized for the watch face. Single line of
/// text, a tappable complete-circle on the leading edge, optional time
/// chip on the trailing edge, and a colored dot indicating the parent
/// list. Designed to scan-and-tap with a glance.
struct WatchTaskRow: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 8) {
            completeButton
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(task.status == .completed ? .secondary : .primary)
                    .strikethrough(task.status == .completed)
                    .lineLimit(1)
                if let due = task.dueDate, !task.allDay {
                    Text(due, format: .dateTime.hour().minute())
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
            if let list = task.list {
                Circle()
                    .fill(ListPalette.color(for: list.colorKey))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.gray.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var completeButton: some View {
        Button(action: complete) {
            ZStack {
                Circle()
                    .strokeBorder(checkBorder, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if task.status == .completed {
                    Circle()
                        .fill(Color.mint)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var checkBorder: Color {
        switch task.priority {
        case .high:   return .red
        case .medium: return .orange
        case .low, .none: return .gray
        }
    }

    private func complete() {
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.success)
        #endif
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            if task.status == .completed {
                task.status = .open
                task.completedAt = nil
            } else {
                task.status = .completed
                task.completedAt = .now
                task.modifiedAt = .now
            }
        }
        try? modelContext.save()
    }
}

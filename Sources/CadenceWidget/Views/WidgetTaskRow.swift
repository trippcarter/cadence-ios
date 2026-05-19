import SwiftUI
import AppIntents

/// Build 29: extracted from MediumWidgetView so SmallWidgetView's
/// "Next" block can reuse the same row. Also gained a "carried" chip
/// for tasks rolling over from previous days, and a tap-to-complete
/// circle that fires CompleteTaskFromWidgetIntent.
struct WidgetTaskRow: View {
    let task: WidgetTaskInfo

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: CompleteTaskFromWidgetIntent(taskID: task.id.uuidString)) {
                ZStack {
                    Circle()
                        .strokeBorder(ListPalette.color(for: task.colorKey), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    if task.isCompleted {
                        Circle()
                            .fill(ListPalette.color(for: task.colorKey))
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(task.isCompleted ? Tokens.Color.text3 : Tokens.Color.text)
                .strikethrough(task.isCompleted, color: Tokens.Color.text3)
                .lineLimit(1)

            if task.isCarriedOver {
                Text("carried")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Tokens.Color.amber.opacity(0.22))
                    .foregroundStyle(Tokens.Color.amber)
                    .clipShape(Capsule())
            }

            Spacer(minLength: 4)

            if let time = task.timeText {
                Text(time)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
                    .monospacedDigit()
            } else if task.allDay && !task.isCarriedOver {
                Text("all day")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }

            Circle()
                .fill(ListPalette.color(for: task.colorKey))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

/// Build 29: companion row for Google Calendar events. Same visual
/// language as the task row, with a calendar glyph in place of the
/// complete circle (events aren't completable) and a teal accent dot.
struct WidgetEventRow: View {
    let event: WidgetEventInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ListPalette.color(for: event.calendarColorKey))
                .frame(width: 16, height: 16)

            Text(event.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.Color.text)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let time = event.timeText {
                Text(time)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
                    .monospacedDigit()
            } else if event.isAllDay {
                Text("all day")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }

            Circle()
                .fill(ListPalette.color(for: event.calendarColorKey))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

/// Build 29: router view — renders the right row for a WidgetItem.
struct WidgetItemRow: View {
    let item: WidgetItem

    var body: some View {
        switch item {
        case .task(let t):  WidgetTaskRow(task: t)
        case .event(let e): WidgetEventRow(event: e)
        }
    }
}

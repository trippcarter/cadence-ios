import SwiftUI
import WidgetKit

// MARK: Circular — gauge-style task count

struct CircularLockView: View {
    let entry: CadenceWidgetEntry

    private var count: Int {
        entry.todaysTasks.filter { !$0.isCompleted }.count
    }

    var body: some View {
        // accessoryCircular renders monochrome; the system tints based on the
        // wallpaper. Aim for a clean numeric centerpiece with a tiny label.
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Text("\(count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(count == 1 ? "task" : "tasks")
                    .font(.system(size: 9, weight: .semibold))
                    .opacity(0.7)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetAccentable()
    }
}

// MARK: Rectangular — next-task summary

struct RectangularLockView: View {
    let entry: CadenceWidgetEntry

    private var next: WidgetTaskInfo? {
        entry.todaysTasks.first(where: { !$0.isCompleted })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("CADENCE · NEXT")
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.6)
                .opacity(0.7)
            if let next {
                if let time = next.timeText {
                    Text(time)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .widgetAccentable()
                }
                Text(next.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
            } else {
                Text("Nothing on your plate")
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: Inline — one-line summary

struct InlineLockView: View {
    let entry: CadenceWidgetEntry

    private var count: Int {
        entry.todaysTasks.filter { !$0.isCompleted }.count
    }

    private var next: WidgetTaskInfo? {
        entry.todaysTasks.first(where: { !$0.isCompleted })
    }

    var body: some View {
        if let next {
            if let time = next.timeText {
                Text("⏵ \(count) tasks · next \(time) \(next.title)")
            } else {
                Text("⏵ \(count) tasks · next: \(next.title)")
            }
        } else {
            Text("⏵ Nothing on your plate today")
        }
    }
}

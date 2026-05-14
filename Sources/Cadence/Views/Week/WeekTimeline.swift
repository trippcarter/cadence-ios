import SwiftUI

/// Hour-grid timeline (7 AM – 10 PM) with task blocks positioned at their times.
/// All-day tasks render in a separate band above the hour grid so they don't
/// stack on top of each other.
struct WeekTimeline: View {
    let tasks: [TaskItem]
    let day: Date
    let onTap: (TaskItem) -> Void

    private let startHour: Int = 7
    private let endHour: Int = 22
    private let hourHeight: CGFloat = 64
    private let labelColumnWidth: CGFloat = 56

    private var totalHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    private var timedTasks: [TaskItem] {
        tasks.filter { !$0.allDay }
    }

    private var allDayTasks: [TaskItem] {
        tasks.filter { $0.allDay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            if !allDayTasks.isEmpty {
                allDayBand
            }
            hourTimeline
        }
        .padding(.bottom, Tokens.Space.lg)
    }

    // MARK: All-day band

    private var allDayBand: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ALL DAY")
                .font(Tokens.Font.label)
                .kerning(1.0)
                .foregroundStyle(Tokens.Color.text3)
                .padding(.leading, labelColumnWidth + Tokens.Space.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.sm) {
                    ForEach(allDayTasks) { task in
                        allDayChip(task)
                    }
                }
                .padding(.leading, labelColumnWidth + Tokens.Space.lg)
                .padding(.trailing, Tokens.Space.lg)
            }
        }
    }

    private func allDayChip(_ task: TaskItem) -> some View {
        let tint = ListPalette.color(for: task.list?.colorKey ?? "violet")
        return Button {
            onTap(task)
        } label: {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 6, height: 6)
                Text(task.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: Hour timeline

    private var hourTimeline: some View {
        ZStack(alignment: .topLeading) {
            hourGrid
            timedBlocks
        }
        .frame(height: totalHeight)
    }

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(formatHour(hour))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Tokens.Color.text3)
                        .kerning(0.4)
                        .frame(width: labelColumnWidth, alignment: .leading)
                        .padding(.top, -6)
                        .padding(.leading, Tokens.Space.lg)
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Tokens.Color.borderSoft)
                            .frame(height: 0.5)
                        Spacer()
                    }
                }
                .frame(height: hourHeight)
            }
        }
    }

    private var timedBlocks: some View {
        ForEach(positioned, id: \.task.id) { entry in
            WeekTaskBlock(task: entry.task, height: entry.height)
                .offset(x: labelColumnWidth + Tokens.Space.lg, y: entry.yOffset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, Tokens.Space.lg + labelColumnWidth + Tokens.Space.lg)
                .onTapGesture { onTap(entry.task) }
        }
    }

    // MARK: Positioning math (timed only)

    private struct PositionedTask {
        let task: TaskItem
        let yOffset: CGFloat
        let height: CGFloat
    }

    private var positioned: [PositionedTask] {
        timedTasks.compactMap { task in
            guard let due = task.dueDate else { return nil }
            let cal = Calendar.current
            let hour = cal.component(.hour, from: due)
            let minute = cal.component(.minute, from: due)
            guard hour >= startHour, hour < endHour else { return nil }
            let hoursIntoDay = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
            let yOffset = hoursIntoDay * hourHeight
            let height: CGFloat = 30.0 / 60.0 * hourHeight  // default 30 min
            return PositionedTask(task: task, yOffset: yOffset, height: height)
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let isPM = hour >= 12
        let display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(display) \(isPM ? "PM" : "AM")"
    }
}

// MARK: - Task block (timed)

struct WeekTaskBlock: View {
    let task: TaskItem
    let height: CGFloat

    var body: some View {
        let tint = ListPalette.color(for: task.list?.colorKey ?? "violet")
        HStack(spacing: 6) {
            Rectangle()
                .fill(tint)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text)
                    .lineLimit(1)
                if let due = task.dueDate {
                    Text(due, format: .dateTime.hour().minute())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Tokens.Color.text3)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: height, alignment: .top)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.4), lineWidth: 0.5)
        )
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var label = "Task: \(task.title)"
        if let due = task.dueDate, !task.allDay {
            label += ", at " + due.formatted(.dateTime.hour().minute())
        }
        if let list = task.list { label += ", in \(list.name)" }
        return label
    }
}

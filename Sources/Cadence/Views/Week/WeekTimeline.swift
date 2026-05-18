import SwiftUI

/// Hour-grid timeline (7 AM – 10 PM) with task blocks positioned at their times.
/// All-day tasks render in a separate band above the hour grid so they don't
/// stack on top of each other.
struct WeekTimeline: View {
    let tasks: [TaskItem]
    let events: [CachedEvent]
    let day: Date
    let onTapTask: (TaskItem) -> Void
    let onTapEvent: (CachedEvent) -> Void

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

    private var timedEvents: [CachedEvent] {
        events.filter { !$0.isAllDay }
    }

    private var allDayEvents: [CachedEvent] {
        events.filter { $0.isAllDay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            if !allDayTasks.isEmpty || !allDayEvents.isEmpty {
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
                    ForEach(allDayEvents) { event in
                        allDayEventChip(event)
                    }
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
            onTapTask(task)
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

    private func allDayEventChip(_ event: CachedEvent) -> some View {
        Button { onTapEvent(event) } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 9, weight: .semibold))
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Tokens.Color.teal.opacity(0.14))
            .foregroundStyle(Tokens.Color.teal)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Tokens.Color.teal.opacity(0.4), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: Hour timeline

    private var hourTimeline: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                hourGrid
                timedBlocks(in: proxy.size.width)
            }
        }
        .frame(height: totalHeight)
        .sheet(isPresented: Binding(
            get: { overflowAnchorID != nil },
            set: { if !$0 { overflowAnchorID = nil } }
        )) {
            overflowSheet
        }
    }

    @State private var overflowAnchorID: String?

    /// Common time-range entries for the overlap layout (tasks + events).
    private var overlapEntries: [OverlapLayout.Entry] {
        var out: [OverlapLayout.Entry] = []
        for task in timedTasks {
            guard let due = task.dueDate else { continue }
            out.append(.init(id: "task-\(task.id.uuidString)", start: due, end: due.addingTimeInterval(30 * 60)))
        }
        for event in timedEvents {
            let durationSec = max(event.end.timeIntervalSince(event.start), 1800)
            let clamped = min(durationSec, 4 * 3600)
            out.append(.init(id: "event-\(event.id)", start: event.start, end: event.start.addingTimeInterval(clamped)))
        }
        return out
    }

    private var layouts: [String: OverlapLayout.Position] {
        OverlapLayout.positions(for: overlapEntries)
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

    private func timedBlocks(in containerWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(positionedTasks, id: \.task.id) { entry in
                let entryID = "task-\(entry.task.id.uuidString)"
                if let layout = layouts[entryID], !layout.isOverflow {
                    let frame = blockFrame(for: layout, containerWidth: containerWidth)
                    WeekTaskBlock(task: entry.task, height: entry.height, overflowCount: layout.overflowCount)
                        .frame(width: frame.width)
                        .offset(x: frame.x, y: entry.yOffset)
                        .onTapGesture {
                            if layout.overflowCount > 0 {
                                overflowAnchorID = entryID
                            } else {
                                onTapTask(entry.task)
                            }
                        }
                }
            }
            ForEach(positionedEvents, id: \.event.id) { entry in
                let entryID = "event-\(entry.event.id)"
                if let layout = layouts[entryID], !layout.isOverflow {
                    let frame = blockFrame(for: layout, containerWidth: containerWidth)
                    WeekEventBlock(event: entry.event, height: entry.height, overflowCount: layout.overflowCount)
                        .frame(width: frame.width)
                        .offset(x: frame.x, y: entry.yOffset)
                        .onTapGesture {
                            if layout.overflowCount > 0 {
                                overflowAnchorID = entryID
                            } else {
                                onTapEvent(entry.event)
                            }
                        }
                }
            }
        }
    }

    private func blockFrame(for layout: OverlapLayout.Position, containerWidth: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let leading = labelColumnWidth + Tokens.Space.lg
        let trailing: CGFloat = Tokens.Space.lg
        let trackWidth = max(containerWidth - leading - trailing, 60)
        let gutter: CGFloat = 3
        let columnWidth = (trackWidth - CGFloat(layout.columnCount - 1) * gutter) / CGFloat(layout.columnCount)
        let x = leading + CGFloat(layout.columnIndex) * (columnWidth + gutter)
        return (x, max(columnWidth, 40))
    }

    // MARK: Positioning math (timed only)

    private struct PositionedTask {
        let task: TaskItem
        let yOffset: CGFloat
        let height: CGFloat
    }

    private struct PositionedEvent {
        let event: CachedEvent
        let yOffset: CGFloat
        let height: CGFloat
    }

    private var positionedTasks: [PositionedTask] {
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

    private var positionedEvents: [PositionedEvent] {
        timedEvents.compactMap { event in
            let cal = Calendar.current
            let hour = cal.component(.hour, from: event.start)
            let minute = cal.component(.minute, from: event.start)
            guard hour >= startHour, hour < endHour else { return nil }
            let hoursIntoDay = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
            let yOffset = hoursIntoDay * hourHeight
            // Duration → height, clamped between 30 min and 4 hr for sanity.
            let durationSec = max(event.end.timeIntervalSince(event.start), 1800)
            let clampedSec = min(durationSec, 4 * 3600)
            let height = CGFloat(clampedSec / 3600.0) * hourHeight
            return PositionedEvent(event: event, yOffset: yOffset, height: height)
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let isPM = hour >= 12
        let display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(display) \(isPM ? "PM" : "AM")"
    }

    // MARK: Overflow expansion sheet

    @ViewBuilder
    private var overflowSheet: some View {
        let anchorID = overflowAnchorID ?? ""
        let anchorEntry = overlapEntries.first { $0.id == anchorID }
        if let anchorEntry {
            let cluster = clusterMembers(containing: anchorEntry)
            NavigationStack {
                List {
                    Section {
                        ForEach(cluster, id: \.id) { entry in
                            overflowRow(entry: entry)
                        }
                    } header: {
                        Text("Overlapping at this time")
                            .font(Tokens.Font.label)
                            .foregroundStyle(Tokens.Color.text3)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("More")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { overflowAnchorID = nil }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func overflowRow(entry: OverlapLayout.Entry) -> some View {
        if entry.id.hasPrefix("task-") {
            let uuidString = String(entry.id.dropFirst("task-".count))
            if let uuid = UUID(uuidString: uuidString),
               let task = timedTasks.first(where: { $0.id == uuid }) {
                let tint = ListPalette.color(for: task.list?.colorKey ?? "violet")
                Button {
                    overflowAnchorID = nil
                    onTapTask(task)
                } label: {
                    overflowRowContent(title: task.title,
                                       subtitle: entry.start.formatted(.dateTime.hour().minute()),
                                       tint: tint,
                                       icon: nil)
                }
                .buttonStyle(.plain)
            }
        } else if entry.id.hasPrefix("event-") {
            let eventID = String(entry.id.dropFirst("event-".count))
            if let event = timedEvents.first(where: { $0.id == eventID }) {
                Button {
                    overflowAnchorID = nil
                    onTapEvent(event)
                } label: {
                    overflowRowContent(
                        title: event.title,
                        subtitle: "\(event.start.formatted(.dateTime.hour().minute())) – \(event.end.formatted(.dateTime.hour().minute()))",
                        tint: Tokens.Color.teal,
                        icon: "calendar"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func overflowRowContent(title: String, subtitle: String, tint: Color, icon: String?) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Rectangle().fill(tint).frame(width: 3, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(tint) }
                    Text(title).font(Tokens.Font.bodyEmphasis)
                }
                Text(subtitle).font(Tokens.Font.caption).foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
    }

    private func clusterMembers(containing anchor: OverlapLayout.Entry) -> [OverlapLayout.Entry] {
        let sorted = overlapEntries.sorted { $0.start < $1.start }
        var cluster: [OverlapLayout.Entry] = []
        var currentEnd: Date = .distantPast
        for entry in sorted {
            if cluster.isEmpty {
                cluster = [entry]
                currentEnd = entry.end
            } else if entry.start < currentEnd {
                cluster.append(entry)
                currentEnd = max(currentEnd, entry.end)
            } else {
                if cluster.contains(where: { $0.id == anchor.id }) { return cluster }
                cluster = [entry]
                currentEnd = entry.end
            }
        }
        return cluster
    }
}

// MARK: - Event block (timed)

struct WeekEventBlock: View {
    let event: CachedEvent
    let height: CGFloat
    var overflowCount: Int = 0

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Tokens.Color.teal)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9, weight: .semibold))
                    Text(event.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tokens.Color.text)
                        .lineLimit(1)
                }
                Text(event.start, format: .dateTime.hour().minute())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Tokens.Color.text3)
                if overflowCount > 0 {
                    Text("+\(overflowCount) more")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Tokens.Color.teal)
                        .padding(.top, 1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: height, alignment: .top)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Tokens.Color.teal.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Tokens.Color.teal.opacity(0.45), lineWidth: 0.5)
        )
    }
}

// MARK: - Task block (timed)

struct WeekTaskBlock: View {
    let task: TaskItem
    let height: CGFloat
    var overflowCount: Int = 0

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
                if overflowCount > 0 {
                    Text("+\(overflowCount) more")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tint)
                        .padding(.top, 1)
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

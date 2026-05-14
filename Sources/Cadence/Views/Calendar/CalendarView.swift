import SwiftUI
import SwiftData

struct CalendarView: View {
    @State private var mode: CalendarMode = {
        switch AppLaunchArgs.calendarMode {
        case "day":   return .day
        case "month": return .month
        case "year":  return .year
        default:      return .week
        }
    }()
    @State private var referenceDate: Date = .now
    @State private var detailTask: TaskItem?
    @State private var detailEvent: CachedEvent?
    @State private var showingAddTask = false
    @State private var addTaskDate: Date?

    var body: some View {
        ZStack(alignment: .top) {
            Tokens.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                modePicker
                header
                Divider().background(Tokens.Color.borderSoft)
                content
            }
        }
        .sheet(item: $detailTask) { task in
            TaskDetailSheet(task: task)
        }
        .sheet(item: $detailEvent) { event in
            EventDetailSheet(event: event)
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet()
        }
    }

    // MARK: Mode picker

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(CalendarMode.allCases) { m in
                Button {
                    Haptics.tap()
                    withAnimation(.bouncy(duration: 0.35)) {
                        mode = m
                    }
                } label: {
                    Text(m.label)
                        .font(Tokens.Font.bodyEmphasis)
                        .padding(.vertical, Tokens.Space.sm)
                        .frame(maxWidth: .infinity)
                        .background(mode == m ? Tokens.Color.accent.opacity(0.20) : Color.clear)
                        .foregroundStyle(mode == m ? Tokens.Color.accent2 : Tokens.Color.text2)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(m.label) view")
            }
        }
        .padding(4)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md + 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md + 2, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.top, Tokens.Space.md)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(modeEyebrow)
                    .font(Tokens.Font.label)
                    .kerning(1.0)
                    .foregroundStyle(Tokens.Color.text3)
                Text(mode.headerTitle(for: referenceDate))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Tokens.Color.text)
                    .contentTransition(.numericText())
                    .animation(.smooth, value: referenceDate)
            }
            Spacer()
            if !Calendar.current.isDate(referenceDate, equalTo: .now, toGranularity: granularity) {
                Button {
                    withAnimation(.bouncy(duration: 0.5)) {
                        referenceDate = .now
                    }
                    Haptics.tap()
                } label: {
                    Text("Today")
                        .font(Tokens.Font.bodyEmphasis)
                        .padding(.horizontal, Tokens.Space.md)
                        .padding(.vertical, 6)
                        .background(Tokens.Color.accent.opacity(0.18))
                        .foregroundStyle(Tokens.Color.accent2)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Button {
                addTaskDate = mode.normalize(referenceDate)
                showingAddTask = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(8)
                    .background(Tokens.Color.surface2)
                    .foregroundStyle(Tokens.Color.accent2)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Tokens.Color.borderSoft, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add task")
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    private var modeEyebrow: String {
        switch mode {
        case .day:   return "DAY"
        case .week:  return "WEEK"
        case .month: return "MONTH"
        case .year:  return "YEAR"
        }
    }

    private var granularity: Calendar.Component {
        switch mode {
        case .day:   return .day
        case .week:  return .weekOfYear
        case .month: return .month
        case .year:  return .year
        }
    }

    // MARK: Content switcher

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .day:
            CalendarDayView(
                referenceDate: $referenceDate,
                onTapTask: { detailTask = $0 },
                onTapEvent: { detailEvent = $0 }
            )
        case .week:
            CalendarWeekView(
                referenceDate: $referenceDate,
                onTapTask: { detailTask = $0 },
                onTapEvent: { detailEvent = $0 }
            )
        case .month:
            CalendarMonthView(referenceDate: $referenceDate) { day in
                referenceDate = day
                withAnimation(.bouncy(duration: 0.4)) { mode = .day }
            }
        case .year:
            CalendarYearView(referenceDate: $referenceDate) { month in
                referenceDate = month
                withAnimation(.bouncy(duration: 0.4)) { mode = .month }
            }
        }
    }
}

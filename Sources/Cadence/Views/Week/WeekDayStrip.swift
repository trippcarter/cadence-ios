import SwiftUI

/// 7-day pill row across the top of the Week view.
struct WeekDayStrip: View {
    let days: [Date]
    @Binding var selectedDay: Date
    /// For each day in `days`, the colored dots to render under the day number.
    let dotsFor: (Date) -> [Color]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.timeIntervalSince1970) { day in
                DayCell(
                    day: day,
                    isToday: Calendar.current.isDateInToday(day),
                    isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDay),
                    dots: dotsFor(day)
                ) {
                    Haptics.tap()
                    withAnimation(.bouncy(duration: 0.35)) {
                        selectedDay = day
                    }
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: Date
    let isToday: Bool
    let isSelected: Bool
    let dots: [Color]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(day, format: .dateTime.weekday(.narrow))
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(Tokens.Color.text3)
                Text(day, format: .dateTime.day(.defaultDigits))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isSelected ? Tokens.Color.text : Tokens.Color.text2)
                dotRow
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.md)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }

    private var dotRow: some View {
        HStack(spacing: 3) {
            ForEach(0..<min(dots.count, 3), id: \.self) { idx in
                Circle()
                    .fill(dots[idx])
                    .frame(width: 4, height: 4)
            }
            if dots.isEmpty {
                Circle().fill(Color.clear).frame(width: 4, height: 4)
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private var background: some View {
        if isToday {
            LinearGradient(
                colors: [
                    Tokens.Color.accent.opacity(0.22),
                    Tokens.Color.accent.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isSelected {
            Tokens.Color.surface2
        } else {
            Tokens.Color.surface
        }
    }

    private var borderColor: Color {
        if isToday { return Tokens.Color.accent.opacity(0.5) }
        if isSelected { return Tokens.Color.accent.opacity(0.35) }
        return Tokens.Color.borderSoft
    }

    private var borderWidth: CGFloat {
        (isToday || isSelected) ? 1 : 0.5
    }

    private var accessibilityText: String {
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEEE, MMM d"
        var label = dayFmt.string(from: day)
        if isToday { label += ", today" }
        if isSelected { label += ", selected" }
        if !dots.isEmpty {
            label += ", \(dots.count) task\(dots.count == 1 ? "" : "s") scheduled"
        }
        return label
    }
}

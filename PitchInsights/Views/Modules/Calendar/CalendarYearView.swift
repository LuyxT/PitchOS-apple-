import SwiftUI

struct CalendarYearView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let events: [CalendarEvent]
    let categories: [CalendarCategory]

    private var columns: [GridItem] {
        if isPhoneLayout {
            return Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
        }
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: isPhoneLayout ? 12 : 16) {
                ForEach(0..<12, id: \.self) { monthIndex in
                    yearMonthCard(monthIndex: monthIndex)
                }
            }
            .padding(isPhoneLayout ? 12 : 16)
        }
        .background(AppTheme.surface)
    }

    private func yearMonthCard(monthIndex: Int) -> some View {
        let calendar = viewModel.calendar
        let year = calendar.component(.year, from: viewModel.focusDate)
        var components = DateComponents()
        components.year = year
        components.month = monthIndex + 1
        components.day = 1
        let monthDate = calendar.date(from: components) ?? viewModel.focusDate

        return VStack(alignment: .leading, spacing: 8) {
            Text(monthDate, format: .dateTime.month(.wide))
                .font(.system(size: isPhoneLayout ? 15 : 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            MiniMonthGrid(
                calendar: calendar,
                monthDate: monthDate,
                events: events,
                isPhoneLayout: isPhoneLayout
            )
        }
        .padding(isPhoneLayout ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceAlt)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .onTapGesture {
            viewModel.focusDate = monthDate
            viewModel.viewMode = .month
        }
    }

    private var isPhoneLayout: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
}

private struct MiniMonthGrid: View {
    let calendar: Calendar
    let monthDate: Date
    let events: [CalendarEvent]
    let isPhoneLayout: Bool

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: isPhoneLayout ? 3 : 2), count: 7)
    }

    var body: some View {
        let days = monthDates()
        LazyVGrid(columns: columns, spacing: isPhoneLayout ? 3 : 2) {
            ForEach(days, id: \.self) { date in
                let isCurrentMonth = calendar.isDate(date, equalTo: monthDate, toGranularity: .month)
                let hasEvent = events.contains { calendar.isDate($0.startDate, inSameDayAs: date) }

                Text(String(calendar.component(.day, from: date)))
                    .font(.system(size: isPhoneLayout ? 10 : 9, weight: .medium))
                    .foregroundStyle(isCurrentMonth ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: isPhoneLayout ? 16 : 14)
                    .background(
                        RoundedRectangle(cornerRadius: isPhoneLayout ? 4 : 3, style: .continuous)
                            .fill(hasEvent ? AppTheme.primary.opacity(0.2) : Color.clear)
                    )
            }
        }
    }

    private func monthDates() -> [Date] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) ?? monthDate
        let range = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1..<31
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        let total = range.count + offset
        let totalCells = Int(ceil(Double(total) / 7.0)) * 7

        return (0..<totalCells).compactMap { index in
            let dayOffset = index - offset
            return calendar.date(byAdding: .day, value: dayOffset, to: startOfMonth)
        }
    }
}

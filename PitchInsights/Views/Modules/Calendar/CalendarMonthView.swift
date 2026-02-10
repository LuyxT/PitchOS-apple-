import SwiftUI

struct CalendarMonthView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: CalendarViewModel
    let events: [CalendarEvent]
    let categories: [CalendarCategory]
    @Binding var hoverSlot: CalendarSlot?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            weekdayHeader

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(monthDates(), id: \.self) { date in
                    monthCell(for: date)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.top, 12)
        .background(AppTheme.surface)
    }

    private var weekdayHeader: some View {
        let symbols = weekdaySymbols()
        return HStack(spacing: 0) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }

    private func weekdaySymbols() -> [String] {
        let symbols = viewModel.calendar.shortWeekdaySymbols
        let startIndex = max(0, viewModel.calendar.firstWeekday - 1)
        let ordered = Array(symbols[startIndex...] + symbols[..<startIndex])
        return ordered
    }

    private func monthCell(for date: Date) -> some View {
        let isCurrentMonth = viewModel.calendar.isDate(date, equalTo: viewModel.focusDate, toGranularity: .month)
        let dayEvents = events.filter { viewModel.calendar.isDate($0.startDate, inSameDayAs: date) }
        let slot = CalendarSlot(date: date, hour: nil)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String(viewModel.calendar.component(.day, from: date)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isCurrentMonth ? AppTheme.textPrimary : AppTheme.textSecondary)
                Spacer()
                Button {
                    if let createDate = viewModel.calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) {
                        Haptics.trigger(.soft)
                        viewModel.beginCreate(at: createDate)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.primary)
                        .opacity(hoverSlot == slot ? 1 : 0)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(dayEvents.prefix(2)) { event in
                    CalendarEventPill(
                        event: event,
                        category: categories.first(where: { $0.id == event.categoryID })
                    )
                    .onTapGesture {
                        Haptics.trigger(.light)
                        viewModel.selectedEventID = event.id
                    }
                    .onTapGesture(count: 2) {
                        Haptics.trigger(.light)
                        viewModel.beginEdit(event: event)
                    }
                    .contextMenu {
                        Button("Bearbeiten") {
                            Haptics.trigger(.light)
                            viewModel.beginEdit(event: event)
                        }
                        Button("Duplizieren") {
                            Haptics.trigger(.soft)
                            Task {
                                await dataStore.duplicateCalendarEvent(event)
                            }
                        }
                        Divider()
                        Button("Löschen", role: .destructive) {
                            Haptics.trigger(.soft)
                            Task {
                                await dataStore.deleteCalendarEvent(id: event.id)
                            }
                        }
                    }
                }

                if dayEvents.count > 2 {
                    Text("+\(dayEvents.count - 2) weitere")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(minHeight: 96, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isCurrentMonth ? AppTheme.surfaceAlt : AppTheme.surfaceAlt.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .onHover { hovering in
            hoverSlot = hovering ? slot : nil
        }
        .onTapGesture {
            Haptics.trigger(.light)
            viewModel.focusDate = date
        }
        .interactiveSurface(hoverScale: 1.008, pressScale: 0.992, hoverShadowOpacity: 0.08, feedback: nil)
        .animation(AppMotion.hover, value: hoverSlot == slot)
    }

    private func monthDates() -> [Date] {
        let calendar = viewModel.calendar
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: viewModel.focusDate)) ?? viewModel.focusDate
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

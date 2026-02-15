import SwiftUI

struct CalendarMonthView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: CalendarViewModel
    let events: [CalendarEvent]
    let categories: [CalendarCategory]
    @Binding var hoverSlot: CalendarSlot?

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: isCompactPhoneLayout ? 4 : 8), count: 7)
    }

    var body: some View {
        VStack(spacing: isCompactPhoneLayout ? 6 : 8) {
            weekdayHeader

            LazyVGrid(columns: columns, spacing: isCompactPhoneLayout ? 4 : 8) {
                ForEach(monthDates(), id: \.self) { date in
                    monthCell(for: date)
                }
            }
            .padding(.horizontal, isCompactPhoneLayout ? 10 : 16)
            .padding(.bottom, isCompactPhoneLayout ? 10 : 12)
        }
        .padding(.top, isCompactPhoneLayout ? 8 : 12)
        .background(AppTheme.surface)
    }

    private var weekdayHeader: some View {
        let symbols = weekdaySymbols()
        return HStack(spacing: 0) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: isCompactPhoneLayout ? 10 : 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, isCompactPhoneLayout ? 10 : 16)
    }

    private func weekdaySymbols() -> [String] {
        let symbols = viewModel.calendar.shortWeekdaySymbols
        let startIndex = max(0, viewModel.calendar.firstWeekday - 1)
        let ordered = Array(symbols[startIndex...] + symbols[..<startIndex])
        if isCompactPhoneLayout {
            return ordered.map { String($0.prefix(2)) }
        }
        return ordered
    }

    @ViewBuilder
    private func monthCell(for date: Date) -> some View {
        let isCurrentMonth = viewModel.calendar.isDate(date, equalTo: viewModel.focusDate, toGranularity: .month)
        let dayEvents = events.filter { viewModel.calendar.isDate($0.startDate, inSameDayAs: date) }
        let slot = CalendarSlot(date: date, hour: nil)

        if isCompactPhoneLayout {
            compactMonthCell(for: date, isCurrentMonth: isCurrentMonth, dayEvents: dayEvents, slot: slot)
        } else {
            VStack(alignment: .leading, spacing: 6) {
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
    }

    private func compactMonthCell(
        for date: Date,
        isCurrentMonth: Bool,
        dayEvents: [CalendarEvent],
        slot: CalendarSlot
    ) -> some View {
        let isToday = viewModel.calendar.isDateInToday(date)

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(String(viewModel.calendar.component(.day, from: date)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isCurrentMonth ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if isToday {
                    Circle()
                        .fill(AppTheme.primary)
                        .frame(width: 4, height: 4)
                }

                Spacer(minLength: 2)

                if dayEvents.count > 0 {
                    Text("\(dayEvents.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppTheme.surface)
                        )
                }
            }

            if !dayEvents.isEmpty {
                HStack(spacing: 3) {
                    ForEach(Array(dayEvents.prefix(3).enumerated()), id: \.offset) { _, event in
                        Circle()
                            .fill(categories.first(where: { $0.id == event.categoryID })?.color ?? AppTheme.primary)
                            .frame(width: 5, height: 5)
                    }
                    if dayEvents.count > 3 {
                        Text("+\(dayEvents.count - 3)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(height: 72, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isCurrentMonth ? AppTheme.surfaceAlt : AppTheme.surfaceAlt.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .onTapGesture {
            Haptics.trigger(.light)
            viewModel.focusDate = date
            if let first = dayEvents.first {
                viewModel.selectedEventID = first.id
            }
        }
        .onLongPressGesture {
            if let createDate = viewModel.calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) {
                Haptics.trigger(.soft)
                viewModel.beginCreate(at: createDate)
            }
        }
        .onHover { hovering in
            hoverSlot = hovering ? slot : nil
        }
    }

    private var isCompactPhoneLayout: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
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

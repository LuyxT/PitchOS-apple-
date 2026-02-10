import SwiftUI

struct CalendarWeekView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: CalendarViewModel
    let events: [CalendarEvent]
    let categories: [CalendarCategory]
    @Binding var hoverSlot: CalendarSlot?

    private let hourRowHeight: CGFloat = 52

    var body: some View {
        let weekStart = viewModel.startOfWeek(for: viewModel.focusDate)
        let days = (0..<7).compactMap { viewModel.calendar.date(byAdding: .day, value: $0, to: weekStart) }

        VStack(spacing: 0) {
            headerRow(days: days)

            ScrollView {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 54, height: hourRowHeight, alignment: .topLeading)
                                .padding(.top, 6)
                        }
                    }

                    GeometryReader { proxy in
                        let columnWidth = proxy.size.width / CGFloat(days.count)
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) {
                                ForEach(0..<24, id: \.self) { hour in
                                    weekGridRow(hour: hour, days: days)
                                }
                            }

                            ForEach(eventsForWeek(days: days)) { event in
                                if let dayIndex = dayIndex(for: event.startDate, days: days) {
                                    CalendarEventBlock(
                                        event: event,
                                        category: categories.first(where: { $0.id == event.categoryID }),
                                        isSelected: viewModel.selectedEventID == event.id,
                                        onSelect: { viewModel.selectedEventID = event.id },
                                        onEdit: { viewModel.beginEdit(event: event) },
                                        onDuplicate: {
                                            Task { await dataStore.duplicateCalendarEvent(event) }
                                        },
                                        onDelete: {
                                            Task { await dataStore.deleteCalendarEvent(id: event.id) }
                                        }
                                    )
                                    .frame(width: columnWidth - 10, height: eventHeight(for: event))
                                    .offset(x: CGFloat(dayIndex) * columnWidth + 5, y: eventOffset(for: event))
                                }
                            }
                        }
                        .frame(height: hourRowHeight * 24)
                    }
                    .frame(height: hourRowHeight * 24)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(AppTheme.surface)
    }

    private func headerRow(days: [Date]) -> some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 54)

            ForEach(days, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(day, format: .dateTime.weekday(.short))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(day, format: .dateTime.day())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .background(AppTheme.surfaceAlt)
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 0.5))
    }

    private func weekGridRow(hour: Int, days: [Date]) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let slot = CalendarSlot(date: day, hour: hour)
                ZStack(alignment: .topTrailing) {
                    Rectangle()
                        .fill(AppTheme.surfaceAlt.opacity(hour % 2 == 0 ? 0.35 : 0.2))
                        .frame(height: hourRowHeight)
                        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 0.4))

                    Button {
                        if let date = viewModel.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) {
                            viewModel.beginCreate(at: date)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                            .opacity(hoverSlot == slot ? 1 : 0)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
                .onHover { hovering in
                    hoverSlot = hovering ? slot : nil
                }
            }
        }
    }

    private func eventsForWeek(days: [Date]) -> [CalendarEvent] {
        events.filter { event in
            days.contains { viewModel.calendar.isDate(event.startDate, inSameDayAs: $0) }
        }
    }

    private func dayIndex(for date: Date, days: [Date]) -> Int? {
        days.firstIndex { viewModel.calendar.isDate($0, inSameDayAs: date) }
    }

    private func eventOffset(for event: CalendarEvent) -> CGFloat {
        let startOfDay = viewModel.calendar.startOfDay(for: event.startDate)
        let minutes = viewModel.calendar.dateComponents([.minute], from: startOfDay, to: event.startDate).minute ?? 0
        let minuteHeight = hourRowHeight / 60
        return CGFloat(minutes) * minuteHeight
    }

    private func eventHeight(for event: CalendarEvent) -> CGFloat {
        let minutes = max(15, viewModel.calendar.dateComponents([.minute], from: event.startDate, to: event.endDate).minute ?? 0)
        let minuteHeight = hourRowHeight / 60
        return CGFloat(minutes) * minuteHeight
    }
}

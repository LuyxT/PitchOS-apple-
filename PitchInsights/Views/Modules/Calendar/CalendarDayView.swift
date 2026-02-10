import SwiftUI

struct CalendarDayView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: CalendarViewModel
    let events: [CalendarEvent]
    let categories: [CalendarCategory]
    @Binding var hoverSlot: CalendarSlot?

    private let hourRowHeight: CGFloat = 52

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 54, height: hourRowHeight, alignment: .topLeading)
                            .padding(.top, 6)
                    }
                }

                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            hourRow(hour: hour)
                        }
                    }

                    ForEach(eventsForDay()) { event in
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
                        .frame(height: eventHeight(for: event))
                        .offset(x: 8, y: eventOffset(for: event))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppTheme.surface)
    }

    private func hourRow(hour: Int) -> some View {
        let day = viewModel.focusDate
        let slot = CalendarSlot(date: day, hour: hour)
        return ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(AppTheme.surfaceAlt.opacity(hour % 2 == 0 ? 0.4 : 0.2))
                .frame(height: hourRowHeight)
                .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 0.5))

            Button {
                if let date = viewModel.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) {
                    Haptics.trigger(.soft)
                    viewModel.beginCreate(at: date)
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.primary)
                    .opacity(hoverSlot == slot ? 1 : 0)
                    .scaleEffect(hoverSlot == slot ? 1 : 0.9)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .onHover { hovering in
            hoverSlot = hovering ? slot : nil
        }
        .animation(AppMotion.hover, value: hoverSlot == slot)
    }

    private func eventsForDay() -> [CalendarEvent] {
        events.filter { viewModel.calendar.isDate($0.startDate, inSameDayAs: viewModel.focusDate) }
    }

    private func eventOffset(for event: CalendarEvent) -> CGFloat {
        let calendar = viewModel.calendar
        let startOfDay = calendar.startOfDay(for: event.startDate)
        let minutes = calendar.dateComponents([.minute], from: startOfDay, to: event.startDate).minute ?? 0
        let minuteHeight = hourRowHeight / 60
        return CGFloat(minutes) * minuteHeight
    }

    private func eventHeight(for event: CalendarEvent) -> CGFloat {
        let calendar = viewModel.calendar
        let minutes = max(15, calendar.dateComponents([.minute], from: event.startDate, to: event.endDate).minute ?? 0)
        let minuteHeight = hourRowHeight / 60
        return CGFloat(minutes) * minuteHeight
    }
}

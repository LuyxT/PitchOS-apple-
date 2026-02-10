import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @StateObject private var viewModel = CalendarViewModel()
    @State private var hoverSlot: CalendarSlot?

    var body: some View {
        VStack(spacing: 0) {
            CalendarToolbarView(viewModel: viewModel) {
                viewModel.beginCreate(at: Date())
            }

            Divider()

            Group {
                switch viewModel.viewMode {
                case .day:
                    CalendarDayView(
                        viewModel: viewModel,
                        events: dataStore.calendarEvents,
                        categories: dataStore.calendarCategories,
                        hoverSlot: $hoverSlot
                    )
                case .week:
                    CalendarWeekView(
                        viewModel: viewModel,
                        events: dataStore.calendarEvents,
                        categories: dataStore.calendarCategories,
                        hoverSlot: $hoverSlot
                    )
                case .month:
                    CalendarMonthView(
                        viewModel: viewModel,
                        events: dataStore.calendarEvents,
                        categories: dataStore.calendarCategories,
                        hoverSlot: $hoverSlot
                    )
                case .year:
                    CalendarYearView(
                        viewModel: viewModel,
                        events: dataStore.calendarEvents,
                        categories: dataStore.calendarCategories
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.surface)
        }
        .background(AppTheme.surface)
        .popover(isPresented: $viewModel.isPresentingPopover, arrowEdge: .top) {
            CalendarEventPopover(
                viewModel: viewModel,
                categories: $dataStore.calendarCategories,
                players: dataStore.players
            ) { draft, isEditing, selectedID in
                Task {
                    if isEditing, let id = selectedID {
                        await dataStore.updateCalendarEvent(id: id, draft: draft)
                    } else {
                        await dataStore.createCalendarEvent(draft)
                    }
                    viewModel.closePopover()
                }
            } onDelete: { id in
                Task {
                    await dataStore.deleteCalendarEvent(id: id)
                    viewModel.closePopover()
                }
            }
            .frame(width: 320)
            .padding()
        }
        #if os(macOS)
        .onMoveCommand { direction in
            switch direction {
            case .left, .up:
                viewModel.goToPrevious()
            case .right, .down:
                viewModel.goToNext()
            default:
                break
            }
        }
        .onDeleteCommand {
            guard let id = viewModel.selectedEventID else { return }
            Task {
                await dataStore.deleteCalendarEvent(id: id)
                viewModel.selectedEventID = nil
            }
        }
        #endif
    }
}

#Preview {
    CalendarView()
        .environmentObject(AppDataStore())
        .frame(width: 1000, height: 700)
}

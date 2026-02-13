import SwiftUI
import Combine

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var viewMode: CalendarViewMode = .month
    @Published var focusDate: Date = Date()
    @Published var selectedEventID: UUID?
    @Published var isPresentingPopover = false
    @Published var draft: CalendarEventDraft = CalendarEventDraft()
    @Published var isEditing = false

    var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    func goToToday() {
        focusDate = Date()
    }

    func goToPrevious() {
        switch viewMode {
        case .day:
            focusDate = calendar.date(byAdding: .day, value: -1, to: focusDate) ?? focusDate
        case .week:
            focusDate = calendar.date(byAdding: .weekOfYear, value: -1, to: focusDate) ?? focusDate
        case .month:
            focusDate = calendar.date(byAdding: .month, value: -1, to: focusDate) ?? focusDate
        case .year:
            focusDate = calendar.date(byAdding: .year, value: -1, to: focusDate) ?? focusDate
        }
    }

    func goToNext() {
        switch viewMode {
        case .day:
            focusDate = calendar.date(byAdding: .day, value: 1, to: focusDate) ?? focusDate
        case .week:
            focusDate = calendar.date(byAdding: .weekOfYear, value: 1, to: focusDate) ?? focusDate
        case .month:
            focusDate = calendar.date(byAdding: .month, value: 1, to: focusDate) ?? focusDate
        case .year:
            focusDate = calendar.date(byAdding: .year, value: 1, to: focusDate) ?? focusDate
        }
    }

    func rangeTitle() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")

        switch viewMode {
        case .day:
            formatter.dateFormat = "EEEE, d. MMMM yyyy"
            return formatter.string(from: focusDate)
        case .week:
            let week = calendar.component(.weekOfYear, from: focusDate)
            formatter.dateFormat = "MMMM yyyy"
            return "KW \(week) · \(formatter.string(from: focusDate))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: focusDate)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: focusDate)
        }
    }

    func startOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    func beginCreate(at date: Date) {
        isEditing = false
        selectedEventID = nil
        let endDate = calendar.date(byAdding: .minute, value: 90, to: date) ?? date
        draft = CalendarEventDraft(
            title: "",
            startDate: date,
            endDate: endDate,
            categoryID: CalendarCategory.training.id,
            visibility: .team,
            audience: .team,
            audiencePlayerIDs: [],
            recurrence: .none,
            location: "",
            notes: ""
        )
        isPresentingPopover = true
    }

    func beginEdit(event: CalendarEvent) {
        isEditing = true
        selectedEventID = event.id
        draft = CalendarEventDraft(
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            categoryID: event.categoryID,
            visibility: event.visibility,
            audience: event.audience,
            audiencePlayerIDs: event.audiencePlayerIDs,
            recurrence: event.recurrence,
            location: event.location,
            notes: event.notes
        )
        isPresentingPopover = true
    }

    func closePopover() {
        isPresentingPopover = false
        isEditing = false
        selectedEventID = nil
    }
}

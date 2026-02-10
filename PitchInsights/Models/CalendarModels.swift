import SwiftUI

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case day = "Tag"
    case week = "Woche"
    case month = "Monat"
    case year = "Jahr"

    var id: String { rawValue }
}

enum CalendarVisibility: String, CaseIterable, Identifiable, Codable {
    case team = "Öffentlich"
    case `private` = "Privat"

    var id: String { rawValue }
}

enum CalendarAudience: String, CaseIterable, Identifiable, Codable {
    case team = "Team"
    case group = "Gruppe"
    case individual = "Einzel"

    var id: String { rawValue }
}

enum CalendarRecurrence: String, CaseIterable, Identifiable, Codable {
    case none
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Keine"
        case .daily: return "Täglich"
        case .weekly: return "Wöchentlich"
        case .monthly: return "Monatlich"
        }
    }
}

enum CalendarEventKind: String, CaseIterable, Identifiable, Codable {
    case generic
    case training
    case match

    var id: String { rawValue }
}

struct CalendarCategory: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var colorHex: String
    var isSystem: Bool

    var color: Color {
        Color(hex: colorHex)
    }

    static let training = CalendarCategory(
        id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA") ?? UUID(),
        name: "Training",
        colorHex: "#10b981",
        isSystem: true
    )

    static let match = CalendarCategory(
        id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB") ?? UUID(),
        name: "Spiel",
        colorHex: "#2563eb",
        isSystem: true
    )
}

struct CalendarEvent: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var categoryID: UUID
    var visibility: CalendarVisibility
    var audience: CalendarAudience
    var audiencePlayerIDs: [UUID]
    var recurrence: CalendarRecurrence
    var location: String
    var notes: String
    var linkedTrainingPlanID: UUID? = nil
    var eventKind: CalendarEventKind = .generic
    var playerVisibleGoal: String? = nil
    var playerVisibleDurationMinutes: Int? = nil
}

struct CalendarEventDraft {
    var title: String = ""
    var startDate: Date = Date()
    var endDate: Date = Calendar.current.date(byAdding: .minute, value: 90, to: Date()) ?? Date()
    var categoryID: UUID = CalendarCategory.training.id
    var visibility: CalendarVisibility = .team
    var audience: CalendarAudience = .team
    var audiencePlayerIDs: [UUID] = []
    var recurrence: CalendarRecurrence = .none
    var location: String = ""
    var notes: String = ""
}

struct CalendarSlot: Equatable {
    let date: Date
    let hour: Int?
}

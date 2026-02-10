import Foundation

enum TrainingStoreError: LocalizedError {
    case backendUnavailable
    case planNotFound
    case phaseNotFound
    case exerciseNotFound
    case groupNotFound
    case briefingNotFound
    case reportNotFound
    case invalidTitle
    case invalidDuration
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .backendUnavailable:
            return "Trainingsplanung benötigt eine aktive Backend-Verbindung."
        case .planNotFound:
            return "Training nicht gefunden."
        case .phaseNotFound:
            return "Trainingsphase nicht gefunden."
        case .exerciseNotFound:
            return "Übung nicht gefunden."
        case .groupNotFound:
            return "Trainingsgruppe nicht gefunden."
        case .briefingNotFound:
            return "Gruppen-Briefing nicht gefunden."
        case .reportNotFound:
            return "Trainingsbericht nicht gefunden."
        case .invalidTitle:
            return "Bitte einen gültigen Namen eingeben."
        case .invalidDuration:
            return "Dauer muss größer als 0 sein."
        case .invalidDate:
            return "Ungültiges Datum."
        }
    }
}

enum TrainingPlanStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case scheduled
    case live
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft:
            return "Entwurf"
        case .scheduled:
            return "Geplant"
        case .live:
            return "Live"
        case .completed:
            return "Abgeschlossen"
        }
    }
}

enum TrainingPhaseType: String, Codable, CaseIterable, Identifiable {
    case warmup
    case activation
    case main
    case cooldown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warmup:
            return "Aufwärmen"
        case .activation:
            return "Aktivierung"
        case .main:
            return "Hauptteil"
        case .cooldown:
            return "Abschlussspiel / Cooldown"
        }
    }
}

enum TrainingIntensity: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low:
            return "Locker"
        case .medium:
            return "Mittel"
        case .high:
            return "Hoch"
        }
    }

    var loadFactor: Int {
        switch self {
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        }
    }
}

enum TrainingMaterialKind: String, Codable, CaseIterable, Identifiable {
    case baelle
    case huetchen
    case tore
    case leibchen
    case stangen
    case huerden
    case sonstiges

    var id: String { rawValue }

    var title: String {
        switch self {
        case .baelle:
            return "Bälle"
        case .huetchen:
            return "Hütchen"
        case .tore:
            return "Tore"
        case .leibchen:
            return "Leibchen"
        case .stangen:
            return "Stangen"
        case .huerden:
            return "Hürden"
        case .sonstiges:
            return "Sonstiges"
        }
    }
}

enum TrainingLiveDeviationKind: String, Codable, CaseIterable, Identifiable {
    case timeAdjusted
    case skipped
    case extended
    case reordered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeAdjusted:
            return "Zeit angepasst"
        case .skipped:
            return "Übersprungen"
        case .extended:
            return "Verlängert"
        case .reordered:
            return "Reihenfolge geändert"
        }
    }
}

enum TrainingPlayersViewLevel: String, Codable, CaseIterable, Identifiable {
    case basic
    case basicPlusGoalDuration

    var id: String { rawValue }
}

struct TrainingMaterialQuantity: Codable, Hashable, Identifiable {
    let id: UUID
    var kind: TrainingMaterialKind
    var label: String
    var quantity: Int

    init(
        id: UUID = UUID(),
        kind: TrainingMaterialKind,
        label: String = "",
        quantity: Int
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.quantity = max(0, quantity)
    }

    var displayName: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.title : trimmed
    }
}

struct TrainingPlan: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var title: String
    var date: Date
    var location: String
    var mainGoal: String
    var secondaryGoals: [String]
    var status: TrainingPlanStatus
    var linkedMatchID: UUID?
    var calendarEventID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var syncState: AnalysisSyncState

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        title: String,
        date: Date,
        location: String = "",
        mainGoal: String = "",
        secondaryGoals: [String] = [],
        status: TrainingPlanStatus = .draft,
        linkedMatchID: UUID? = nil,
        calendarEventID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncState: AnalysisSyncState = .pending
    ) {
        self.id = id
        self.backendID = backendID
        self.title = title
        self.date = date
        self.location = location
        self.mainGoal = mainGoal
        self.secondaryGoals = secondaryGoals
        self.status = status
        self.linkedMatchID = linkedMatchID
        self.calendarEventID = calendarEventID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }
}

struct TrainingPhase: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var planID: UUID
    var orderIndex: Int
    var type: TrainingPhaseType
    var title: String
    var durationMinutes: Int
    var goal: String
    var intensity: TrainingIntensity
    var description: String
    var isCompletedLive: Bool

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        planID: UUID,
        orderIndex: Int,
        type: TrainingPhaseType,
        title: String,
        durationMinutes: Int,
        goal: String = "",
        intensity: TrainingIntensity,
        description: String = "",
        isCompletedLive: Bool = false
    ) {
        self.id = id
        self.backendID = backendID
        self.planID = planID
        self.orderIndex = max(0, orderIndex)
        self.type = type
        self.title = title
        self.durationMinutes = max(1, durationMinutes)
        self.goal = goal
        self.intensity = intensity
        self.description = description
        self.isCompletedLive = isCompletedLive
    }
}

struct TrainingExercise: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var phaseID: UUID
    var orderIndex: Int
    var name: String
    var description: String
    var durationMinutes: Int
    var intensity: TrainingIntensity
    var requiredPlayers: Int
    var materials: [TrainingMaterialQuantity]
    var excludedPlayerIDs: [UUID]
    var templateSourceID: UUID?
    var isSkippedLive: Bool
    var actualDurationMinutes: Int?

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        phaseID: UUID,
        orderIndex: Int,
        name: String,
        description: String,
        durationMinutes: Int,
        intensity: TrainingIntensity,
        requiredPlayers: Int,
        materials: [TrainingMaterialQuantity] = [],
        excludedPlayerIDs: [UUID] = [],
        templateSourceID: UUID? = nil,
        isSkippedLive: Bool = false,
        actualDurationMinutes: Int? = nil
    ) {
        self.id = id
        self.backendID = backendID
        self.phaseID = phaseID
        self.orderIndex = max(0, orderIndex)
        self.name = name
        self.description = description
        self.durationMinutes = max(1, durationMinutes)
        self.intensity = intensity
        self.requiredPlayers = max(1, requiredPlayers)
        self.materials = materials
        self.excludedPlayerIDs = excludedPlayerIDs
        self.templateSourceID = templateSourceID
        self.isSkippedLive = isSkippedLive
        self.actualDurationMinutes = actualDurationMinutes
    }

    var effectiveDuration: Int {
        if let actualDurationMinutes {
            return max(1, actualDurationMinutes)
        }
        return durationMinutes
    }
}

struct TrainingExerciseTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var name: String
    var baseDescription: String
    var defaultDuration: Int
    var defaultIntensity: TrainingIntensity
    var defaultRequiredPlayers: Int
    var defaultMaterials: [TrainingMaterialQuantity]

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        name: String,
        baseDescription: String,
        defaultDuration: Int,
        defaultIntensity: TrainingIntensity,
        defaultRequiredPlayers: Int,
        defaultMaterials: [TrainingMaterialQuantity] = []
    ) {
        self.id = id
        self.backendID = backendID
        self.name = name
        self.baseDescription = baseDescription
        self.defaultDuration = max(1, defaultDuration)
        self.defaultIntensity = defaultIntensity
        self.defaultRequiredPlayers = max(1, defaultRequiredPlayers)
        self.defaultMaterials = defaultMaterials
    }
}

struct TrainingGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var planID: UUID
    var name: String
    var goal: String
    var playerIDs: [UUID]
    var headCoachUserID: String
    var assistantCoachUserID: String?

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        planID: UUID,
        name: String,
        goal: String,
        playerIDs: [UUID],
        headCoachUserID: String,
        assistantCoachUserID: String? = nil
    ) {
        self.id = id
        self.backendID = backendID
        self.planID = planID
        self.name = name
        self.goal = goal
        self.playerIDs = playerIDs
        self.headCoachUserID = headCoachUserID
        self.assistantCoachUserID = assistantCoachUserID
    }
}

struct TrainingGroupBriefing: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var groupID: UUID
    var goal: String
    var coachingPoints: String
    var focusPoints: String
    var commonMistakes: String
    var targetIntensity: TrainingIntensity

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        groupID: UUID,
        goal: String,
        coachingPoints: String,
        focusPoints: String,
        commonMistakes: String,
        targetIntensity: TrainingIntensity
    ) {
        self.id = id
        self.backendID = backendID
        self.groupID = groupID
        self.goal = goal
        self.coachingPoints = coachingPoints
        self.focusPoints = focusPoints
        self.commonMistakes = commonMistakes
        self.targetIntensity = targetIntensity
    }
}

struct TrainingAvailabilitySnapshot: Identifiable, Codable, Hashable {
    var id: UUID { playerID }
    var playerID: UUID
    var availability: AvailabilityStatus
    var isAbsent: Bool
    var isLimited: Bool
    var note: String

    init(
        playerID: UUID,
        availability: AvailabilityStatus,
        isAbsent: Bool = false,
        isLimited: Bool = false,
        note: String = ""
    ) {
        self.playerID = playerID
        self.availability = availability
        self.isAbsent = isAbsent
        self.isLimited = isLimited
        self.note = note
    }
}

struct TrainingLiveDeviation: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var planID: UUID
    var phaseID: UUID?
    var exerciseID: UUID?
    var kind: TrainingLiveDeviationKind
    var plannedValue: String
    var actualValue: String
    var note: String
    var timestamp: Date

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        planID: UUID,
        phaseID: UUID? = nil,
        exerciseID: UUID? = nil,
        kind: TrainingLiveDeviationKind,
        plannedValue: String,
        actualValue: String,
        note: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.backendID = backendID
        self.planID = planID
        self.phaseID = phaseID
        self.exerciseID = exerciseID
        self.kind = kind
        self.plannedValue = plannedValue
        self.actualValue = actualValue
        self.note = note
        self.timestamp = timestamp
    }
}

struct TrainingAttendanceEntry: Identifiable, Codable, Hashable {
    var id: UUID { playerID }
    var playerID: UUID
    var status: String
    var note: String

    init(playerID: UUID, status: String, note: String = "") {
        self.playerID = playerID
        self.status = status
        self.note = note
    }
}

struct TrainingGroupFeedback: Identifiable, Codable, Hashable {
    let id: UUID
    var groupID: UUID
    var trainerUserID: String
    var feedback: String

    init(id: UUID = UUID(), groupID: UUID, trainerUserID: String, feedback: String) {
        self.id = id
        self.groupID = groupID
        self.trainerUserID = trainerUserID
        self.feedback = feedback
    }
}

struct TrainingPlayerNote: Identifiable, Codable, Hashable {
    var id: UUID { playerID }
    var playerID: UUID
    var note: String

    init(playerID: UUID, note: String) {
        self.playerID = playerID
        self.note = note
    }
}

struct TrainingReport: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var planID: UUID
    var generatedAt: Date
    var plannedTotalMinutes: Int
    var actualTotalMinutes: Int
    var attendance: [TrainingAttendanceEntry]
    var groupFeedback: [TrainingGroupFeedback]
    var playerNotes: [TrainingPlayerNote]
    var summary: String

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        planID: UUID,
        generatedAt: Date = Date(),
        plannedTotalMinutes: Int,
        actualTotalMinutes: Int,
        attendance: [TrainingAttendanceEntry],
        groupFeedback: [TrainingGroupFeedback],
        playerNotes: [TrainingPlayerNote],
        summary: String
    ) {
        self.id = id
        self.backendID = backendID
        self.planID = planID
        self.generatedAt = generatedAt
        self.plannedTotalMinutes = max(0, plannedTotalMinutes)
        self.actualTotalMinutes = max(0, actualTotalMinutes)
        self.attendance = attendance
        self.groupFeedback = groupFeedback
        self.playerNotes = playerNotes
        self.summary = summary
    }
}

struct TrainingCalendarVisibility: Codable, Hashable {
    var playersViewLevel: TrainingPlayersViewLevel

    init(playersViewLevel: TrainingPlayersViewLevel = .basic) {
        self.playersViewLevel = playersViewLevel
    }
}

struct TrainingLoadSummary: Hashable {
    var totalMinutes: Int
    var loadScore: Int
    var highIntensityMinutes: Int
    var warningConsecutiveHighLoad: Bool

    static let zero = TrainingLoadSummary(totalMinutes: 0, loadScore: 0, highIntensityMinutes: 0, warningConsecutiveHighLoad: false)
}

struct TrainingPlanBundle {
    var plan: TrainingPlan
    var phases: [TrainingPhase]
    var exercisesByPhase: [UUID: [TrainingExercise]]
    var groups: [TrainingGroup]
    var briefingsByGroup: [UUID: TrainingGroupBriefing]
    var report: TrainingReport?
}

struct TrainingPlanDraft {
    var title: String
    var date: Date
    var location: String
    var mainGoal: String
    var secondaryGoals: [String]
    var linkedMatchID: UUID?

    init(
        title: String = "Neue Einheit",
        date: Date = Date(),
        location: String = "",
        mainGoal: String = "",
        secondaryGoals: [String] = [],
        linkedMatchID: UUID? = nil
    ) {
        self.title = title
        self.date = date
        self.location = location
        self.mainGoal = mainGoal
        self.secondaryGoals = secondaryGoals
        self.linkedMatchID = linkedMatchID
    }
}

extension TrainingPhase {
    static func defaults(planID: UUID) -> [TrainingPhase] {
        [
            TrainingPhase(planID: planID, orderIndex: 0, type: .warmup, title: TrainingPhaseType.warmup.title, durationMinutes: 15, goal: "Aktivieren", intensity: .low),
            TrainingPhase(planID: planID, orderIndex: 1, type: .activation, title: TrainingPhaseType.activation.title, durationMinutes: 15, goal: "Dynamik", intensity: .medium),
            TrainingPhase(planID: planID, orderIndex: 2, type: .main, title: TrainingPhaseType.main.title, durationMinutes: 45, goal: "Spielprinzip", intensity: .high),
            TrainingPhase(planID: planID, orderIndex: 3, type: .cooldown, title: TrainingPhaseType.cooldown.title, durationMinutes: 15, goal: "Regeneration", intensity: .low)
        ]
    }
}

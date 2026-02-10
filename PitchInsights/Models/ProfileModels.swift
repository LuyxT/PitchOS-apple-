import Foundation

enum ProfileRoleType: String, CaseIterable, Identifiable, Codable, Hashable {
    case player
    case headCoach
    case assistantCoach
    case coachingStaff
    case athleticCoach
    case physiotherapist
    case teamManager
    case boardMember
    case facilityManager
    case analyst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .player:
            return "Spieler"
        case .headCoach:
            return "Chef-Trainer"
        case .assistantCoach:
            return "Co-Trainer"
        case .coachingStaff:
            return "Trainerteam"
        case .athleticCoach:
            return "Athletiktrainer"
        case .physiotherapist:
            return "Physiotherapeut"
        case .teamManager:
            return "Teammanager"
        case .boardMember:
            return "Vorstand"
        case .facilityManager:
            return "Platzwart"
        case .analyst:
            return "Analyst"
        }
    }

    var iconName: String {
        switch self {
        case .player:
            return "figure.soccer"
        case .headCoach:
            return "person.crop.square.badge.checkmark"
        case .assistantCoach:
            return "person.2.badge.gearshape"
        case .coachingStaff:
            return "person.3.sequence"
        case .athleticCoach:
            return "figure.run"
        case .physiotherapist:
            return "cross.case"
        case .teamManager:
            return "clipboard"
        case .boardMember:
            return "building.columns"
        case .facilityManager:
            return "wrench.and.screwdriver"
        case .analyst:
            return "chart.line.uptrend.xyaxis"
        }
    }

    var isTrainerFamily: Bool {
        switch self {
        case .headCoach, .assistantCoach, .coachingStaff, .athleticCoach, .analyst:
            return true
        case .player, .physiotherapist, .teamManager, .boardMember, .facilityManager:
            return false
        }
    }

    var canViewMedicalInternalsByDefault: Bool {
        switch self {
        case .headCoach, .assistantCoach, .athleticCoach, .physiotherapist:
            return true
        case .player, .coachingStaff, .teamManager, .boardMember, .facilityManager, .analyst:
            return false
        }
    }
}

enum ProfilePlayerLoadCapacity: String, CaseIterable, Identifiable, Codable, Hashable {
    case free
    case limited
    case individual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free:
            return "Frei"
        case .limited:
            return "Eingeschränkt"
        case .individual:
            return "Individuell"
        }
    }
}

struct ProfileCoreData: Codable, Hashable {
    var avatarPath: String?
    var firstName: String
    var lastName: String
    var dateOfBirth: Date?
    var email: String
    var phone: String?
    var clubName: String
    var roles: [ProfileRoleType]
    var isActive: Bool
    var internalNotes: String

    var displayName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var age: Int? {
        guard let dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
    }
}

struct PlayerRoleProfileData: Codable, Hashable {
    var primaryPosition: PlayerPosition
    var secondaryPositions: [PlayerPosition]
    var jerseyNumber: Int?
    var heightCm: Int?
    var weightKg: Int?
    var preferredFoot: PreferredFoot?
    var preferredSystemRole: String
    var seasonGoals: String
    var longTermGoals: String
    var pathway: String
    var loadCapacity: ProfilePlayerLoadCapacity
    var injuryHistory: String
    var availability: AvailabilityStatus
}

struct HeadCoachProfileData: Codable, Hashable {
    var licenses: [String]
    var education: [String]
    var careerPath: [String]
    var preferredSystems: [String]
    var matchPhilosophy: String
    var trainingPhilosophy: String
    var personalGoals: String
    var responsibilities: [String]
    var isPrimaryContact: Bool
}

struct AssistantCoachProfileData: Codable, Hashable {
    var licenses: [String]
    var focusAreas: [String]
    var operationalFocus: String
    var groupResponsibilities: [String]
    var trainingInvolvement: String
}

struct AthleticCoachProfileData: Codable, Hashable {
    var certifications: [String]
    var focusAreas: [String]
    var ageGroupExperience: [String]
    var planningInvolvement: String
    var groupResponsibilities: [String]
}

struct MedicalProfileData: Codable, Hashable {
    var education: [String]
    var additionalQualifications: [String]
    var specialties: [String]
    var assignedTeams: [String]
    var organizationalAvailability: String
    var protectedInternalNotes: String
}

struct TeamManagerProfileData: Codable, Hashable {
    var clubFunction: String
    var responsibilities: [String]
    var operationalTasks: [String]
    var communicationOwnership: String
    var internalAvailability: String
}

struct BoardProfileData: Codable, Hashable {
    var boardFunction: String
    var termStart: Date?
    var termEnd: Date?
    var responsibilityAreas: [String]
    var contactOptions: [String]
}

struct FacilityProfileData: Codable, Hashable {
    var responsibilities: [String]
    var facilities: [String]
    var availability: String
}

struct PersonProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var linkedPlayerID: UUID?
    var linkedAdminPersonID: UUID?
    var core: ProfileCoreData

    var player: PlayerRoleProfileData?
    var headCoach: HeadCoachProfileData?
    var assistantCoach: AssistantCoachProfileData?
    var athleticCoach: AthleticCoachProfileData?
    var medical: MedicalProfileData?
    var teamManager: TeamManagerProfileData?
    var board: BoardProfileData?
    var facility: FacilityProfileData?

    var lockedFieldKeys: Set<String>
    var updatedAt: Date
    var updatedBy: String

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        linkedPlayerID: UUID? = nil,
        linkedAdminPersonID: UUID? = nil,
        core: ProfileCoreData,
        player: PlayerRoleProfileData? = nil,
        headCoach: HeadCoachProfileData? = nil,
        assistantCoach: AssistantCoachProfileData? = nil,
        athleticCoach: AthleticCoachProfileData? = nil,
        medical: MedicalProfileData? = nil,
        teamManager: TeamManagerProfileData? = nil,
        board: BoardProfileData? = nil,
        facility: FacilityProfileData? = nil,
        lockedFieldKeys: Set<String> = [],
        updatedAt: Date = Date(),
        updatedBy: String = "system"
    ) {
        self.id = id
        self.backendID = backendID
        self.linkedPlayerID = linkedPlayerID
        self.linkedAdminPersonID = linkedAdminPersonID
        self.core = core
        self.player = player
        self.headCoach = headCoach
        self.assistantCoach = assistantCoach
        self.athleticCoach = athleticCoach
        self.medical = medical
        self.teamManager = teamManager
        self.board = board
        self.facility = facility
        self.lockedFieldKeys = lockedFieldKeys
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
    }

    var primaryRole: ProfileRoleType {
        core.roles.first ?? .player
    }

    var displayName: String {
        core.displayName.isEmpty ? "Unbekannt" : core.displayName
    }
}

enum ProfileAuditFieldArea: String, CaseIterable, Identifiable, Codable, Hashable {
    case core
    case role
    case permissions
    case medical
    case assignments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .core:
            return "Basisdaten"
        case .role:
            return "Rollenprofil"
        case .permissions:
            return "Rechte"
        case .medical:
            return "Medizinisch"
        case .assignments:
            return "Zuordnung"
        }
    }
}

struct ProfileAuditEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var profileID: UUID
    var actorName: String
    var fieldPath: String
    var area: ProfileAuditFieldArea
    var oldValue: String
    var newValue: String
    var timestamp: Date

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        profileID: UUID,
        actorName: String,
        fieldPath: String,
        area: ProfileAuditFieldArea,
        oldValue: String,
        newValue: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.backendID = backendID
        self.profileID = profileID
        self.actorName = actorName
        self.fieldPath = fieldPath
        self.area = area
        self.oldValue = oldValue
        self.newValue = newValue
        self.timestamp = timestamp
    }
}

struct ProfilePermissionSnapshot: Equatable {
    var canViewMedicalInternals: Bool
    var canViewInternalNotes: Bool
    var canEditCore: Bool
    var canEditRoles: Bool
    var canEditSports: Bool
    var canEditOwnGoalsOnly: Bool
    var canEditMedical: Bool
    var canEditResponsibilities: Bool
    var canDeleteProfile: Bool
}

struct ProfileFilter: Equatable {
    var search: String = ""
    var role: ProfileRoleType? = nil
    var includeInactive: Bool = true
}

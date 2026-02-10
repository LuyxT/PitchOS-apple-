import Foundation

enum AdminRole: String, CaseIterable, Identifiable, Codable {
    case chefTrainer
    case coTrainer
    case analyst
    case teamManager
    case medicalStaff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chefTrainer:
            return "Chef-Trainer"
        case .coTrainer:
            return "Co-Trainer"
        case .analyst:
            return "Analyst"
        case .teamManager:
            return "Team-Manager"
        case .medicalStaff:
            return "Medizinischer Betreuer"
        }
    }
}

enum AdminPermission: String, CaseIterable, Identifiable, Codable, Hashable {
    case trainingCreate
    case trainingEdit
    case trainingDelete
    case squadEdit
    case managePeople
    case manageMessengerRights
    case manageGroups
    case publishTrainingReports
    case manageSeasons
    case manageSettings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trainingCreate:
            return "Training erstellen"
        case .trainingEdit:
            return "Training bearbeiten"
        case .trainingDelete:
            return "Training löschen"
        case .squadEdit:
            return "Kader bearbeiten"
        case .managePeople:
            return "Personen verwalten"
        case .manageMessengerRights:
            return "Messenger-Rechte"
        case .manageGroups:
            return "Teamgruppen verwalten"
        case .publishTrainingReports:
            return "Trainingsberichte freigeben"
        case .manageSeasons:
            return "Saisonverwaltung"
        case .manageSettings:
            return "Einstellungen ändern"
        }
    }
}

enum AdminPersonType: String, CaseIterable, Identifiable, Codable {
    case trainer
    case player

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trainer:
            return "Trainer"
        case .player:
            return "Spieler"
        }
    }
}

enum AdminPresenceStatus: String, CaseIterable, Identifiable, Codable {
    case active
    case away
    case inactive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Aktiv"
        case .away:
            return "Abwesend"
        case .inactive:
            return "Inaktiv"
        }
    }
}

struct AdminPerson: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var fullName: String
    var email: String
    var personType: AdminPersonType
    var role: AdminRole?
    var teamName: String
    var groupIDs: [UUID]
    var permissions: Set<AdminPermission>
    var presenceStatus: AdminPresenceStatus
    var isOnline: Bool
    var linkedPlayerID: UUID?
    var linkedMessengerUserID: String?
    var lastActiveAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        fullName: String,
        email: String,
        personType: AdminPersonType,
        role: AdminRole? = nil,
        teamName: String,
        groupIDs: [UUID] = [],
        permissions: Set<AdminPermission> = [],
        presenceStatus: AdminPresenceStatus = .active,
        isOnline: Bool = false,
        linkedPlayerID: UUID? = nil,
        linkedMessengerUserID: String? = nil,
        lastActiveAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.backendID = backendID
        self.fullName = fullName
        self.email = email
        self.personType = personType
        self.role = role
        self.teamName = teamName
        self.groupIDs = groupIDs
        self.permissions = permissions
        self.presenceStatus = presenceStatus
        self.isOnline = isOnline
        self.linkedPlayerID = linkedPlayerID
        self.linkedMessengerUserID = linkedMessengerUserID
        self.lastActiveAt = lastActiveAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum AdminGroupType: String, CaseIterable, Identifiable, Codable {
    case permanent
    case temporary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .permanent:
            return "Permanent"
        case .temporary:
            return "Temporär"
        }
    }
}

struct AdminGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var name: String
    var goal: String
    var groupType: AdminGroupType
    var memberIDs: [UUID]
    var responsibleCoachID: UUID?
    var assistantCoachID: UUID?
    var startsAt: Date?
    var endsAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        name: String,
        goal: String,
        groupType: AdminGroupType,
        memberIDs: [UUID] = [],
        responsibleCoachID: UUID? = nil,
        assistantCoachID: UUID? = nil,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.backendID = backendID
        self.name = name
        self.goal = goal
        self.groupType = groupType
        self.memberIDs = memberIDs
        self.responsibleCoachID = responsibleCoachID
        self.assistantCoachID = assistantCoachID
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum AdminInvitationMethod: String, CaseIterable, Identifiable, Codable {
    case email
    case link

    var id: String { rawValue }

    var title: String {
        switch self {
        case .email:
            return "E-Mail"
        case .link:
            return "Link"
        }
    }
}

enum AdminInvitationStatus: String, CaseIterable, Identifiable, Codable {
    case open
    case accepted
    case expired
    case revoked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open:
            return "Offen"
        case .accepted:
            return "Angenommen"
        case .expired:
            return "Abgelaufen"
        case .revoked:
            return "Zurückgezogen"
        }
    }
}

struct AdminInvitation: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var recipientName: String
    var email: String
    var method: AdminInvitationMethod
    var role: AdminRole
    var teamName: String
    var status: AdminInvitationStatus
    var inviteLink: String?
    var sentBy: String
    var sentAt: Date
    var expiresAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        recipientName: String,
        email: String,
        method: AdminInvitationMethod,
        role: AdminRole,
        teamName: String,
        status: AdminInvitationStatus = .open,
        inviteLink: String? = nil,
        sentBy: String,
        sentAt: Date = Date(),
        expiresAt: Date,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.backendID = backendID
        self.recipientName = recipientName
        self.email = email
        self.method = method
        self.role = role
        self.teamName = teamName
        self.status = status
        self.inviteLink = inviteLink
        self.sentBy = sentBy
        self.sentAt = sentAt
        self.expiresAt = expiresAt
        self.updatedAt = updatedAt
    }
}

enum AdminAuditArea: String, CaseIterable, Identifiable, Codable {
    case users
    case roles
    case groups
    case invitations
    case seasons
    case settings
    case messengerRules

    var id: String { rawValue }

    var title: String {
        switch self {
        case .users:
            return "Benutzer"
        case .roles:
            return "Rechte"
        case .groups:
            return "Gruppen"
        case .invitations:
            return "Einladungen"
        case .seasons:
            return "Saisons"
        case .settings:
            return "Verein"
        case .messengerRules:
            return "Messenger"
        }
    }
}

struct AdminAuditEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var actorName: String
    var targetName: String
    var area: AdminAuditArea
    var action: String
    var details: String
    var timestamp: Date

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        actorName: String,
        targetName: String,
        area: AdminAuditArea,
        action: String,
        details: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.backendID = backendID
        self.actorName = actorName
        self.targetName = targetName
        self.area = area
        self.action = action
        self.details = details
        self.timestamp = timestamp
    }
}

enum AdminSeasonStatus: String, CaseIterable, Identifiable, Codable {
    case active
    case locked
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Aktiv"
        case .locked:
            return "Gesperrt"
        case .archived:
            return "Archiviert"
        }
    }
}

struct AdminSeason: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var name: String
    var startsAt: Date
    var endsAt: Date
    var status: AdminSeasonStatus
    var teamCount: Int
    var playerCount: Int
    var trainerCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        name: String,
        startsAt: Date,
        endsAt: Date,
        status: AdminSeasonStatus,
        teamCount: Int = 1,
        playerCount: Int = 0,
        trainerCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.backendID = backendID
        self.name = name
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.status = status
        self.teamCount = teamCount
        self.playerCount = playerCount
        self.trainerCount = trainerCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct AdminClubSettings: Codable, Hashable {
    var backendID: String?
    var clubName: String
    var clubLogoPath: String
    var primaryColorHex: String
    var secondaryColorHex: String
    var standardTrainingTypes: [String]
    var defaultVisibility: String
    var teamNameConvention: String
    var globalPermissions: Set<AdminPermission>

    static let `default` = AdminClubSettings(
        backendID: nil,
        clubName: "PitchInsights FC",
        clubLogoPath: "",
        primaryColorHex: "#10b981",
        secondaryColorHex: "#1f2937",
        standardTrainingTypes: ["Technik", "Pressing", "Athletik", "Regeneration"],
        defaultVisibility: "Intern",
        teamNameConvention: "Altersklasse + Mannschaft",
        globalPermissions: [.trainingCreate, .trainingEdit, .squadEdit]
    )
}

struct AdminMessengerRules: Codable, Hashable {
    var backendID: String?
    var allowPrivatePlayerChat: Bool
    var allowDirectTrainerPlayerChat: Bool
    var defaultReadOnlyForPlayers: Bool
    var defaultGroups: [String]
    var allowedChatTypes: [String]
    var groupRuleDescription: String

    static let `default` = AdminMessengerRules(
        backendID: nil,
        allowPrivatePlayerChat: true,
        allowDirectTrainerPlayerChat: true,
        defaultReadOnlyForPlayers: false,
        defaultGroups: ["Teamchat", "Trainingsgruppe"],
        allowedChatTypes: ["Direkt", "Gruppe"],
        groupRuleDescription: "Spieltag-Gruppen werden nach Ende automatisch archiviert."
    )
}

struct AdminDashboardMetrics: Hashable {
    var totalPersons: Int
    var activeTrainers: Int
    var activePlayers: Int
    var openInvitations: Int
    var rightsAlerts: Int
    var activeGroups: Int
}

enum AdminSection: String, CaseIterable, Identifiable {
    case dashboard
    case users
    case roles
    case groups
    case seasons
    case invitations
    case audit
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .users:
            return "Benutzer"
        case .roles:
            return "Rechte"
        case .groups:
            return "Gruppen"
        case .seasons:
            return "Saisons"
        case .invitations:
            return "Einladungen"
        case .audit:
            return "Audit-Log"
        case .settings:
            return "System"
        }
    }
}

struct AdminAuditFilter: Equatable {
    var personName: String = ""
    var area: AdminAuditArea?
    var from: Date?
    var to: Date?
}

enum AdminStoreError: LocalizedError {
    case backendUnavailable
    case invalidInput(String)
    case entityNotFound
    case unauthorized(String)

    var errorDescription: String? {
        switch self {
        case .backendUnavailable:
            return "Backend für Verwaltung nicht verfügbar."
        case .invalidInput(let message):
            return message
        case .entityNotFound:
            return "Eintrag nicht gefunden."
        case .unauthorized(let action):
            return "Keine Berechtigung für \(action)."
        }
    }
}


import Foundation
import SwiftUI

enum CashStoreError: LocalizedError {
    case backendUnavailable
    case transactionNotFound
    case categoryNotFound
    case contributionNotFound
    case goalNotFound
    case missingPermission
    case invalidAmount
    case invalidTitle

    var errorDescription: String? {
        switch self {
        case .backendUnavailable:
            return "Mannschaftskasse benötigt eine aktive Backend-Verbindung."
        case .transactionNotFound:
            return "Transaktion nicht gefunden."
        case .categoryNotFound:
            return "Kategorie nicht gefunden."
        case .contributionNotFound:
            return "Beitrag nicht gefunden."
        case .goalNotFound:
            return "Kassenziel nicht gefunden."
        case .missingPermission:
            return "Keine Berechtigung für diese Aktion."
        case .invalidAmount:
            return "Ungültiger Betrag."
        case .invalidTitle:
            return "Bitte einen gültigen Titel eingeben."
        }
    }
}

enum CashTransactionKind: String, Codable, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income:
            return "Einnahme"
        case .expense:
            return "Ausgabe"
        }
    }
}

enum CashPaymentStatus: String, Codable, CaseIterable, Identifiable {
    case paid
    case open
    case overdue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paid:
            return "Bezahlt"
        case .open:
            return "Offen"
        case .overdue:
            return "Überfällig"
        }
    }
}

enum CashUserRole: String, Codable, CaseIterable, Identifiable {
    case admin
    case trainer
    case cashier
    case player

    var id: String { rawValue }

    var title: String {
        switch self {
        case .admin:
            return "Admin"
        case .trainer:
            return "Trainer"
        case .cashier:
            return "Kassierer"
        case .player:
            return "Spieler"
        }
    }
}

enum CashPermission: String, Codable, CaseIterable, Identifiable, Hashable {
    case createTransaction
    case editTransaction
    case deleteTransaction
    case manageGoals
    case manageContributions
    case sendPaymentReminder
    case viewClubBalance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .createTransaction:
            return "Transaktionen anlegen"
        case .editTransaction:
            return "Transaktionen bearbeiten"
        case .deleteTransaction:
            return "Transaktionen löschen"
        case .manageGoals:
            return "Kassenziele verwalten"
        case .manageContributions:
            return "Monatsbeiträge verwalten"
        case .sendPaymentReminder:
            return "Zahlungserinnerung senden"
        case .viewClubBalance:
            return "Gesamtstand sehen"
        }
    }
}

struct CashAccessContext: Equatable {
    var role: CashUserRole
    var permissions: Set<CashPermission>
    var currentPlayerID: UUID?

    var canManageTransactions: Bool {
        permissions.contains(.createTransaction) || permissions.contains(.editTransaction)
    }

    var canDeleteTransactions: Bool {
        permissions.contains(.deleteTransaction)
    }

    var canViewBalance: Bool {
        permissions.contains(.viewClubBalance)
    }
}

struct CashCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var name: String
    var colorHex: String
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        name: String,
        colorHex: String,
        isDefault: Bool = false
    ) {
        self.id = id
        self.backendID = backendID
        self.name = name
        self.colorHex = colorHex
        self.isDefault = isDefault
    }

    static let defaultCategories: [CashCategory] = [
        CashCategory(name: "Material", colorHex: "#10b981", isDefault: true),
        CashCategory(name: "Beiträge", colorHex: "#059669", isDefault: true),
        CashCategory(name: "Platzmiete", colorHex: "#1d4ed8", isDefault: true),
        CashCategory(name: "Getränke", colorHex: "#f59e0b", isDefault: true),
        CashCategory(name: "Events", colorHex: "#7c3aed", isDefault: true),
        CashCategory(name: "Sponsoren", colorHex: "#be185d", isDefault: true),
        CashCategory(name: "Fahrtkosten", colorHex: "#dc2626", isDefault: true),
        CashCategory(name: "Schiedsrichter", colorHex: "#334155", isDefault: true)
    ]
}

struct CashTransaction: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var amount: Double
    var date: Date
    var categoryID: UUID
    var description: String
    var type: CashTransactionKind
    var playerID: UUID?
    var responsibleTrainerID: String?
    var comment: String
    var paymentStatus: CashPaymentStatus
    var contextLabel: String?
    var createdAt: Date
    var updatedAt: Date
    var syncState: AnalysisSyncState

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        amount: Double,
        date: Date,
        categoryID: UUID,
        description: String,
        type: CashTransactionKind,
        playerID: UUID? = nil,
        responsibleTrainerID: String? = nil,
        comment: String = "",
        paymentStatus: CashPaymentStatus = .paid,
        contextLabel: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncState: AnalysisSyncState = .pending
    ) {
        self.id = id
        self.backendID = backendID
        self.amount = amount
        self.date = date
        self.categoryID = categoryID
        self.description = description
        self.type = type
        self.playerID = playerID
        self.responsibleTrainerID = responsibleTrainerID
        self.comment = comment
        self.paymentStatus = paymentStatus
        self.contextLabel = contextLabel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }
}

struct MonthlyContribution: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var playerID: UUID
    var amount: Double
    var dueDate: Date
    var status: CashPaymentStatus
    var monthKey: String
    var lastReminderAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        playerID: UUID,
        amount: Double,
        dueDate: Date,
        status: CashPaymentStatus,
        monthKey: String,
        lastReminderAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.backendID = backendID
        self.playerID = playerID
        self.amount = amount
        self.dueDate = dueDate
        self.status = status
        self.monthKey = monthKey
        self.lastReminderAt = lastReminderAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct CashGoal: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var name: String
    var targetAmount: Double
    var currentProgress: Double
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        name: String,
        targetAmount: Double,
        currentProgress: Double = 0,
        startDate: Date,
        endDate: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.backendID = backendID
        self.name = name
        self.targetAmount = targetAmount
        self.currentProgress = currentProgress
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var progressRatio: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentProgress / targetAmount, 0), 1)
    }
}

struct CashFilterState: Equatable {
    var query: String = ""
    var range: DateInterval?
    var categoryIDs: Set<UUID> = []
    var playerID: UUID?
    var responsibleTrainerID: String?
    var statuses: Set<CashPaymentStatus> = []
    var transactionType: CashTransactionKind?
}

struct CashSummary {
    var openingBalance: Double
    var currentBalance: Double
    var totalIncome: Double
    var totalExpense: Double
    var projectedBalance: Double
    var openAmount: Double
    var overdueAmount: Double
}

struct CashCategoryBreakdown: Identifiable {
    let id: UUID
    let categoryID: UUID
    let categoryName: String
    let colorHex: String
    let amount: Double
    let ratio: Double

    init(categoryID: UUID, categoryName: String, colorHex: String, amount: Double, ratio: Double) {
        self.id = categoryID
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.colorHex = colorHex
        self.amount = amount
        self.ratio = ratio
    }
}

enum CashTimelineGranularity: String, CaseIterable, Identifiable {
    case daily = "Tag"
    case weekly = "Woche"
    case monthly = "Monat"
    case yearly = "Jahr"

    var id: String { rawValue }
}

struct CashTimelinePoint: Identifiable {
    let id = UUID()
    let label: String
    let income: Double
    let expense: Double
    let balance: Double
}

struct CashTransactionDraft: Equatable {
    var amount: Double
    var date: Date
    var categoryID: UUID
    var description: String
    var type: CashTransactionKind
    var playerID: UUID?
    var responsibleTrainerID: String?
    var comment: String
    var paymentStatus: CashPaymentStatus
    var contextLabel: String?
}

struct CashGoalDraft: Equatable {
    var name: String
    var targetAmount: Double
    var currentProgress: Double
    var startDate: Date
    var endDate: Date
}

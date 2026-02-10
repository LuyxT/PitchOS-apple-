import Foundation
import SwiftUI
import Combine

@MainActor
final class CashWorkspaceViewModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case transactions = "Transaktionen"
        case payments = "Spielerzahlungen"
        case goals = "Kassenziele"

        var id: String { rawValue }
    }

    @Published var selectedSection: Section = .dashboard
    @Published var filter = CashFilterState()
    @Published var isLoading = false
    @Published var statusMessage: String?

    @Published var isTransactionEditorPresented = false
    @Published var editingTransactionID: UUID?
    @Published var transactionDraft = CashTransactionDraft(
        amount: 0,
        date: Date(),
        categoryID: UUID(),
        description: "",
        type: .income,
        playerID: nil,
        responsibleTrainerID: nil,
        comment: "",
        paymentStatus: .paid,
        contextLabel: nil
    )

    @Published var isGoalEditorPresented = false
    @Published var editingGoalID: UUID?
    @Published var goalDraft = CashGoalDraft(
        name: "",
        targetAmount: 0,
        currentProgress: 0,
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    )

    @Published var transactionPage = 1
    let pageSize = 60

    func bootstrap(store: AppDataStore) async {
        isLoading = true
        defer { isLoading = false }
        await store.bootstrapCashModule()
        normalizeFilterCategory(store: store)
        if store.cashAccessContext.role == .player {
            selectedSection = .payments
        }
        statusMessage = store.cashLastErrorMessage
    }

    func visibleSections(for access: CashAccessContext) -> [Section] {
        if access.role == .player {
            return [.payments]
        }
        return Section.allCases
    }

    func applySearch(_ text: String) {
        filter.query = text
        resetPaging()
    }

    func resetFilters() {
        filter = CashFilterState()
        resetPaging()
    }

    func pagedTransactions(store: AppDataStore) -> [CashTransaction] {
        let filtered = store.filteredCashTransactions(filter)
        let upperBound = min(filtered.count, transactionPage * pageSize)
        return Array(filtered.prefix(upperBound))
    }

    func canLoadMoreTransactions(store: AppDataStore) -> Bool {
        let filteredCount = store.filteredCashTransactions(filter).count
        return transactionPage * pageSize < filteredCount
    }

    func loadMoreTransactions() {
        transactionPage += 1
    }

    func presentCreateTransaction(store: AppDataStore) {
        editingTransactionID = nil
        let responsibleID: String? = {
            guard let trainer = store.adminPersons.first(where: { $0.personType == .trainer }) else { return nil }
            return trainer.backendID ?? trainer.id.uuidString
        }()
        let draft = CashTransactionDraft(
            amount: 0.0,
            date: Date(),
            categoryID: store.cashCategories.first?.id ?? UUID(),
            description: "",
            type: .income,
            playerID: nil,
            responsibleTrainerID: responsibleID,
            comment: "",
            paymentStatus: .paid,
            contextLabel: nil
        )
        transactionDraft = draft
        isTransactionEditorPresented = true
    }

    func presentEditTransaction(_ transaction: CashTransaction) {
        editingTransactionID = transaction.id
        transactionDraft = CashTransactionDraft(
            amount: transaction.amount,
            date: transaction.date,
            categoryID: transaction.categoryID,
            description: transaction.description,
            type: transaction.type,
            playerID: transaction.playerID,
            responsibleTrainerID: transaction.responsibleTrainerID,
            comment: transaction.comment,
            paymentStatus: transaction.paymentStatus,
            contextLabel: transaction.contextLabel
        )
        isTransactionEditorPresented = true
    }

    func saveTransaction(store: AppDataStore) async {
        do {
            _ = try await store.upsertCashTransaction(draft: transactionDraft, editingID: editingTransactionID)
            isTransactionEditorPresented = false
            statusMessage = editingTransactionID == nil ? "Transaktion erstellt" : "Transaktion gespeichert"
            editingTransactionID = nil
            resetPaging()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteTransaction(_ transactionID: UUID, store: AppDataStore) async {
        do {
            try await store.deleteCashTransaction(id: transactionID)
            statusMessage = "Transaktion gelöscht"
            resetPaging()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func duplicateTransaction(_ transactionID: UUID, store: AppDataStore) async {
        do {
            _ = try await store.duplicateCashTransaction(id: transactionID)
            statusMessage = "Transaktion dupliziert"
            resetPaging()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func presentCreateGoal() {
        editingGoalID = nil
        goalDraft = CashGoalDraft(
            name: "",
            targetAmount: 0,
            currentProgress: 0,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        )
        isGoalEditorPresented = true
    }

    func presentEditGoal(_ goal: CashGoal) {
        editingGoalID = goal.id
        goalDraft = CashGoalDraft(
            name: goal.name,
            targetAmount: goal.targetAmount,
            currentProgress: goal.currentProgress,
            startDate: goal.startDate,
            endDate: goal.endDate
        )
        isGoalEditorPresented = true
    }

    func saveGoal(store: AppDataStore) async {
        do {
            _ = try await store.upsertCashGoal(draft: goalDraft, editingID: editingGoalID)
            isGoalEditorPresented = false
            statusMessage = editingGoalID == nil ? "Kassenziel erstellt" : "Kassenziel gespeichert"
            editingGoalID = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteGoal(_ goalID: UUID, store: AppDataStore) async {
        do {
            try await store.deleteCashGoal(id: goalID)
            statusMessage = "Kassenziel gelöscht"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func normalizeFilterCategory(store: AppDataStore) {
        if filter.categoryIDs.isEmpty { return }
        let categoryIDs = Set(store.cashCategories.map(\.id))
        filter.categoryIDs = filter.categoryIDs.filter { categoryIDs.contains($0) }
    }

    private func resetPaging() {
        transactionPage = 1
    }
}

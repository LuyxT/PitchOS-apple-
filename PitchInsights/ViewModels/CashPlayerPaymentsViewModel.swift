import Foundation
import SwiftUI
import Combine

@MainActor
final class CashPlayerPaymentsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var statusFilter: CashPaymentStatus?
    @Published var selectedContributionIDs: Set<UUID> = []
    @Published var statusMessage: String?

    func filteredContributions(store: AppDataStore) -> [MonthlyContribution] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.cashVisibleContributions()
            .filter { item in
                if let statusFilter, item.status != statusFilter {
                    return false
                }
                if query.isEmpty {
                    return true
                }
                let playerName = store.players.first(where: { $0.id == item.playerID })?.name.lowercased() ?? ""
                return playerName.contains(query) || item.monthKey.lowercased().contains(query)
            }
    }

    func toggleSelection(_ id: UUID) {
        if selectedContributionIDs.contains(id) {
            selectedContributionIDs.remove(id)
        } else {
            selectedContributionIDs.insert(id)
        }
    }

    func clearSelection() {
        selectedContributionIDs.removeAll()
    }

    func markSelected(
        status: CashPaymentStatus,
        store: AppDataStore
    ) async {
        let selected = selectedContributionIDs
        guard !selected.isEmpty else { return }
        do {
            for id in selected {
                try await store.updateCashContributionStatus(contributionID: id, status: status)
            }
            statusMessage = "Zahlungsstatus aktualisiert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func sendReminders(store: AppDataStore) async {
        let selected = selectedContributionIDs
        guard !selected.isEmpty else { return }
        do {
            try await store.sendCashPaymentReminder(contributionIDs: Array(selected))
            statusMessage = "Erinnerung gesendet"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func generateCurrentMonthContributions(store: AppDataStore, amount: Double) async {
        do {
            try await store.generateRecurringMonthlyContributions(monthDate: Date(), defaultAmount: amount)
            statusMessage = "Monatsbeiträge erzeugt"
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

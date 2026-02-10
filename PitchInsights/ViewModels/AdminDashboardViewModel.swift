import Foundation
import Combine

@MainActor
final class AdminDashboardViewModel: ObservableObject {
    @Published var metrics = AdminDashboardMetrics(
        totalPersons: 0,
        activeTrainers: 0,
        activePlayers: 0,
        openInvitations: 0,
        rightsAlerts: 0,
        activeGroups: 0
    )
    @Published var rightsAlerts: [AdminPerson] = []
    @Published var openInvitations: [AdminInvitation] = []

    func refresh(store: AppDataStore) {
        metrics = store.adminDashboardMetrics()
        rightsAlerts = store.adminPersons
            .filter { $0.personType == .trainer && $0.permissions.isEmpty }
            .sorted { $0.fullName < $1.fullName }
        openInvitations = store.adminInvitations
            .filter { $0.status == .open }
            .sorted { $0.sentAt > $1.sentAt }
    }
}

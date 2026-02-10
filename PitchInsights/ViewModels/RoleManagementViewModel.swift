import Foundation
import Combine

@MainActor
final class RoleManagementViewModel: ObservableObject {
    @Published var selectedPersonID: UUID?
    @Published var isSaving = false
    @Published var statusMessage: String?

    func trainerPersons(from persons: [AdminPerson]) -> [AdminPerson] {
        persons
            .filter { $0.personType == .trainer }
            .sorted { $0.fullName < $1.fullName }
    }

    func ensureSelection(in persons: [AdminPerson]) {
        if let selectedPersonID, persons.contains(where: { $0.id == selectedPersonID }) {
            return
        }
        selectedPersonID = persons.first?.id
    }

    func setRole(_ role: AdminRole, for person: AdminPerson, store: AppDataStore) async {
        var updated = person
        updated.role = role
        await persist(updated, store: store)
    }

    func togglePermission(_ permission: AdminPermission, for person: AdminPerson, store: AppDataStore) async {
        var updated = person
        if updated.permissions.contains(permission) {
            updated.permissions.remove(permission)
        } else {
            updated.permissions.insert(permission)
        }
        await persist(updated, store: store)
    }

    private func persist(_ person: AdminPerson, store: AppDataStore) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await store.upsertAdminPerson(person)
            selectedPersonID = saved.id
            statusMessage = "Rechte gespeichert."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

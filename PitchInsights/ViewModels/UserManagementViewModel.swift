import Foundation
import Combine

struct AdminPersonDraft {
    var localID: UUID?
    var backendID: String?
    var fullName: String = ""
    var email: String = ""
    var personType: AdminPersonType = .trainer
    var role: AdminRole? = .coTrainer
    var teamName: String = "1. Mannschaft"
    var groupIDs: Set<UUID> = []
    var permissions: Set<AdminPermission> = [.trainingCreate, .trainingEdit]
    var presenceStatus: AdminPresenceStatus = .active
    var linkedPlayerID: UUID?

    init() {}

    init(from person: AdminPerson) {
        localID = person.id
        backendID = person.backendID
        fullName = person.fullName
        email = person.email
        personType = person.personType
        role = person.role
        teamName = person.teamName
        groupIDs = Set(person.groupIDs)
        permissions = person.permissions
        presenceStatus = person.presenceStatus
        linkedPlayerID = person.linkedPlayerID
    }

    func materialize(existing: AdminPerson?) -> AdminPerson {
        AdminPerson(
            id: existing?.id ?? localID ?? UUID(),
            backendID: existing?.backendID ?? backendID,
            fullName: fullName,
            email: email,
            personType: personType,
            role: personType == .trainer ? (role ?? .coTrainer) : nil,
            teamName: teamName,
            groupIDs: Array(groupIDs),
            permissions: personType == .trainer ? permissions : [],
            presenceStatus: presenceStatus,
            isOnline: existing?.isOnline ?? false,
            linkedPlayerID: personType == .player ? (existing?.linkedPlayerID ?? linkedPlayerID) : nil,
            linkedMessengerUserID: existing?.linkedMessengerUserID,
            lastActiveAt: existing?.lastActiveAt,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
}

@MainActor
final class UserManagementViewModel: ObservableObject {
    @Published var selectedPersonID: UUID?
    @Published var searchText = ""
    @Published var draft = AdminPersonDraft()
    @Published var isEditorPresented = false
    @Published var isSaving = false
    @Published var statusMessage: String?

    func filteredPersons(from source: [AdminPerson]) -> [AdminPerson] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return source.sorted { $0.fullName < $1.fullName }
        }
        return source
            .filter {
                $0.fullName.lowercased().contains(query) ||
                    $0.email.lowercased().contains(query) ||
                    $0.teamName.lowercased().contains(query)
            }
            .sorted { $0.fullName < $1.fullName }
    }

    func ensureSelection(in persons: [AdminPerson]) {
        if let selectedPersonID, persons.contains(where: { $0.id == selectedPersonID }) {
            return
        }
        selectedPersonID = persons.first?.id
    }

    func beginCreate(defaultTeam: String) {
        draft = AdminPersonDraft()
        draft.teamName = defaultTeam
        isEditorPresented = true
    }

    func beginEdit(_ person: AdminPerson) {
        draft = AdminPersonDraft(from: person)
        isEditorPresented = true
    }

    func togglePermission(_ permission: AdminPermission) {
        if draft.permissions.contains(permission) {
            draft.permissions.remove(permission)
        } else {
            draft.permissions.insert(permission)
        }
    }

    func toggleGroup(_ groupID: UUID) {
        if draft.groupIDs.contains(groupID) {
            draft.groupIDs.remove(groupID)
        } else {
            draft.groupIDs.insert(groupID)
        }
    }

    func save(store: AppDataStore) async {
        isSaving = true
        defer { isSaving = false }
        let existing = store.adminPersons.first(where: { $0.id == draft.localID })
        let person = draft.materialize(existing: existing)
        do {
            let saved = try await store.upsertAdminPerson(person)
            selectedPersonID = saved.id
            isEditorPresented = false
            statusMessage = "Person gespeichert."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteSelected(store: AppDataStore) async {
        guard let selectedPersonID else { return }
        do {
            try await store.deleteAdminPerson(selectedPersonID)
            self.selectedPersonID = store.adminPersons.first?.id
            statusMessage = "Person gelöscht."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

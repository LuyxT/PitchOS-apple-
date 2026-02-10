import Foundation
import Combine

struct AdminGroupDraft {
    var localID: UUID?
    var backendID: String?
    var name: String = ""
    var goal: String = ""
    var groupType: AdminGroupType = .permanent
    var responsibleCoachID: UUID?
    var assistantCoachID: UUID?
    var memberIDs: Set<UUID> = []
    var startsAt: Date = Date()
    var endsAt: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()

    init() {}

    init(from group: AdminGroup) {
        localID = group.id
        backendID = group.backendID
        name = group.name
        goal = group.goal
        groupType = group.groupType
        responsibleCoachID = group.responsibleCoachID
        assistantCoachID = group.assistantCoachID
        memberIDs = Set(group.memberIDs)
        startsAt = group.startsAt ?? Date()
        endsAt = group.endsAt ?? (Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date())
    }

    func materialize(existing: AdminGroup?) -> AdminGroup {
        AdminGroup(
            id: existing?.id ?? localID ?? UUID(),
            backendID: existing?.backendID ?? backendID,
            name: name,
            goal: goal,
            groupType: groupType,
            memberIDs: Array(memberIDs),
            responsibleCoachID: responsibleCoachID,
            assistantCoachID: assistantCoachID,
            startsAt: groupType == .temporary ? startsAt : nil,
            endsAt: groupType == .temporary ? endsAt : nil,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
}

@MainActor
final class GroupManagementViewModel: ObservableObject {
    @Published var selectedGroupID: UUID?
    @Published var draft = AdminGroupDraft()
    @Published var isEditorPresented = false
    @Published var isSaving = false
    @Published var statusMessage: String?

    func ensureSelection(in groups: [AdminGroup]) {
        if let selectedGroupID, groups.contains(where: { $0.id == selectedGroupID }) {
            return
        }
        selectedGroupID = groups.first?.id
    }

    func beginCreate() {
        draft = AdminGroupDraft()
        isEditorPresented = true
    }

    func beginEdit(_ group: AdminGroup) {
        draft = AdminGroupDraft(from: group)
        isEditorPresented = true
    }

    func toggleMember(_ personID: UUID) {
        if draft.memberIDs.contains(personID) {
            draft.memberIDs.remove(personID)
        } else {
            draft.memberIDs.insert(personID)
        }
    }

    func save(store: AppDataStore) async {
        isSaving = true
        defer { isSaving = false }
        let existing = store.adminGroups.first(where: { $0.id == draft.localID })
        let group = draft.materialize(existing: existing)
        do {
            let saved = try await store.upsertAdminGroup(group)
            selectedGroupID = saved.id
            isEditorPresented = false
            statusMessage = "Gruppe gespeichert."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteSelected(store: AppDataStore) async {
        guard let selectedGroupID else { return }
        do {
            try await store.deleteAdminGroup(selectedGroupID)
            self.selectedGroupID = store.adminGroups.first?.id
            statusMessage = "Gruppe gelöscht."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

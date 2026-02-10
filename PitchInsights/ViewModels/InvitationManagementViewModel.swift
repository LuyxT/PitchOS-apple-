import Foundation
import Combine

struct AdminInvitationDraft {
    var recipientName: String = ""
    var email: String = ""
    var method: AdminInvitationMethod = .email
    var role: AdminRole = .coTrainer
    var teamName: String = "1. Mannschaft"
    var expiresAt: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    func materialize(sentBy: String) -> AdminInvitation {
        AdminInvitation(
            recipientName: recipientName,
            email: email,
            method: method,
            role: role,
            teamName: teamName,
            status: .open,
            inviteLink: method == .link ? "https://invite.pitchinsights.local/\(UUID().uuidString.lowercased())" : nil,
            sentBy: sentBy,
            expiresAt: expiresAt
        )
    }
}

@MainActor
final class InvitationManagementViewModel: ObservableObject {
    @Published var draft = AdminInvitationDraft()
    @Published var showComposer = false
    @Published var statusMessage: String?
    @Published var searchText = ""
    @Published var selectedStatus: AdminInvitationStatus?

    func filteredInvitations(from source: [AdminInvitation]) -> [AdminInvitation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return source
            .filter { invitation in
                if let selectedStatus, invitation.status != selectedStatus {
                    return false
                }
                if query.isEmpty {
                    return true
                }
                return invitation.recipientName.lowercased().contains(query) ||
                    invitation.email.lowercased().contains(query) ||
                    invitation.teamName.lowercased().contains(query)
            }
            .sorted { $0.sentAt > $1.sentAt }
    }

    func sendInvitation(sentBy: String, store: AppDataStore) async {
        let invitation = draft.materialize(sentBy: sentBy)
        do {
            _ = try await store.createAdminInvitation(invitation)
            statusMessage = "Einladung versendet."
            showComposer = false
            draft = AdminInvitationDraft()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func revoke(_ invitation: AdminInvitation, store: AppDataStore) async {
        do {
            try await store.updateAdminInvitationStatus(invitationID: invitation.id, status: .revoked)
            statusMessage = "Einladung zurückgezogen."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func resend(_ invitation: AdminInvitation, store: AppDataStore) async {
        do {
            try await store.resendAdminInvitation(invitationID: invitation.id)
            statusMessage = "Einladung erneut versendet."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

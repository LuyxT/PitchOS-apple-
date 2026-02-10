import Foundation

struct AdminValidationService {
    func validatePerson(_ person: AdminPerson) throws {
        let name = person.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            throw AdminStoreError.invalidInput("Name ist erforderlich.")
        }
        if !person.email.contains("@") {
            throw AdminStoreError.invalidInput("Ungültige E-Mail-Adresse.")
        }
        if person.personType == .trainer && person.role == nil {
            throw AdminStoreError.invalidInput("Trainer benötigen eine Rolle.")
        }
    }

    func validateGroup(_ group: AdminGroup) throws {
        let name = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            throw AdminStoreError.invalidInput("Gruppenname ist erforderlich.")
        }
        if group.groupType == .temporary, let startsAt = group.startsAt, let endsAt = group.endsAt, endsAt < startsAt {
            throw AdminStoreError.invalidInput("Temporäre Gruppe hat ungültigen Zeitraum.")
        }
    }

    func validateInvitation(_ invitation: AdminInvitation) throws {
        if invitation.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AdminStoreError.invalidInput("E-Mail für Einladung fehlt.")
        }
        if !invitation.email.contains("@") {
            throw AdminStoreError.invalidInput("Ungültige E-Mail-Adresse.")
        }
        if invitation.expiresAt <= invitation.sentAt {
            throw AdminStoreError.invalidInput("Einladung muss in der Zukunft ablaufen.")
        }
    }

    func validateSeason(_ season: AdminSeason) throws {
        if season.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AdminStoreError.invalidInput("Saisonname ist erforderlich.")
        }
        if season.endsAt <= season.startsAt {
            throw AdminStoreError.invalidInput("Saisonzeitraum ist ungültig.")
        }
    }
}


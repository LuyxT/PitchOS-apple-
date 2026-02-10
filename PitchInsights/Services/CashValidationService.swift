import Foundation

struct CashValidationService {
    func validateTransactionDraft(_ draft: CashTransactionDraft) -> String? {
        if !draft.amount.isFinite || draft.amount <= 0 {
            return "Betrag muss größer als 0 sein."
        }
        if draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Beschreibung ist erforderlich."
        }
        return nil
    }

    func validateGoalDraft(_ draft: CashGoalDraft) -> String? {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name für Kassenziel fehlt."
        }
        if !draft.targetAmount.isFinite || draft.targetAmount <= 0 {
            return "Zielbetrag muss größer als 0 sein."
        }
        if draft.endDate < draft.startDate {
            return "Enddatum muss nach dem Startdatum liegen."
        }
        return nil
    }
}

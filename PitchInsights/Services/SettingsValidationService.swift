import Foundation

struct SettingsValidationService {
    func validatePasswordChange(
        currentPassword: String,
        newPassword: String,
        confirmPassword: String
    ) -> String? {
        if currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Aktuelles Passwort ist erforderlich."
        }
        if newPassword.count < 8 {
            return "Neues Passwort muss mindestens 8 Zeichen haben."
        }
        if newPassword != confirmPassword {
            return "Passwort-Bestätigung stimmt nicht überein."
        }
        return nil
    }

    func validateFeedbackMessage(_ message: String) -> String? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 8 {
            return "Bitte eine aussagekräftige Nachricht eingeben."
        }
        return nil
    }

    func validateProfileEmail(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "E-Mail ist erforderlich." }
        guard trimmed.contains("@"), trimmed.contains(".") else {
            return "E-Mail hat kein gültiges Format."
        }
        return nil
    }
}

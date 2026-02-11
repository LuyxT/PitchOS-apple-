import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var motion: MotionEngine

    @Binding var email: String
    @Binding var password: String
    @Binding var passwordConfirmation: String
    @Binding var inviteCode: String
    let isBusy: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            OnboardingInputField(title: "E-Mail", text: $email)
            OnboardingInputField(title: "Passwort", text: $password, isSecure: true)
            OnboardingInputField(title: "Passwort bestatigen", text: $passwordConfirmation, isSecure: true)
            OnboardingInputField(title: "Zugangscode (optional)", text: $inviteCode)

            OnboardingProcessingButton(
                title: "Account erstellen",
                busyTitle: "Account wird erstellt...",
                isBusy: isBusy
            ) {
                motion.triggerPulse()
                onSubmit()
            }
            .disabled(isBusy || !isFormValid)
        }
        .frame(maxWidth: 360)
    }

    private var isFormValid: Bool {
        isValidEmail(email) && password.count >= 8 && password == passwordConfirmation
    }

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

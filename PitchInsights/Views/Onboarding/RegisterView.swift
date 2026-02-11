import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var motion: MotionEngine

    @Binding var email: String
    @Binding var password: String
    let isBusy: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            OnboardingInputField(title: "E-Mail", text: $email)
            OnboardingInputField(title: "Passwort", text: $password, isSecure: true)

            OnboardingProcessingButton(
                title: "Account erstellen",
                busyTitle: "Account wird erstellt...",
                isBusy: isBusy
            ) {
                motion.triggerPulse()
                onSubmit()
            }
            .disabled(isBusy || email.isEmpty || password.count < 8)
        }
        .frame(maxWidth: 360)
    }
}

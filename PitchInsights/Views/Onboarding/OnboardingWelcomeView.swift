import SwiftUI

struct OnboardingWelcomeView: View {
    @EnvironmentObject private var motion: MotionEngine

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("Willkommen")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Starte deine Umgebung und richte deinen Verein in wenigen Schritten ein.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Los geht's") {
                motion.feedback(.soft)
                motion.triggerPulse()
                withAnimation(AppMotion.cameraPush) {
                    onContinue()
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
        }
        .frame(maxWidth: 420)
    }
}

import SwiftUI

struct OnboardingCompleteView: View {
    @EnvironmentObject private var motion: MotionEngine

    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.15))
                    .frame(width: 90, height: 90)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.primary)
                ParticleBurstView(trigger: motion.successID, color: AppTheme.primary)
                    .frame(width: 160, height: 160)
            }

            Text("Welcome to the Club")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Dein Workspace wird geoffnet.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)

            Button("Zum Dashboard") {
                motion.feedback(.success)
                motion.triggerSuccess()
                onFinish()
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
        }
    }
}

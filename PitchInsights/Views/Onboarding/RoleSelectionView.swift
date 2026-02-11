import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject private var motion: MotionEngine

    let selectedRole: String
    let onSelect: (String) -> Void
    let onContinue: () -> Void
    let showPlayerWarning: Bool

    var body: some View {
        VStack(spacing: 14) {
            Text("Welche Rolle hast du?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 12) {
                roleCard("Trainer", value: "trainer")
                roleCard("Vorstand", value: "vorstand")
                roleCard("Physio", value: "physio")
                roleCard("Spieler", value: "player")
            }

            if showPlayerWarning {
                Text("Spieler-Onboarding ist bald verfugbar.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                    .motionGlow(true, color: .orange, animation: AppMotion.errorShake)
            }

            Button("Weiter") {
                motion.triggerPulse()
                onContinue()
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
        }
    }

    private func roleCard(_ title: String, value: String) -> some View {
        let isSelected = selectedRole == value
        let isDimmed = !selectedRole.isEmpty && !isSelected
        return Button {
            motion.feedback(.light)
            motion.triggerPulse()
            onSelect(value)
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Capsule()
                    .fill(isSelected ? AppTheme.primary : AppTheme.border)
                    .frame(width: 32, height: 4)
            }
            .frame(width: 120, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AppTheme.primary.opacity(0.12) : AppTheme.surfaceAlt.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppTheme.primary : AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(OnboardingCardButtonStyle())
        .depthStyle(.cardLift, isActive: isSelected, animation: AppMotion.hoverLift)
        .hoverLift()
        .scaleEffect(isSelected ? 1.03 : 1)
        .opacity(isDimmed ? 0.7 : 1)
        .animation(AppMotion.transitionZoom, value: selectedRole)
    }
}

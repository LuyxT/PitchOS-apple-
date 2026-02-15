import SwiftUI

enum AuthChoice {
    case login
    case register
}

struct AuthChoiceView: View {
    @EnvironmentObject private var motion: MotionEngine
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let selected: AuthChoice?
    let onSelect: (AuthChoice) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Login oder Registrierung")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if isCompactPhoneLayout {
                VStack(spacing: 10) {
                    choiceCard(title: "Login", subtitle: "Zuruck in den Tunnel", value: .login)
                    choiceCard(title: "Registrieren", subtitle: "Erstelle dein Konto", value: .register)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        choiceCard(title: "Login", subtitle: "Zuruck in den Tunnel", value: .login)
                        choiceCard(title: "Registrieren", subtitle: "Erstelle dein Konto", value: .register)
                    }
                    VStack(spacing: 10) {
                        choiceCard(title: "Login", subtitle: "Zuruck in den Tunnel", value: .login)
                        choiceCard(title: "Registrieren", subtitle: "Erstelle dein Konto", value: .register)
                    }
                }
            }
        }
        .frame(maxWidth: 460)
    }

    private var isCompactPhoneLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private func choiceCard(title: String, subtitle: String, value: AuthChoice) -> some View {
        let isSelected = selected == value
        let isDimmed = selected != nil && !isSelected
        return Button {
            motion.feedback(.light)
            motion.triggerPulse()
            withAnimation(AppMotion.transitionZoom) {
                onSelect(value)
            }
        } label: {
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surfaceAlt.opacity(isSelected ? 0.9 : 0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? AppTheme.primary : AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(OnboardingCardButtonStyle())
        .depthStyle(.cardLift, isActive: isSelected, animation: AppMotion.hoverLift)
        .hoverLift()
        .scaleEffect(isSelected ? 1.04 : 1)
        .opacity(isDimmed ? 0.6 : 1)
        .animation(AppMotion.transitionZoom, value: selected)
    }
}

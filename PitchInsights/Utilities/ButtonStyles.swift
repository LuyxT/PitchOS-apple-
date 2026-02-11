import SwiftUI

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.84)
            .allowsTightening(true)
            .foregroundStyle(Color.black.opacity(isEnabled ? 1 : 0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppTheme.primary.opacity(configuration.isPressed ? 0.28 : (isEnabled ? 0.18 : 0.12)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.primary.opacity(isEnabled ? 1 : 0.65), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(AppMotion.press, value: configuration.isPressed)
            .opacity(1)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.84)
            .allowsTightening(true)
            .foregroundStyle(Color.black.opacity(isEnabled ? 1 : 0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppTheme.surfaceAlt.opacity(configuration.isPressed ? 0.95 : (isEnabled ? 0.72 : 0.62)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.border.opacity(isEnabled ? 1 : 0.7), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(AppMotion.press, value: configuration.isPressed)
            .opacity(1)
    }
}

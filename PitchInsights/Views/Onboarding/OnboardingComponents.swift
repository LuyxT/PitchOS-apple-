import SwiftUI

struct OnboardingCard<Content: View>: View {
    let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surface.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.9), lineWidth: 1)
            )
    }
}

struct OnboardingInputField: View {
    @EnvironmentObject private var motion: MotionEngine

    let title: String
    @Binding var text: String
    var isSecure: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.surfaceAlt)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocused ? AppTheme.primary : AppTheme.border, lineWidth: 1)
            )
            .depthStyle(.fieldFocus, isActive: isFocused, animation: AppMotion.hoverLift)
            .motionGlow(isFocused, color: AppTheme.primary, animation: AppMotion.hoverLift)
            .focused($isFocused)
        }
    }
}

struct OnboardingRegionPicker: View {
    @Binding var region: String
    private let regions = [
        "Baden-Wuerttemberg", "Bayern", "Berlin", "Brandenburg", "Bremen",
        "Hamburg", "Hessen", "Mecklenburg-Vorpommern", "Niedersachsen",
        "Nordrhein-Westfalen", "Rheinland-Pfalz", "Saarland", "Sachsen",
        "Sachsen-Anhalt", "Schleswig-Holstein", "Thueringen"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Region")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Menu {
                ForEach(regions, id: \.self) { entry in
                    Button(entry) { region = entry }
                }
            } label: {
                HStack {
                    Text(region.isEmpty ? "Region auswahlen" : region)
                        .foregroundStyle(region.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.surfaceAlt)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }
        }
    }
}

struct OnboardingProgressRing: View {
    @EnvironmentObject private var motion: MotionEngine
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.border, lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AppTheme.primary,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: AppTheme.primary.opacity(0.35), radius: 6, x: 0, y: 2)
        }
        .frame(width: 36, height: 36)
        .animation(AppMotion.sceneReveal, value: progress)
        .scaleEffect(motion.successID % 2 == 0 ? 1 : 1.04)
        .animation(AppMotion.successPulse, value: motion.successID)
    }
}

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.black.opacity(isEnabled ? 1 : 0.6))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.primary.opacity(configuration.isPressed ? 0.35 : 0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.primary.opacity(isEnabled ? 1 : 0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(AppMotion.pressDepth, value: configuration.isPressed)
            .hoverLift(.hoverLift)
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary.opacity(isEnabled ? 1 : 0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppTheme.surfaceAlt.opacity(configuration.isPressed ? 0.9 : 0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(AppTheme.border.opacity(isEnabled ? 1 : 0.6), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(AppMotion.pressDepth, value: configuration.isPressed)
            .hoverLift(.hoverLift)
    }
}

struct OnboardingCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(AppMotion.pressDepth, value: configuration.isPressed)
    }
}

struct OnboardingProcessingButton: View {
    let title: String
    let busyTitle: String
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(isBusy ? busyTitle : title) {
            action()
        }
        .buttonStyle(OnboardingPrimaryButtonStyle())
        .hoverLift(.hoverLift)
        .overlay(
            ShimmerOverlay(isActive: isBusy)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        )
    }
}

struct ShimmerOverlay: View {
    let isActive: Bool
    @State private var offset: CGFloat = -160

    var body: some View {
        GeometryReader { proxy in
            if isActive {
                LinearGradient(
                    colors: [Color.clear, Color.white.opacity(0.35), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width * 0.6)
                .offset(x: offset)
                .onAppear {
                    offset = -proxy.size.width
                    withAnimation(AppMotion.scanSweep.repeatForever(autoreverses: false)) {
                        offset = proxy.size.width
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct OnboardingConnectionPanel: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button("Erneut versuchen") { onRetry() }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                Button("Schliessen") { onDismiss() }
                    .buttonStyle(OnboardingSecondaryButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
                .shadow(color: AppTheme.shadow.opacity(0.2), radius: 18, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

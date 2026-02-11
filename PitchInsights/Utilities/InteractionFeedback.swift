import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum HapticStyle {
    case light
    case soft
    case success
}

enum Haptics {
    static func trigger(_ style: HapticStyle) {
        #if os(macOS)
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch style {
        case .success:
            performer.perform(.alignment, performanceTime: .now)
        case .soft, .light:
            performer.perform(.generic, performanceTime: .now)
        }
        #elseif os(iOS)
        switch style {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}

struct InteractiveSurfaceModifier: ViewModifier {
    let hoverScale: CGFloat
    let pressScale: CGFloat
    let hoverShadowOpacity: Double
    let feedback: HapticStyle?
    let isEnabled: Bool

    @State private var isHovering = false
    @GestureState private var isPressing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? hoverScale : 1)
            .scaleEffect(isPressing ? pressScale : 1)
            .shadow(
                color: AppTheme.shadow.opacity(isHovering ? hoverShadowOpacity : 0),
                radius: isHovering ? 10 : 0,
                x: 0,
                y: isHovering ? 6 : 0
            )
            .animation(AppMotion.hoverLift, value: isHovering)
            .animation(AppMotion.pressDepth, value: isPressing)
            .onHover { hovering in
                guard isEnabled else { return }
                isHovering = hovering
            }
            .simultaneousGesture(pressGesture)
    }

    private var pressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.01, maximumDistance: 10)
            .updating($isPressing) { isPressed, state, _ in
                state = isPressed
            }
            .onEnded { _ in
                guard isEnabled, let feedback else { return }
                Haptics.trigger(feedback)
            }
    }
}

extension View {
    func interactiveSurface(
        hoverScale: CGFloat = 1.012,
        pressScale: CGFloat = 0.988,
        hoverShadowOpacity: Double = 0.16,
        feedback: HapticStyle? = .light,
        isEnabled: Bool = true
    ) -> some View {
        modifier(
            InteractiveSurfaceModifier(
                hoverScale: hoverScale,
                pressScale: pressScale,
                hoverShadowOpacity: hoverShadowOpacity,
                feedback: feedback,
                isEnabled: isEnabled
            )
        )
    }
}

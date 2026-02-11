import SwiftUI
import Combine

#if os(macOS)
import AppKit
#endif

final class MotionEngine: ObservableObject {
    @Published var sceneID: Int = 0
    @Published var pulseID: Int = 0
    @Published var successID: Int = 0
    @Published var errorID: Int = 0
    @Published var rippleID: Int = 0

    func advanceScene() {
        sceneID += 1
    }

    func triggerPulse() {
        pulseID += 1
    }

    func triggerSuccess() {
        successID += 1
    }

    func triggerError() {
        errorID += 1
    }

    func triggerRipple() {
        rippleID += 1
    }

    func feedback(_ style: HapticStyle) {
        Haptics.trigger(style)
        #if os(macOS)
        NSSound(named: NSSound.Name("Glass"))?.play()
        #endif
    }

    func transition(_ style: MotionTransitionStyle) -> AnyTransition {
        switch style {
        case .cameraPush:
            return .asymmetric(
                insertion: .scale(scale: 1.02).combined(with: .opacity),
                removal: .scale(scale: 0.98).combined(with: .opacity)
            )
        case .cameraPull:
            return .asymmetric(
                insertion: .scale(scale: 0.98).combined(with: .opacity),
                removal: .scale(scale: 1.02).combined(with: .opacity)
            )
        case .sceneReveal:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .transitionZoom:
            return .asymmetric(
                insertion: .scale(scale: 1.04).combined(with: .opacity),
                removal: .scale(scale: 0.96).combined(with: .opacity)
            )
        }
    }
}

enum MotionTransitionStyle {
    case cameraPush
    case cameraPull
    case sceneReveal
    case transitionZoom
}

struct MotionGlowModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isActive ? 0.4 : 0), radius: isActive ? 14 : 0, x: 0, y: 0)
            .animation(animation, value: isActive)
    }
}

extension View {
    func motionGlow(_ isActive: Bool, color: Color, animation: Animation) -> some View {
        modifier(MotionGlowModifier(isActive: isActive, color: color, animation: animation))
    }

    func errorShake(_ trigger: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(trigger)))
            .animation(AppMotion.errorShake, value: trigger)
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

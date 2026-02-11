import SwiftUI

enum AppMotion {
    static let hover = Animation.spring(response: 0.22, dampingFraction: 0.88, blendDuration: 0.02)
    static let press = Animation.spring(response: 0.18, dampingFraction: 0.9, blendDuration: 0.02)
    static let settle = Animation.spring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.05)
    static let impactHeavy = Animation.spring(response: 0.32, dampingFraction: 0.78, blendDuration: 0.04)
    static let impactMedium = Animation.spring(response: 0.26, dampingFraction: 0.82, blendDuration: 0.03)
    static let hoverLift = Animation.spring(response: 0.22, dampingFraction: 0.88, blendDuration: 0.02)
    static let pressDepth = Animation.spring(response: 0.18, dampingFraction: 0.9, blendDuration: 0.02)
    static let settleSoft = Animation.spring(response: 0.36, dampingFraction: 0.86, blendDuration: 0.05)
    static let cameraPush = Animation.spring(response: 0.42, dampingFraction: 0.82, blendDuration: 0.05)
    static let sceneReveal = Animation.spring(response: 0.48, dampingFraction: 0.86, blendDuration: 0.06)
    static let transitionZoom = Animation.spring(response: 0.38, dampingFraction: 0.84, blendDuration: 0.05)
    static let errorShake = Animation.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.01)
    static let successPulse = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.03)
    static let scanSweep = Animation.spring(response: 1.2, dampingFraction: 0.9, blendDuration: 0.2)
}

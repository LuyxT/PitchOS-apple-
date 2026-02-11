import SwiftUI

struct DepthStyle {
    let scale: CGFloat
    let shadowRadius: CGFloat
    let shadowOpacity: Double
    let shadowY: CGFloat
    let highlightOpacity: Double

    static let none = DepthStyle(scale: 1, shadowRadius: 0, shadowOpacity: 0, shadowY: 0, highlightOpacity: 0)
    static let hoverLift = DepthStyle(scale: 1.02, shadowRadius: 14, shadowOpacity: 0.18, shadowY: 8, highlightOpacity: 0.12)
    static let pressDepth = DepthStyle(scale: 0.985, shadowRadius: 8, shadowOpacity: 0.12, shadowY: 4, highlightOpacity: 0.06)
    static let cardLift = DepthStyle(scale: 1.03, shadowRadius: 18, shadowOpacity: 0.2, shadowY: 10, highlightOpacity: 0.14)
    static let fieldFocus = DepthStyle(scale: 1.01, shadowRadius: 10, shadowOpacity: 0.16, shadowY: 6, highlightOpacity: 0.1)
}

struct DepthStyleModifier: ViewModifier {
    let style: DepthStyle
    let isActive: Bool
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? style.scale : 1)
            .shadow(
                color: AppTheme.shadow.opacity(isActive ? style.shadowOpacity : 0),
                radius: isActive ? style.shadowRadius : 0,
                x: 0,
                y: isActive ? style.shadowY : 0
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(isActive ? style.highlightOpacity : 0), lineWidth: 1)
            )
            .animation(animation, value: isActive)
    }
}

extension View {
    func depthStyle(_ style: DepthStyle, isActive: Bool, animation: Animation) -> some View {
        modifier(DepthStyleModifier(style: style, isActive: isActive, animation: animation))
    }

    func hoverLift(_ style: DepthStyle = .hoverLift) -> some View {
        modifier(HoverLiftModifier(style: style))
    }
}

struct HoverLiftModifier: ViewModifier {
    let style: DepthStyle
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .depthStyle(style, isActive: isHovering, animation: AppMotion.hoverLift)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

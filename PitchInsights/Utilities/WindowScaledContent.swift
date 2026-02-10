import SwiftUI

struct WindowScaledContent<Content: View>: View {
    let window: FloatingWindowState
    let content: Content

    init(window: FloatingWindowState, @ViewBuilder content: () -> Content) {
        self.window = window
        self.content = content()
    }

    var body: some View {
        let preferred = WindowSizing.spec(for: window.kind).preferredSize
        let scale = WindowScaledContent.scale(for: window.size, preferred: preferred)
        content
            .scaleEffect(scale, anchor: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(AppMotion.settle, value: scale)
    }

    private static func scale(for size: CGSize, preferred: CGSize) -> CGFloat {
        guard preferred.width > 0, preferred.height > 0 else { return 1 }
        let ratio = min(size.width / preferred.width, size.height / preferred.height)
        return max(0.88, min(1.06, ratio))
    }
}

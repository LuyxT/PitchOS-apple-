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
        let needsScroll = window.size.width < preferred.width || window.size.height < preferred.height

        Group {
            if needsScroll {
                ScrollView([.horizontal, .vertical]) {
                    content
                        .frame(
                            minWidth: preferred.width,
                            minHeight: preferred.height,
                            alignment: .topLeading
                        )
                }
                .scrollIndicators(.visible)
            } else {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .animation(AppMotion.settle, value: needsScroll)
    }
}

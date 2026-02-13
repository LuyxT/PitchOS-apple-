import SwiftUI

struct ManagedFloatingWindowsLayer: View {
    @Binding var windows: [FloatingWindowState]
    let titleProvider: (FloatingWindowState) -> String
    let contentProvider: (FloatingWindowState) -> AnyView
    let onClose: (UUID) -> Void
    let onFrameCommit: (UUID, CGPoint, CGSize) -> Void
    let workspaceSize: CGSize
    let onBringToFront: (UUID) -> Void

    init(
        windows: Binding<[FloatingWindowState]>,
        workspaceSize: CGSize,
        titleProvider: @escaping (FloatingWindowState) -> String,
        contentProvider: @escaping (FloatingWindowState) -> AnyView,
        onBringToFront: @escaping (UUID) -> Void,
        onClose: @escaping (UUID) -> Void,
        onFrameCommit: @escaping (UUID, CGPoint, CGSize) -> Void
    ) {
        _windows = windows
        self.workspaceSize = workspaceSize
        self.titleProvider = titleProvider
        self.contentProvider = contentProvider
        self.onBringToFront = onBringToFront
        self.onClose = onClose
        self.onFrameCommit = onFrameCommit
    }

    var body: some View {
        ForEach($windows) { $window in
            FloatingWindowView(
                window: $window,
                title: titleProvider(window),
                workspaceSize: workspaceSize,
                bringToFront: { onBringToFront(window.id) },
                close: { onClose(window.id) }
            ) {
                contentProvider(window)
            }
            .zIndex(window.zIndex)
        }
    }
}

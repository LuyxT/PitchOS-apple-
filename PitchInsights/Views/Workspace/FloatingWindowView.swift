import SwiftUI

struct FloatingWindowView<Content: View>: View {
    @Binding var window: FloatingWindowState
    let title: String
    let workspaceSize: CGSize
    let bringToFront: () -> Void
    let close: () -> Void
    private let content: Content

    @State private var dragStart: CGPoint?
    @State private var resizeStart: CGSize?
    @State private var isDraggingWindow = false
    @State private var isResizing = false

    private var minimumSize: CGSize {
        WindowSizing.spec(for: window.kind).minimumSize
    }

    init(
        window: Binding<FloatingWindowState>,
        title: String,
        workspaceSize: CGSize,
        bringToFront: @escaping () -> Void,
        close: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        _window = window
        self.title = title
        self.workspaceSize = workspaceSize
        self.bringToFront = bringToFront
        self.close = close
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            content
        }
        .frame(width: window.size.width, height: window.size.height)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
        .overlay(resizeHandle, alignment: .bottomTrailing)
        .offset(x: window.origin.x, y: window.origin.y)
        .transaction { transaction in
            if isDraggingWindow || isResizing {
                transaction.animation = nil
            }
        }
        .onTapGesture {
            bringToFront()
        }
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(AppTheme.border)
                    )
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .background(AppTheme.surfaceAlt)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStart == nil {
                    dragStart = window.origin
                    bringToFront()
                    isDraggingWindow = true
                }
                guard let start = dragStart else { return }
                let proposedOrigin = CGPoint(
                    x: start.x + value.translation.width,
                    y: start.y + value.translation.height
                )
                window.origin = WindowSizing.clampedOrigin(
                    origin: proposedOrigin,
                    size: window.size,
                    workspace: workspaceSize
                )
            }
            .onEnded { _ in
                window.origin = WindowSizing.clampedOrigin(
                    origin: window.origin,
                    size: window.size,
                    workspace: workspaceSize
                )
                dragStart = nil
                isDraggingWindow = false
            }
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .gesture(resizeGesture)
            .padding(6)
    }

    private var resizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if resizeStart == nil {
                    resizeStart = window.size
                    bringToFront()
                    isResizing = true
                }
                guard let start = resizeStart else { return }
                let proposedSize = CGSize(
                    width: max(minimumSize.width, start.width + value.translation.width),
                    height: max(minimumSize.height, start.height + value.translation.height)
                )
                let clampedSize = WindowSizing.clampedSize(proposedSize, for: window.kind)
                window.size = clampedSize
                window.origin = WindowSizing.clampedOrigin(
                    origin: window.origin,
                    size: clampedSize,
                    workspace: workspaceSize
                )
            }
            .onEnded { _ in
                window.size = WindowSizing.clampedSize(window.size, for: window.kind)
                window.origin = WindowSizing.clampedOrigin(
                    origin: window.origin,
                    size: window.size,
                    workspace: workspaceSize
                )
                resizeStart = nil
                isResizing = false
            }
    }
}

#Preview {
    FloatingWindowView(
        window: .constant(
            FloatingWindowState(
                id: UUID(),
                kind: .module(.kalender),
                size: CGSize(width: 700, height: 480),
                origin: CGPoint(x: 40, y: 40),
                zIndex: 1
            )
        ),
        title: "Kalender",
        workspaceSize: CGSize(width: 1000, height: 700),
        bringToFront: {},
        close: {}
    ) {
        WorkspaceSwitchView(module: .kalender)
    }
    .frame(width: 1000, height: 700)
}

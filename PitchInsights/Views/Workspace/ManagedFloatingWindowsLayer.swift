import SwiftUI

#if os(macOS)
import AppKit

struct ManagedFloatingWindowsLayer: NSViewRepresentable {
    @Binding var windows: [FloatingWindowState]
    let workspaceSize: CGSize
    let titleProvider: (FloatingWindowState) -> String
    let contentProvider: (FloatingWindowState) -> AnyView
    let onBringToFront: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onFrameCommit: (UUID, CGPoint, CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WorkspaceWindowCanvasView {
        let canvas = WorkspaceWindowCanvasView()
        context.coordinator.attach(to: canvas)
        return canvas
    }

    func updateNSView(_ nsView: WorkspaceWindowCanvasView, context: Context) {
        context.coordinator.reconcile(
            windows: windows,
            titleProvider: titleProvider,
            contentProvider: contentProvider,
            onClose: onClose,
            onFrameCommit: onFrameCommit
        )
    }

    final class Coordinator {
        private weak var canvas: WorkspaceWindowCanvasView?
        private var runtimeViews: [UUID: ManagedWorkspaceWindowView] = [:]
        private var zOrder: [UUID: Double] = [:]
        private var modelZOrder: [UUID: Double] = [:]
        private var nextZIndex: Double = 1

        func attach(to canvas: WorkspaceWindowCanvasView) {
            self.canvas = canvas
        }

        func reconcile(
            windows: [FloatingWindowState],
            titleProvider: (FloatingWindowState) -> String,
            contentProvider: (FloatingWindowState) -> AnyView,
            onClose: @escaping (UUID) -> Void,
            onFrameCommit: @escaping (UUID, CGPoint, CGSize) -> Void
        ) {
            guard let canvas else { return }

            let incomingIDs = Set(windows.map(\.id))
            var needsReorder = false

            for id in runtimeViews.keys where !incomingIDs.contains(id) {
                runtimeViews[id]?.removeFromSuperview()
                runtimeViews.removeValue(forKey: id)
                zOrder.removeValue(forKey: id)
                modelZOrder.removeValue(forKey: id)
                needsReorder = true
            }

            for state in windows {
                let runtime: ManagedWorkspaceWindowView
                if let existing = runtimeViews[state.id] {
                    runtime = existing
                } else {
                    runtime = makeRuntimeWindow(
                        state: state,
                        onClose: onClose,
                        onFrameCommit: onFrameCommit
                    )
                    needsReorder = true
                }
                runtimeViews[state.id] = runtime

                if runtime.superview == nil {
                    canvas.addSubview(runtime)
                    needsReorder = true
                }

                if zOrder[state.id] == nil {
                    zOrder[state.id] = max(state.zIndex, nextZIndex)
                    nextZIndex = (zOrder[state.id] ?? nextZIndex) + 1
                }

                if state.zIndex > (modelZOrder[state.id] ?? 0) {
                    zOrder[state.id] = max(zOrder[state.id] ?? 0, state.zIndex)
                    nextZIndex = max(nextZIndex, (zOrder[state.id] ?? 0) + 1)
                    needsReorder = true
                }
                modelZOrder[state.id] = state.zIndex

                runtime.minimumSize = WindowSizing.spec(for: state.kind).minimumSize
                runtime.update(
                    title: titleProvider(state),
                    content: contentProvider(state),
                    kind: state.kind
                )

                let targetFrame = CGRect(
                    x: state.origin.x,
                    y: state.origin.y,
                    width: state.size.width,
                    height: state.size.height
                )
                runtime.applyExternalFrame(targetFrame)
            }

            if needsReorder {
                reorderSubviews()
            }
        }

        private func makeRuntimeWindow(
            state: FloatingWindowState,
            onClose: @escaping (UUID) -> Void,
            onFrameCommit: @escaping (UUID, CGPoint, CGSize) -> Void
        ) -> ManagedWorkspaceWindowView {
            let runtime = ManagedWorkspaceWindowView(windowID: state.id)

            runtime.onRequestFront = { [weak self] id in
                self?.bringToFront(id)
            }
            runtime.onCloseRequested = { id in
                onClose(id)
            }
            runtime.onFrameCommitted = { id, frame in
                onFrameCommit(id, CGPoint(x: frame.origin.x, y: frame.origin.y), frame.size)
            }
            runtime.minimumSize = WindowSizing.spec(for: state.kind).minimumSize

            return runtime
        }

        private func bringToFront(_ id: UUID) {
            zOrder[id] = nextZIndex
            nextZIndex += 1
            reorderSubviews()
        }

        private func reorderSubviews() {
            guard let canvas else { return }
            let ordered = runtimeViews.values.sorted { lhs, rhs in
                let left = zOrder[lhs.windowID] ?? 0
                let right = zOrder[rhs.windowID] ?? 0
                return left < right
            }

            for view in ordered {
                view.removeFromSuperview()
                canvas.addSubview(view)
            }
        }
    }
}

final class WorkspaceWindowCanvasView: NSView {
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        return hit === self ? nil : hit
    }
}

private enum WindowInteractionMode: CaseIterable {
    case move
    case left
    case right
    case top
    case bottom
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var affectsLeft: Bool {
        self == .left || self == .topLeft || self == .bottomLeft
    }

    var affectsRight: Bool {
        self == .right || self == .topRight || self == .bottomRight
    }

    var affectsTop: Bool {
        self == .top || self == .topLeft || self == .topRight
    }

    var affectsBottom: Bool {
        self == .bottom || self == .bottomLeft || self == .bottomRight
    }

    var cursor: NSCursor {
        switch self {
        case .move:
            return .openHand
        case .left, .right:
            return .resizeLeftRight
        case .top, .bottom:
            return .resizeUpDown
        case .topLeft, .bottomRight, .topRight, .bottomLeft:
            return .crosshair
        }
    }
}

private final class WindowInteractionHandleView: NSView {
    let mode: WindowInteractionMode
    weak var owner: ManagedWorkspaceWindowView?

    init(mode: WindowInteractionMode) {
        self.mode = mode
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: mode.cursor)
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        owner?.beginInteraction(mode: mode, event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        owner?.updateInteraction(event: event)
    }

    override func mouseUp(with event: NSEvent) {
        owner?.endInteraction(event: event)
    }
}

private final class FocusAwareHostingView: NSHostingView<AnyView> {
    var onAnyMouseDown: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onAnyMouseDown?()
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        onAnyMouseDown?()
        super.rightMouseDown(with: event)
    }
}

private final class NonInteractiveTitleLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private final class PassthroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private final class ManagedWorkspaceWindowView: NSView {
    let windowID: UUID

    var onCloseRequested: ((UUID) -> Void)?
    var onFrameCommitted: ((UUID, CGRect) -> Void)?
    var onRequestFront: ((UUID) -> Void)?
    var minimumSize: CGSize = CGSize(width: 700, height: 480)

    private(set) var isInteracting = false

    private let titleBarHeight: CGFloat = 34
    private let edgeHandleThickness: CGFloat = 10
    private let cornerHandleSize: CGFloat = 16
    private let topResizeThickness: CGFloat = 6
    private let workspaceMargin: CGFloat = 10

    private let titleBar = NSView()
    private let moveHandle = WindowInteractionHandleView(mode: .move)
    private let titleLabel = NonInteractiveTitleLabel(labelWithString: "")
    private let closeButton = NSButton()
    private let contentHost = FocusAwareHostingView(rootView: AnyView(EmptyView()))
    private lazy var resizeHandles: [WindowInteractionMode: WindowInteractionHandleView] = {
        var map: [WindowInteractionMode: WindowInteractionHandleView] = [:]
        for mode in WindowInteractionMode.allCases where mode != .move {
            map[mode] = WindowInteractionHandleView(mode: mode)
        }
        return map
    }()

    private var currentKind: FloatingWindowKind = .module(.trainerProfil)
    private var didAttachContent = false

    private var interactionMode: WindowInteractionMode?
    private var startMouseLocation: CGPoint = .zero
    private var startFrame: CGRect = .zero
    private var pushedClosedHand = false
    private var resizeSnapshotView: PassthroughImageView?

    override var isFlipped: Bool { true }

    init(windowID: UUID) {
        self.windowID = windowID
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: String, content: AnyView, kind: FloatingWindowKind) {
        titleLabel.stringValue = title
        if !didAttachContent || currentKind != kind {
            currentKind = kind
            contentHost.rootView = content
            didAttachContent = true
        }
    }

    func applyExternalFrame(_ frame: CGRect) {
        guard !isInteracting else { return }
        setFrameWithoutAnimation(pixelAlignedFrame(frame))
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(moveRect, cursor: .openHand)
        addCursorRect(topRect, cursor: .resizeUpDown)
        addCursorRect(bottomRect, cursor: .resizeUpDown)
        addCursorRect(leftRect, cursor: .resizeLeftRight)
        addCursorRect(rightRect, cursor: .resizeLeftRight)
        addCursorRect(topLeftRect, cursor: .crosshair)
        addCursorRect(topRightRect, cursor: .crosshair)
        addCursorRect(bottomLeftRect, cursor: .crosshair)
        addCursorRect(bottomRightRect, cursor: .crosshair)
    }

    override func layout() {
        super.layout()
        layoutWindowSubviews()
    }

    private func layoutWindowSubviews() {
        titleBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: titleBarHeight)
        closeButton.frame = CGRect(x: 10, y: 9, width: 16, height: 16)
        titleLabel.frame = CGRect(x: 36, y: 7, width: max(0, titleBar.bounds.width - 48), height: 20)
        moveHandle.frame = CGRect(
            x: closeButton.frame.maxX + 8,
            y: 0,
            width: max(0, titleBar.bounds.width - (closeButton.frame.maxX + 8)),
            height: titleBarHeight
        )

        contentHost.frame = CGRect(
            x: edgeHandleThickness,
            y: titleBarHeight,
            width: max(0, bounds.width - edgeHandleThickness * 2),
            height: max(0, bounds.height - titleBarHeight - edgeHandleThickness)
        )
        resizeHandles[.top]?.frame = topRect
        resizeHandles[.bottom]?.frame = bottomRect
        resizeHandles[.left]?.frame = leftRect
        resizeHandles[.right]?.frame = rightRect
        resizeHandles[.topLeft]?.frame = topLeftRect
        resizeHandles[.topRight]?.frame = topRightRect
        resizeHandles[.bottomLeft]?.frame = bottomLeftRect
        resizeHandles[.bottomRight]?.frame = bottomRightRect
        resizeSnapshotView?.frame = contentHost.frame

        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: 12,
            cornerHeight: 12,
            transform: nil
        )
    }

    func beginInteraction(mode: WindowInteractionMode, eventLocationInWindow: CGPoint) {
        onRequestFront?(windowID)

        interactionMode = mode
        startMouseLocation = eventLocationInWindow
        startFrame = frame
        isInteracting = true

        if mode == .move {
            NSCursor.closedHand.push()
            pushedClosedHand = true
        } else {
            beginLiveResizeSnapshot()
        }
    }

    func updateInteraction(currentLocationInWindow: CGPoint) {
        guard let mode = interactionMode else { return }

        let deltaX = currentLocationInWindow.x - startMouseLocation.x
        let deltaY = -(currentLocationInWindow.y - startMouseLocation.y)

        var proposed = startFrame

        switch mode {
        case .move:
            proposed.origin.x += deltaX
            proposed.origin.y += deltaY
        case .left:
            proposed.origin.x += deltaX
            proposed.size.width -= deltaX
        case .right:
            proposed.size.width += deltaX
        case .top:
            proposed.origin.y += deltaY
            proposed.size.height -= deltaY
        case .bottom:
            proposed.size.height += deltaY
        case .topLeft:
            proposed.origin.x += deltaX
            proposed.size.width -= deltaX
            proposed.origin.y += deltaY
            proposed.size.height -= deltaY
        case .topRight:
            proposed.size.width += deltaX
            proposed.origin.y += deltaY
            proposed.size.height -= deltaY
        case .bottomLeft:
            proposed.origin.x += deltaX
            proposed.size.width -= deltaX
            proposed.size.height += deltaY
        case .bottomRight:
            proposed.size.width += deltaX
            proposed.size.height += deltaY
        }

        let clamped = clampedFrame(proposed, mode: mode)
        setFrameWithoutAnimation(clamped)
    }

    func endInteraction() {
        guard let mode = interactionMode else { return }

        let finalFrame = pixelAlignedFrame(clampedFrame(frame, mode: mode))
        setFrameWithoutAnimation(finalFrame)
        if mode != .move {
            endLiveResizeSnapshot()
        }
        onFrameCommitted?(windowID, finalFrame)

        interactionMode = nil
        isInteracting = false

        if pushedClosedHand {
            NSCursor.pop()
            pushedClosedHand = false
        }
    }

    @objc private func closeTapped() {
        onCloseRequested?(windowID)
    }

    func beginInteraction(mode: WindowInteractionMode, event: NSEvent) {
        beginInteraction(mode: mode, eventLocationInWindow: event.locationInWindow)
    }

    func updateInteraction(event: NSEvent) {
        updateInteraction(currentLocationInWindow: event.locationInWindow)
    }

    func endInteraction(event _: NSEvent) {
        endInteraction()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(calibratedWhite: 0.87, alpha: 1).cgColor
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 14
        layer?.shadowOffset = CGSize(width: 0, height: 8)
        layer?.masksToBounds = false

        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = NSColor(calibratedWhite: 0.95, alpha: 1).cgColor
        addSubview(titleBar)
        titleBar.addSubview(moveHandle)
        moveHandle.owner = self

        closeButton.title = ""
        closeButton.isBordered = false
        closeButton.bezelStyle = .regularSquare
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Schließen")
        closeButton.contentTintColor = NSColor(calibratedWhite: 0.34, alpha: 1)
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.focusRingType = .none
        titleBar.addSubview(closeButton)

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = NSColor(calibratedWhite: 0.14, alpha: 1)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.usesSingleLineMode = true
        titleBar.addSubview(titleLabel)

        contentHost.onAnyMouseDown = { [weak self] in
            guard let self else { return }
            self.onRequestFront?(self.windowID)
        }
        addSubview(contentHost)
        for handle in resizeHandles.values {
            handle.owner = self
            addSubview(handle, positioned: .above, relativeTo: contentHost)
        }
    }

    private func beginLiveResizeSnapshot() {
        guard resizeSnapshotView == nil else { return }
        guard contentHost.bounds.width > 2, contentHost.bounds.height > 2 else { return }
        guard let rep = contentHost.bitmapImageRepForCachingDisplay(in: contentHost.bounds) else { return }
        contentHost.cacheDisplay(in: contentHost.bounds, to: rep)
        let image = NSImage(size: contentHost.bounds.size)
        image.addRepresentation(rep)

        let snapshot = PassthroughImageView(frame: contentHost.frame)
        snapshot.image = image
        snapshot.imageScaling = .scaleAxesIndependently
        snapshot.wantsLayer = true
        snapshot.layer?.masksToBounds = true
        addSubview(snapshot, positioned: .above, relativeTo: contentHost)

        contentHost.isHidden = true
        resizeSnapshotView = snapshot
    }

    private func endLiveResizeSnapshot() {
        contentHost.isHidden = false
        resizeSnapshotView?.removeFromSuperview()
        resizeSnapshotView = nil
    }

    private func clampedFrame(_ frame: CGRect, mode: WindowInteractionMode) -> CGRect {
        guard let superview else { return frame }

        let bounds = superview.bounds
        let minWidth = minimumSize.width
        let minHeight = minimumSize.height

        var next = frame

        if next.size.width < minWidth {
            if mode.affectsLeft {
                next.origin.x -= (minWidth - next.size.width)
            }
            next.size.width = minWidth
        }

        if next.size.height < minHeight {
            if mode.affectsTop {
                next.origin.y -= (minHeight - next.size.height)
            }
            next.size.height = minHeight
        }

        if next.origin.x < workspaceMargin {
            if mode.affectsLeft {
                next.size.width -= (workspaceMargin - next.origin.x)
                next.size.width = max(next.size.width, minWidth)
            }
            next.origin.x = workspaceMargin
        }

        if next.origin.y < workspaceMargin {
            if mode.affectsTop {
                next.size.height -= (workspaceMargin - next.origin.y)
                next.size.height = max(next.size.height, minHeight)
            }
            next.origin.y = workspaceMargin
        }

        let maxX = bounds.width - workspaceMargin
        if next.maxX > maxX {
            if !mode.affectsRight {
                next.origin.x = max(workspaceMargin, maxX - next.size.width)
            }
        }

        let maxY = bounds.height - workspaceMargin
        if next.maxY > maxY {
            if !mode.affectsBottom {
                next.origin.y = max(workspaceMargin, maxY - next.size.height)
            }
        }

        let maxOriginX = bounds.width - workspaceMargin - next.size.width
        if maxOriginX >= workspaceMargin {
            next.origin.x = min(max(next.origin.x, workspaceMargin), maxOriginX)
        } else {
            next.origin.x = max(next.origin.x, workspaceMargin)
        }

        let maxOriginY = bounds.height - workspaceMargin - next.size.height
        if maxOriginY >= workspaceMargin {
            next.origin.y = min(max(next.origin.y, workspaceMargin), maxOriginY)
        } else {
            next.origin.y = max(next.origin.y, workspaceMargin)
        }

        return next
    }

    private func setFrameWithoutAnimation(_ frame: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.frame = frame
        layoutWindowSubviews()
        CATransaction.commit()
    }

    private func interactionMode(at point: CGPoint) -> WindowInteractionMode? {
        if topLeftRect.contains(point) { return .topLeft }
        if topRightRect.contains(point) { return .topRight }
        if bottomLeftRect.contains(point) { return .bottomLeft }
        if bottomRightRect.contains(point) { return .bottomRight }
        if topRect.contains(point) { return .top }
        if bottomRect.contains(point) { return .bottom }
        if leftRect.contains(point) { return .left }
        if rightRect.contains(point) { return .right }
        if moveRect.contains(point) { return .move }
        return nil
    }

    func interactionMode(atCanvasPoint point: CGPoint) -> WindowInteractionMode? {
        let localPoint = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        guard bounds.contains(localPoint) else { return nil }
        return interactionMode(at: localPoint)
    }

    private var moveRect: CGRect {
        let x = closeButton.frame.maxX + 8
        return CGRect(
            x: x,
            y: 0,
            width: max(0, bounds.width - x),
            height: titleBarHeight
        )
    }

    private var topRect: CGRect {
        CGRect(
            x: cornerHandleSize,
            y: 0,
            width: max(0, bounds.width - cornerHandleSize * 2),
            height: topResizeThickness
        )
    }

    private var bottomRect: CGRect {
        CGRect(
            x: cornerHandleSize,
            y: max(0, bounds.height - edgeHandleThickness),
            width: max(0, bounds.width - cornerHandleSize * 2),
            height: edgeHandleThickness
        )
    }

    private var leftRect: CGRect {
        CGRect(
            x: 0,
            y: cornerHandleSize,
            width: edgeHandleThickness,
            height: max(0, bounds.height - cornerHandleSize * 2)
        )
    }

    private var rightRect: CGRect {
        CGRect(
            x: max(0, bounds.width - edgeHandleThickness),
            y: cornerHandleSize,
            width: edgeHandleThickness,
            height: max(0, bounds.height - cornerHandleSize * 2)
        )
    }

    private var topLeftRect: CGRect {
        CGRect(x: 0, y: 0, width: cornerHandleSize, height: topResizeThickness)
    }

    private var topRightRect: CGRect {
        CGRect(
            x: max(0, bounds.width - cornerHandleSize),
            y: 0,
            width: cornerHandleSize,
            height: topResizeThickness
        )
    }

    private var bottomLeftRect: CGRect {
        CGRect(
            x: 0,
            y: max(0, bounds.height - cornerHandleSize),
            width: cornerHandleSize,
            height: cornerHandleSize
        )
    }

    private var bottomRightRect: CGRect {
        CGRect(
            x: max(0, bounds.width - cornerHandleSize),
            y: max(0, bounds.height - cornerHandleSize),
            width: cornerHandleSize,
            height: cornerHandleSize
        )
    }

    private func pixelAlignedFrame(_ frame: CGRect) -> CGRect {
        CGRect(
            x: frame.origin.x.rounded(.toNearestOrAwayFromZero),
            y: frame.origin.y.rounded(.toNearestOrAwayFromZero),
            width: frame.size.width.rounded(.toNearestOrAwayFromZero),
            height: frame.size.height.rounded(.toNearestOrAwayFromZero)
        )
    }
}

#else

struct ManagedFloatingWindowsLayer: View {
    @Binding var windows: [FloatingWindowState]
    let titleProvider: (FloatingWindowState) -> String
    let contentProvider: (FloatingWindowState) -> AnyView
    let onClose: (UUID) -> Void
    let onFrameCommit: (UUID, CGPoint, CGSize) -> Void
    let workspaceSize: CGSize
    let onBringToFront: (UUID) -> Void

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

#endif

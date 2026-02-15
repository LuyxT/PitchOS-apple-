import SwiftUI
import Combine

enum FloatingWindowKind: Equatable {
    case module(Module)
    case folder(UUID)
    case playerProfile(UUID)
}

struct FloatingWindowState: Identifiable, Equatable {
    let id: UUID
    var kind: FloatingWindowKind
    var size: CGSize
    var origin: CGPoint
    var zIndex: Double
}

@MainActor
final class AppState: ObservableObject {
    @Published var activeModule: Module = ModuleRegistry.enabledModules.first ?? .kader
    @Published var dockModules: [Module] = ModuleRegistry.enabledModules
    @Published var desktopItems: [DesktopItem] = []
    @Published var isWidgetBrowserVisible = false
    @Published var floatingWindows: [FloatingWindowState] = []
    @Published var workspaceSize: CGSize = .zero
    @Published var pendingAnalysisClipReference: MessengerClipReference?

    private var nextZIndex: Double = 1

    init() {
        activeModule = ModuleRegistry.enabledModules.first ?? .kader
        dockModules = ModuleRegistry.enabledModules
        desktopItems = []
    }

    func setActive(_ module: Module) {
        guard ModuleRegistry.isEnabled(module) else { return }
        activeModule = module
        MotionEngine.shared.emit(
            .navigation,
            payload: MotionPayload(
                title: "Modul geöffnet",
                subtitle: module.title,
                iconName: module.iconName,
                severity: .info,
                scope: module.motionScope
            )
        )
    }

    func addToDesktop(_ module: Module) {
        guard ModuleRegistry.isEnabled(module) else { return }
        guard !desktopItems.contains(where: { $0.module == module }) else { return }
        var item = DesktopItem.module(module)
        item.position = nextAvailableDesktopPosition(for: item, preferred: defaultDesktopPosition(for: desktopItems.count))
        desktopItems.append(item)
    }

    func removeFromDesktop(_ id: UUID) {
        desktopItems.removeAll { $0.id == id }
    }

    func toggleDesktopPresence(for module: Module) {
        guard ModuleRegistry.isEnabled(module) else { return }
        if let index = desktopItems.firstIndex(where: { $0.module == module }) {
            desktopItems.remove(at: index)
        } else {
            addToDesktop(module)
        }
    }

    func addWidgetToDesktop(_ module: Module, size: DesktopWidgetSize, preferredPosition: CGPoint? = nil) {
        guard ModuleRegistry.isEnabled(module) else { return }
        var item = DesktopItem.widget(module, size: size)
        let preferred = preferredPosition ?? CGPoint(
            x: max(160, workspaceBounds.width * 0.32),
            y: max(120, workspaceBounds.height * 0.22)
        )
        item.position = nextAvailableDesktopPosition(for: item, preferred: preferred)
        desktopItems.append(item)
    }

    func updateWidgetSize(_ itemID: UUID, size: DesktopWidgetSize) {
        guard let index = desktopItems.firstIndex(where: { $0.id == itemID }) else { return }
        guard desktopItems[index].isWidget else { return }

        desktopItems[index].widgetSize = size
        desktopItems[index].position = nextAvailableDesktopPosition(
            for: desktopItems[index],
            preferred: desktopItems[index].position,
            excluding: itemID
        )
    }

    func setDesktopItemPosition(_ itemID: UUID, to position: CGPoint) {
        guard let index = desktopItems.firstIndex(where: { $0.id == itemID }) else { return }
        let size = desktopItemSize(desktopItems[index])
        desktopItems[index].position = clampedDesktopPosition(position, itemSize: size)
    }

    func finalizeDesktopItemPlacement(_ itemID: UUID) {
        guard let index = desktopItems.firstIndex(where: { $0.id == itemID }) else { return }
        desktopItems[index].position = nextAvailableDesktopPosition(
            for: desktopItems[index],
            preferred: desktopItems[index].position,
            excluding: itemID
        )
    }

    func showWidgetBrowser() {
        isWidgetBrowserVisible = true
    }

    func hideWidgetBrowser() {
        isWidgetBrowserVisible = false
    }

    func toggleWidgetBrowser() {
        isWidgetBrowserVisible.toggle()
    }

    func createFolder() {
        let baseName = "Neuer Ordner"
        let existingNames = desktopItems.compactMap { $0.folderName }
        let name = nextAvailableFolderName(baseName: baseName, existing: existingNames)
        var item = DesktopItem.folder(name)
        item.position = nextAvailableDesktopPosition(for: item, preferred: defaultDesktopPosition(for: desktopItems.count))
        desktopItems.append(item)
    }

    private func nextAvailableFolderName(baseName: String, existing: [String]) -> String {
        if !existing.contains(baseName) {
            return baseName
        }
        var index = 2
        while existing.contains("\(baseName) \(index)") {
            index += 1
        }
        return "\(baseName) \(index)"
    }

    private func defaultDesktopPosition(for index: Int) -> CGPoint {
        let usableWidth = max(320, workspaceSize.width - 120)
        let stepX: CGFloat = 108
        let stepY: CGFloat = 108
        let columns = max(1, Int(usableWidth / stepX))
        let col = index % columns
        let row = index / columns
        let x = 64 + CGFloat(col) * stepX
        let y = 64 + CGFloat(row) * stepY
        return CGPoint(x: x, y: y)
    }

    func updateWorkspaceSize(_ size: CGSize) {
        workspaceSize = size
        clampDesktopItemsToWorkspace()
        clampFloatingWindowsToWorkspace()
    }

    func openFloatingWindow(_ module: Module) {
        guard ModuleRegistry.isEnabled(module) else { return }
        if let index = floatingWindows.firstIndex(where: {
            if case .module(let existing) = $0.kind {
                return existing == module
            }
            return false
        }) {
            bringToFront(floatingWindows[index].id)
            activeModule = module
            return
        }

        let window = buildWindowState(
            kind: .module(module),
            cascadeOffset: nextCascadeOffset()
        )
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            floatingWindows.append(window)
        }
        activeModule = module
        MotionEngine.shared.emit(
            .navigation,
            payload: MotionPayload(
                title: "Fenster geöffnet",
                subtitle: module.title,
                iconName: module.iconName,
                severity: .info,
                scope: module.motionScope
            )
        )
    }

    func openFolderWindow(_ folderId: UUID) {
        if let index = floatingWindows.firstIndex(where: { $0.kind == .folder(folderId) }) {
            bringToFront(floatingWindows[index].id)
            return
        }

        let window = buildWindowState(
            kind: .folder(folderId),
            cascadeOffset: nextCascadeOffset()
        )
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            floatingWindows.append(window)
        }
    }

    func openPlayerProfileWindow(playerID: UUID) {
        if let index = floatingWindows.firstIndex(where: { $0.kind == .playerProfile(playerID) }) {
            bringToFront(floatingWindows[index].id)
            return
        }

        let window = buildWindowState(
            kind: .playerProfile(playerID),
            cascadeOffset: nextCascadeOffset() + 18
        )
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            floatingWindows.append(window)
        }
    }

    func openMessengerClipReference(_ ref: MessengerClipReference) {
        pendingAnalysisClipReference = ref
        openFloatingWindow(.spielanalyse)
        activeModule = .spielanalyse
    }

    func consumePendingAnalysisClipReference() -> MessengerClipReference? {
        let ref = pendingAnalysisClipReference
        pendingAnalysisClipReference = nil
        return ref
    }

    func windowTitle(for window: FloatingWindowState, players: [Player]) -> String {
        switch window.kind {
        case .module(let module):
            return module.title
        case .folder(let id):
            return desktopItems.first(where: { $0.id == id })?.name ?? "Ordner"
        case .playerProfile(let playerID):
            let name = players.first(where: { $0.id == playerID })?.name ?? "Spieler"
            return "Spielerprofil - \(name)"
        }
    }

    func bringToFront(_ id: UUID) {
        guard let index = floatingWindows.firstIndex(where: { $0.id == id }) else { return }
        floatingWindows[index].zIndex = nextZIndex
        nextZIndex += 1
    }

    func closeFloatingWindow(_ id: UUID) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            floatingWindows.removeAll { $0.id == id }
        }
    }

    func commitFloatingWindowFrame(_ id: UUID, origin: CGPoint, size: CGSize) {
        guard let index = floatingWindows.firstIndex(where: { $0.id == id }) else { return }
        let kind = floatingWindows[index].kind
        let workspace = effectiveWorkspaceSize(for: kind)
        let clampedSize = WindowSizing.clampedSize(size, for: kind)
        let clampedOrigin = WindowSizing.clampedOrigin(
            origin: origin,
            size: clampedSize,
            workspace: workspace
        )
        floatingWindows[index].size = clampedSize
        floatingWindows[index].origin = clampedOrigin
    }

    private func buildWindowState(kind: FloatingWindowKind, cascadeOffset: CGFloat) -> FloatingWindowState {
        let workspace = effectiveWorkspaceSize(for: kind)
        let size = WindowSizing.defaultSize(for: kind, workspace: workspace)
        let centered = CGPoint(
            x: (workspace.width - size.width) / 2 + cascadeOffset,
            y: (workspace.height - size.height) / 2 + cascadeOffset
        )
        let origin = WindowSizing.clampedOrigin(
            origin: centered,
            size: size,
            workspace: workspace
        )

        defer { nextZIndex += 1 }
        return FloatingWindowState(
            id: UUID(),
            kind: kind,
            size: size,
            origin: origin,
            zIndex: nextZIndex
        )
    }

    private func effectiveWorkspaceSize(for kind: FloatingWindowKind) -> CGSize {
        guard workspaceSize.width > 0, workspaceSize.height > 0 else {
            let preferred = WindowSizing.spec(for: kind).preferredSize
            return CGSize(width: preferred.width + 120, height: preferred.height + 120)
        }
        return workspaceSize
    }

    private func nextCascadeOffset() -> CGFloat {
        CGFloat(floatingWindows.count % 6) * 18
    }

    private var workspaceBounds: CGSize {
        guard workspaceSize.width > 0, workspaceSize.height > 0 else {
            return CGSize(width: 1400, height: 900)
        }
        return workspaceSize
    }

    private func desktopItemSize(_ item: DesktopItem) -> CGSize {
        if item.isWidget {
            return item.widgetSize.dimensions
        }
        return CGSize(width: 96, height: 96)
    }

    private func clampedDesktopPosition(_ position: CGPoint, itemSize: CGSize) -> CGPoint {
        let bounds = workspaceBounds
        let margin: CGFloat = 20
        let halfWidth = itemSize.width / 2
        let halfHeight = itemSize.height / 2

        let minX = margin + halfWidth
        let maxX = max(minX, bounds.width - margin - halfWidth)
        let minY = margin + halfHeight
        let maxY = max(minY, bounds.height - margin - halfHeight)

        let clamped = CGPoint(
            x: min(max(position.x, minX), maxX),
            y: min(max(position.y, minY), maxY)
        )

        return snappedDesktopPosition(clamped)
    }

    private func snappedDesktopPosition(_ point: CGPoint) -> CGPoint {
        let step: CGFloat = 12
        return CGPoint(
            x: (point.x / step).rounded() * step,
            y: (point.y / step).rounded() * step
        )
    }

    private func desktopFrame(for item: DesktopItem, at position: CGPoint) -> CGRect {
        let size = desktopItemSize(item)
        return CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func intersectsDesktopItem(_ frame: CGRect, excluding: UUID?) -> Bool {
        desktopItems.contains { item in
            guard item.id != excluding else { return false }
            let other = desktopFrame(for: item, at: item.position).insetBy(dx: -8, dy: -8)
            return frame.intersects(other)
        }
    }

    private func nextAvailableDesktopPosition(
        for item: DesktopItem,
        preferred: CGPoint,
        excluding: UUID? = nil
    ) -> CGPoint {
        let desired = clampedDesktopPosition(preferred, itemSize: desktopItemSize(item))
        let desiredFrame = desktopFrame(for: item, at: desired)
        if !intersectsDesktopItem(desiredFrame, excluding: excluding) {
            return desired
        }

        let step: CGFloat = 24
        for radius in 1...80 {
            for dx in -radius...radius {
                for dy in -radius...radius {
                    guard abs(dx) == radius || abs(dy) == radius else { continue }
                    let probe = CGPoint(
                        x: desired.x + CGFloat(dx) * step,
                        y: desired.y + CGFloat(dy) * step
                    )
                    let candidate = clampedDesktopPosition(probe, itemSize: desktopItemSize(item))
                    let candidateFrame = desktopFrame(for: item, at: candidate)
                    if !intersectsDesktopItem(candidateFrame, excluding: excluding) {
                        return candidate
                    }
                }
            }
        }

        return desired
    }

    private func clampDesktopItemsToWorkspace() {
        guard !desktopItems.isEmpty else { return }
        for index in desktopItems.indices {
            let itemID = desktopItems[index].id
            let size = desktopItemSize(desktopItems[index])
            desktopItems[index].position = clampedDesktopPosition(desktopItems[index].position, itemSize: size)
            desktopItems[index].position = nextAvailableDesktopPosition(
                for: desktopItems[index],
                preferred: desktopItems[index].position,
                excluding: itemID
            )
        }
    }

    private func clampFloatingWindowsToWorkspace() {
        guard workspaceSize.width > 0, workspaceSize.height > 0 else { return }
        for index in floatingWindows.indices {
            let kind = floatingWindows[index].kind
            let clampedSize = WindowSizing.clampedSize(floatingWindows[index].size, for: kind)
            let clampedOrigin = WindowSizing.clampedOrigin(
                origin: floatingWindows[index].origin,
                size: clampedSize,
                workspace: workspaceSize
            )
            floatingWindows[index].size = clampedSize
            floatingWindows[index].origin = clampedOrigin
        }
    }
}

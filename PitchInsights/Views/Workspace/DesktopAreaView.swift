import SwiftUI

struct DesktopAreaView: View {
    @EnvironmentObject private var appState: AppState
    @State private var renamingItemID: UUID?
    @State private var renameDraft: String = ""

    var body: some View {
        ZStack {
            ForEach($appState.desktopItems) { $item in
                if item.isWidget, let module = item.module {
                    DesktopWidgetItemView(
                        item: $item,
                        module: module
                    )
                    .position(item.position)
                } else {
                    DesktopIconView(
                        item: $item,
                        isRenaming: renamingItemID == item.id,
                        renameDraft: $renameDraft,
                        open: {
                            openItem(item)
                        },
                        beginRename: {
                            beginRename(item)
                        },
                        commitRename: {
                            commitRename(item: $item)
                        },
                        cancelRename: {
                            renamingItemID = nil
                        }
                    )
                    .position(item.position)
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Neuer Ordner") {
                appState.createFolder()
            }
            Button("Widget hinzufügen") {
                appState.showWidgetBrowser()
            }
        }
        .dropDestination(for: String.self) { items, location in
            for payload in items {
                if let widgetDrop = DesktopDragPayload.parseWidget(payload) {
                    appState.addWidgetToDesktop(
                        widgetDrop.module,
                        size: widgetDrop.size,
                        preferredPosition: location
                    )
                } else if let module = Module.from(id: payload) {
                    appState.addToDesktop(module)
                }
            }
            return true
        }
        .onAppear {
            applyDefaultPositionsIfNeeded()
        }
    }

    private func openItem(_ item: DesktopItem) {
        Haptics.trigger(.light)
        if let module = item.module {
            appState.openFloatingWindow(module)
        } else if item.type == .folder {
            appState.openFolderWindow(item.id)
        }
    }

    private func beginRename(_ item: DesktopItem) {
        guard item.type == .folder else { return }
        Haptics.trigger(.soft)
        renameDraft = item.name
        renamingItemID = item.id
    }

    private func commitRename(item: Binding<DesktopItem>) {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            item.wrappedValue.name = trimmed
            Haptics.trigger(.success)
        }
        renamingItemID = nil
    }

    private func applyDefaultPositionsIfNeeded() {
        var current = appState.desktopItems
        var changed = false
        var x: CGFloat = 64
        var y: CGFloat = 64
        let stepX: CGFloat = 108
        let stepY: CGFloat = 108
        let maxWidth: CGFloat = max(320, appState.workspaceSize.width - 120)

        for index in current.indices where current[index].position.x < 0 || current[index].position.y < 0 {
            if current[index].isWidget {
                current[index].position = CGPoint(
                    x: max(180, appState.workspaceSize.width * 0.32 + CGFloat(index % 3) * 24),
                    y: max(110, appState.workspaceSize.height * 0.22 + CGFloat(index % 2) * 18)
                )
            } else {
                current[index].position = CGPoint(x: x, y: y)
                x += stepX
                if x > maxWidth {
                    x = 64
                    y += stepY
                }
            }
            changed = true
        }

        if changed {
            appState.desktopItems = current
            for item in appState.desktopItems {
                appState.finalizeDesktopItemPlacement(item.id)
            }
        }
    }
}

private struct DesktopIconView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var item: DesktopItem
    let isRenaming: Bool
    @Binding var renameDraft: String
    let open: () -> Void
    let beginRename: () -> Void
    let commitRename: () -> Void
    let cancelRename: () -> Void
    @State private var isHovering = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: item.iconName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
            if isRenaming && item.type == .folder {
                TextField("", text: $renameDraft)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
                    .onSubmit {
                        commitRename()
                    }
                    .modifier(FolderRenameExitModifier(onCancel: cancelRename))
            } else {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(width: 96, height: 96)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering ? AppTheme.hover : Color.clear)
        )
        .interactiveSurface(
            hoverScale: 1.012,
            pressScale: 0.988,
            hoverShadowOpacity: 0.12,
            feedback: .light
        )
        .transaction { transaction in
            if isDragging {
                transaction.animation = nil
            }
        }
        .offset(dragOffset)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(AppMotion.hover, value: isHovering)
        .onTapGesture(count: 2) {
            open()
        }
        .gesture(dragGesture)
        .contextMenu {
            if item.type == .folder {
                Button("Umbenennen") {
                    beginRename()
                }
                Button("Löschen", role: .destructive) {
                    Haptics.trigger(.soft)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        appState.removeFromDesktop(item.id)
                    }
                }
            } else if item.type == .module {
                Button("Öffnen") {
                    open()
                }
                Button("Vom Home entfernen", role: .destructive) {
                    Haptics.trigger(.soft)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        appState.removeFromDesktop(item.id)
                    }
                }
            }
        }
        .draggable(item.module?.id ?? item.id.uuidString)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                }
                dragOffset = value.translation
            }
            .onEnded { _ in
                let finalPosition = CGPoint(
                    x: item.position.x + dragOffset.width,
                    y: item.position.y + dragOffset.height
                )
                appState.setDesktopItemPosition(item.id, to: finalPosition)
                appState.finalizeDesktopItemPlacement(item.id)
                dragOffset = .zero
                isDragging = false
            }
    }
}

private struct DesktopWidgetItemView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var item: DesktopItem
    let module: Module

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var isHovering = false

    var body: some View {
        HomeWidgetCardView(module: module, size: item.widgetSize)
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .animation(AppMotion.hover, value: isHovering)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .interactiveSurface(
                hoverScale: 1.01,
                pressScale: 0.988,
                hoverShadowOpacity: 0.1,
                feedback: .light
            )
            .transaction { transaction in
                if isDragging {
                    transaction.animation = nil
                }
            }
            .offset(dragOffset)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                Haptics.trigger(.light)
                appState.openFloatingWindow(module)
            }
            .gesture(dragGesture)
            .contextMenu {
                Button("Öffnen") {
                    Haptics.trigger(.light)
                    appState.openFloatingWindow(module)
                }
                Menu("Größe") {
                    ForEach(DesktopWidgetSize.allCases) { size in
                        Button(size.title) {
                            Haptics.trigger(.soft)
                            appState.updateWidgetSize(item.id, size: size)
                        }
                    }
                }
                Button("Entfernen", role: .destructive) {
                    Haptics.trigger(.soft)
                    appState.removeFromDesktop(item.id)
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                }
                dragOffset = value.translation
            }
            .onEnded { _ in
                let finalPosition = CGPoint(
                    x: item.position.x + dragOffset.width,
                    y: item.position.y + dragOffset.height
                )
                appState.setDesktopItemPosition(item.id, to: finalPosition)
                appState.finalizeDesktopItemPlacement(item.id)
                dragOffset = .zero
                isDragging = false
            }
    }
}

private struct FolderRenameExitModifier: ViewModifier {
    let onCancel: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(macOS)
        content.onExitCommand(perform: onCancel)
        #else
        content
        #endif
    }
}

#Preview {
    DesktopAreaView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 1100, height: 700)
}

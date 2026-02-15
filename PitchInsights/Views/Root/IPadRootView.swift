import SwiftUI

struct IPadRootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dataStore: AppDataStore

    @State private var selectedModule: Module?
    @State private var sheetDestination: IPadSheetDestination?

    private var modules: [Module] {
        ModuleRegistry.modules(for: .ipadTablet)
    }

    var body: some View {
        NavigationSplitView {
            List(modules, selection: $selectedModule) { module in
                Label(ModuleRegistry.definition(for: module).title, systemImage: ModuleRegistry.definition(for: module).iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .tag(module)
            }
            .navigationTitle("Module")
        } detail: {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                if let selectedModule {
                    IPadModuleHostView(module: selectedModule)
                        .id(selectedModule)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    ContentUnavailableView(
                        "Modul wählen",
                        systemImage: "square.grid.2x2",
                        description: Text("Bitte ein Modul in der Sidebar auswählen.")
                    )
                }
            }
            .animation(.easeInOut(duration: 0.22), value: selectedModule)
        }
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case .folder(let id):
                NavigationStack {
                    FolderWorkspaceView(folderId: id)
                        .environmentObject(appState)
                        .environmentObject(dataStore)
                        .navigationTitle("Ordner")
                }
            case .playerProfile(let id):
                NavigationStack {
                    PlayerProfileWindowView(playerID: id)
                        .environmentObject(dataStore)
                        .navigationTitle("Spielerprofil")
                }
            }
        }
        .onAppear {
            syncInitialSelection()
        }
        .onChange(of: selectedModule) { _, newValue in
            guard let newValue else { return }
            if appState.activeModule != newValue {
                appState.setActive(newValue)
            }
        }
        .onChange(of: appState.activeModule) { _, newValue in
            guard modules.contains(newValue) else { return }
            if selectedModule != newValue {
                selectedModule = newValue
            }
        }
        .onChange(of: appState.floatingWindows) { _, newValue in
            handleFloatingWindowRequests(newValue)
        }
    }

    private func syncInitialSelection() {
        if modules.contains(appState.activeModule) {
            selectedModule = appState.activeModule
        } else {
            selectedModule = modules.first
            if let selectedModule {
                appState.setActive(selectedModule)
            }
        }
    }

    private func handleFloatingWindowRequests(_ windows: [FloatingWindowState]) {
        guard let latest = windows.last else { return }

        switch latest.kind {
        case .module(let module):
            if modules.contains(module) {
                selectedModule = module
                appState.setActive(module)
            }
        case .folder(let id):
            sheetDestination = .folder(id)
        case .playerProfile(let id):
            sheetDestination = .playerProfile(id)
        }

        appState.closeFloatingWindow(latest.id)
    }
}

private struct IPadModuleHostView: View {
    let module: Module

    private var title: String {
        ModuleRegistry.definition(for: module).title
    }

    private var preferredSize: CGSize {
        ModuleRegistry.definition(for: module).windowPreferredSize
    }

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(360, proxy.size.width - 24)
            let availableHeight = max(420, proxy.size.height - 24)
            let needsHorizontalScroll = preferredSize.width > availableWidth * 1.08

            ScrollView(needsHorizontalScroll ? [.horizontal, .vertical] : [.vertical]) {
                ModuleRegistry.makeView(for: module)
                    .frame(
                        minWidth: availableWidth,
                        minHeight: availableHeight,
                        alignment: .topLeading
                    )
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.visible)
        }
        .background(AppTheme.background)
        .navigationTitle(title)
    }
}

private enum IPadSheetDestination: Identifiable {
    case folder(UUID)
    case playerProfile(UUID)

    var id: String {
        switch self {
        case .folder(let id):
            return "folder.\(id.uuidString)"
        case .playerProfile(let id):
            return "player.\(id.uuidString)"
        }
    }
}

#Preview {
    IPadRootView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
}

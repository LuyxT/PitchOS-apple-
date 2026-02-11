import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var session: AppSessionStore

    var body: some View {
        Group {
            switch session.phase {
            case .checking:
                sessionChecking
            case .unauthenticated:
                OnboardingFlowView(startAt: .welcome)
            case .onboarding:
                OnboardingFlowView(startAt: onboardingStartStep)
            case .ready:
                mainWorkspace
            case .backendUnavailable:
                sessionChecking
            }
        }
    }

    private var sessionChecking: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Session wird geladen...")
                .font(.headline)
            Text(BackendConfig.baseURLString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var mainWorkspace: some View {
        GeometryReader { proxy in
            ZStack {
                background
                VStack(spacing: 0) {
                    TopBarView()
                    ZStack(alignment: .topLeading) {
                        DesktopAreaView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        ManagedFloatingWindowsLayer(
                            windows: $appState.floatingWindows,
                            workspaceSize: appState.workspaceSize,
                            titleProvider: { window in
                                appState.windowTitle(for: window, players: dataStore.players)
                            },
                            contentProvider: { window in
                                windowContent(for: window)
                            },
                            onBringToFront: { id in
                                appState.bringToFront(id)
                            },
                            onClose: { id in
                                appState.closeFloatingWindow(id)
                            },
                            onFrameCommit: { id, origin, size in
                                appState.commitFloatingWindowFrame(id, origin: origin, size: size)
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    DockSwitcherView()
                        .padding(.bottom, 18)
                }
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appState.isWidgetBrowserVisible {
                    WidgetBrowserPanelView()
                        .frame(
                            width: min(proxy.size.width - 60, 980),
                            height: min(proxy.size.height - 90, 620)
                        )
                        .position(
                            x: proxy.size.width / 2,
                            y: min(max(120, proxy.size.height * 0.42), proxy.size.height - 120)
                        )
                        .transition(.scale(scale: 0.97).combined(with: .opacity))
                        .zIndex(2000)
                }
            }
            .tint(AppTheme.primary)
            .background(
                GeometryReader { innerProxy in
                    Color.clear
                        .onAppear {
                            appState.updateWorkspaceSize(innerProxy.size)
                        }
                        .onChange(of: innerProxy.size) { _, newValue in
                            appState.updateWorkspaceSize(newValue)
                        }
                }
            )
        }
        .frame(minWidth: 1220, minHeight: 780)
    }

    private var background: some View {
        AppTheme.background
            .ignoresSafeArea()
    }

    private var onboardingStartStep: OnboardingFlowView.Step {
        switch session.onboardingState?.lastStep {
        case "club":
            return .club
        case "profile":
            return .profile
        case "confirm", "complete":
            return .confirm
        default:
            return .role
        }
    }

    private func windowContent(for window: FloatingWindowState) -> AnyView {
        let view: AnyView
        switch window.kind {
        case .module(let module):
            view = AnyView(WorkspaceSwitchView(module: module))
        case .folder(let id):
            view = AnyView(FolderWorkspaceView(folderId: id))
        case .playerProfile(let playerID):
            view = AnyView(PlayerProfileWindowView(playerID: playerID))
        }
        return AnyView(
            WindowScaledContent(window: window) {
                view
                    .environmentObject(appState)
                    .environmentObject(dataStore)
            }
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
    .environmentObject(AppSessionStore())
}

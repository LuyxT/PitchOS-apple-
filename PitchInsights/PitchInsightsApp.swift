import SwiftUI

@main
struct PitchInsightsApp: App {
    enum LaunchState {
        case checking
        case ready
        case backendUnavailable
    }

    @StateObject private var appState = AppState()
    @StateObject private var dataStore = AppDataStore()
    @State private var launchState: LaunchState = .checking

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch launchState {
                case .checking:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Backend wird geprüft …")
                            .font(.headline)
                        Text(BackendConfig.baseURLString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.background.ignoresSafeArea())

                case .ready:
                    ContentView()
                        .environmentObject(appState)
                        .environmentObject(dataStore)

                case .backendUnavailable:
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.orange)
                        Text("Backend nicht erreichbar")
                            .font(.title3.weight(.semibold))
                        Text("Bitte prüfe das Backend und versuche es erneut.")
                            .foregroundStyle(.secondary)
                        Button("Erneut prüfen") {
                            Task { await bootstrap() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.background.ignoresSafeArea())
                }
            }
            .frame(minWidth: 1220, minHeight: 780)
            .task {
                await bootstrap()
            }
        }
        #if os(macOS)
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentMinSize)
        #endif
        .commands {
            PitchInsightsCommands(appState: appState)
        }
    }

    @MainActor
    private func bootstrap() async {
        launchState = .checking
        let isHealthy = await dataStore.checkBackendBootstrap()
        if !isHealthy {
            launchState = .backendUnavailable
            return
        }
        launchState = .ready
    }
}

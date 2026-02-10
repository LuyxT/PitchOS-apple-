import SwiftUI

@main
struct PitchInsightsApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var dataStore = AppDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(dataStore)
                .task {
                    await dataStore.refreshFromBackend()
                }
        }
        .commands {
            PitchInsightsCommands(appState: appState)
        }
    }
}

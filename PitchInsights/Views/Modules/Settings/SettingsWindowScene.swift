import SwiftUI

struct SettingsWindowScene: Scene {
    var body: some Scene {
        WindowGroup("Einstellungen") {
            SettingsView()
                .frame(minWidth: 1120, minHeight: 760)
        }
        #if os(macOS)
        .defaultSize(width: 1320, height: 860)
        .windowResizability(.contentMinSize)
        #endif
    }
}

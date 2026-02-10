import SwiftUI

struct EinstellungenWorkspaceView: View {
    var body: some View {
        SettingsView()
            .background(AppTheme.background)
    }
}

#Preview {
    EinstellungenWorkspaceView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 1200, height: 780)
}

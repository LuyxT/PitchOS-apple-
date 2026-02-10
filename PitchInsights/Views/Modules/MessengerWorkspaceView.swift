import SwiftUI

struct MessengerWorkspaceView: View {
    var body: some View {
        MessengerModuleWorkspaceView()
            .background(AppTheme.background)
    }
}

#Preview {
    MessengerWorkspaceView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 1200, height: 760)
}


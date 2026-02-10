import SwiftUI

struct VerwaltungWorkspaceView: View {
    var body: some View {
        AdminWorkspaceView()
            .background(AppTheme.background)
    }
}

#Preview {
    VerwaltungWorkspaceView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 1220, height: 780)
}


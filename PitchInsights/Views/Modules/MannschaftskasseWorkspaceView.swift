import SwiftUI

struct MannschaftskasseWorkspaceView: View {
    var body: some View {
        CashWorkspaceView()
            .background(AppTheme.background)
    }
}

#Preview {
    MannschaftskasseWorkspaceView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 1220, height: 780)
}

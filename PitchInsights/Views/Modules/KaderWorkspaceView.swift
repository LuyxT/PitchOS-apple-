import SwiftUI

struct KaderWorkspaceView: View {
    var body: some View {
        SquadView()
    }
}

#Preview {
    KaderWorkspaceView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 800, height: 500)
}

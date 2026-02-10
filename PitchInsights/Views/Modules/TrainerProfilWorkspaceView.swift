import SwiftUI

struct TrainerProfilWorkspaceView: View {
    var body: some View {
        ProfileView()
    }
}

#Preview {
    TrainerProfilWorkspaceView()
        .environmentObject(AppDataStore())
        .frame(width: 1200, height: 780)
}

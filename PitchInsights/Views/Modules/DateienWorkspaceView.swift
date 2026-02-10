import SwiftUI

struct DateienWorkspaceView: View {
    var body: some View {
        FilesWorkspaceView()
    }
}

#Preview {
    DateienWorkspaceView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 800, height: 500)
}

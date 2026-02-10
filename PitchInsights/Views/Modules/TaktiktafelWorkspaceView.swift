import SwiftUI

struct TaktiktafelWorkspaceView: View {
    var body: some View {
        TacticsBoardView()
    }
}

#Preview {
    TaktiktafelWorkspaceView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 1100, height: 740)
}


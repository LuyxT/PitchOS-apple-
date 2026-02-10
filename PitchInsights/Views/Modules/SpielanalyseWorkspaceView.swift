import SwiftUI

struct SpielanalyseWorkspaceView: View {
    var body: some View {
        AnalysisWorkspaceView()
            .background(AppTheme.background)
    }
}

#Preview {
    SpielanalyseWorkspaceView()
        .environmentObject(AppDataStore())
        .frame(width: 1200, height: 760)
}

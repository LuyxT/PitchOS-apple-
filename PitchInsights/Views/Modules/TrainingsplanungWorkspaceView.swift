import SwiftUI

struct TrainingsplanungWorkspaceView: View {
    var body: some View {
        TrainingPlanningWorkspaceView()
    }
}

#Preview {
    TrainingsplanungWorkspaceView()
        .environmentObject(AppDataStore())
        .frame(width: 800, height: 500)
}

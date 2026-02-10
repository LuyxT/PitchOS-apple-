import SwiftUI

struct WorkspaceSwitchView: View {
    let module: Module

    var body: some View {
        switch module {
        case .trainerProfil:
            TrainerProfilWorkspaceView()
        case .kader:
            KaderWorkspaceView()
        case .kalender:
            KalenderWorkspaceView()
        case .trainingsplanung:
            TrainingsplanungWorkspaceView()
        case .spielanalyse:
            SpielanalyseWorkspaceView()
        case .taktiktafel:
            TaktiktafelWorkspaceView()
        case .messenger:
            MessengerWorkspaceView()
        case .dateien:
            DateienWorkspaceView()
        case .verwaltung:
            VerwaltungWorkspaceView()
        case .mannschaftskasse:
            MannschaftskasseWorkspaceView()
        case .einstellungen:
            EinstellungenWorkspaceView()
        }
    }
}

#Preview {
    WorkspaceSwitchView(module: .trainerProfil)
        .frame(width: 800, height: 500)
}

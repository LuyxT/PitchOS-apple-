import Foundation

@MainActor
final class FileOpenRouter {
    func open(file: CloudFile, appState: AppState, dataStore: AppDataStore) async {
        switch file.type {
        case .video:
            appState.openFloatingWindow(.spielanalyse)
            if let sessionID = file.linkedAnalysisSessionID {
                dataStore.activeAnalysisSessionID = sessionID
            } else {
                _ = try? await dataStore.createAnalysisSessionFromCloudFile(fileID: file.id)
            }
        case .clip:
            if let clipID = file.linkedAnalysisClipID,
               let ref = dataStore.clipReferenceForFileOpen(clipID: clipID) {
                appState.openMessengerClipReference(ref)
            } else {
                appState.openFloatingWindow(.spielanalyse)
            }
        case .tacticboard:
            if let scenarioID = file.linkedTacticsScenarioID {
                dataStore.activeTacticsScenarioID = scenarioID
            }
            appState.openFloatingWindow(.taktiktafel)
        case .trainingplan:
            if let planID = file.linkedTrainingPlanID {
                dataStore.activeTrainingPlanID = planID
            }
            appState.openFloatingWindow(.trainingsplanung)
        case .image, .document, .export, .analysisExport, .other:
            dataStore.selectedCloudFileID = file.id
            appState.openFloatingWindow(.dateien)
        }
    }
}

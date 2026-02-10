import SwiftUI
#if os(macOS)
import AppKit
#endif

struct TacticsBoardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dataStore: AppDataStore

    @State private var playerTokenScale = 1.0
    @StateObject private var viewModel = TacticsViewModel()
    @StateObject private var drawingViewModel = TacticsDrawingViewModel()
    @State private var isDrawingMode = false

    private var scenario: TacticsScenario? {
        viewModel.currentScenario(in: dataStore)
    }

    private var board: TacticsBoardState {
        viewModel.currentBoard(in: dataStore)
    }

    private var playersByID: [UUID: Player] {
        Dictionary(uniqueKeysWithValues: dataStore.players.map { ($0.id, $0) })
    }

    private var selectedPlayerID: UUID? {
        viewModel.selection.playerIDs.first
    }

    private var selectedPlacement: TacticalPlacement? {
        guard let selectedPlayerID else { return nil }
        return board.placements.first(where: { $0.playerID == selectedPlayerID })
    }

    private var selectedPlayer: Player? {
        guard let selectedPlayerID else { return nil }
        return playersByID[selectedPlayerID]
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                TacticsToolbarView(
                    scenarioName: scenario?.name ?? "Szenario",
                    showOpponent: scenario?.showOpponent ?? false,
                    opponentMode: board.opponentMode,
                    isDrawingMode: isDrawingMode,
                    drawingTool: drawingViewModel.selectedTool,
                    drawingIsTemporary: drawingViewModel.isTemporary,
                    showLines: scenario?.showLines ?? false,
                    showZones: scenario?.showZones ?? false,
                    drawingsVisible: scenario?.drawingsVisible ?? true,
                    playerTokenScale: playerTokenScale,
                    onNewScenario: { viewModel.createScenario(in: dataStore) },
                    onDuplicateScenario: { viewModel.duplicateScenario(in: dataStore) },
                    onRenameScenario: { viewModel.beginRenamePrompt(in: dataStore) },
                    onToggleOpponent: { viewModel.toggleShowOpponent(in: dataStore) },
                    onSetOpponentMode: { viewModel.setOpponentMode($0, in: dataStore) },
                    onToggleDrawingMode: {
                        isDrawingMode.toggle()
                        if isDrawingMode {
                            if !(scenario?.drawingsVisible ?? true) {
                                viewModel.toggleDrawingsVisible(in: dataStore)
                            }
                            viewModel.clearSelection()
                        } else {
                            drawingViewModel.cancel()
                        }
                    },
                    onSetDrawingTool: { drawingViewModel.selectedTool = $0 },
                    onSetDrawingTemporary: { drawingViewModel.isTemporary = $0 },
                    onToggleLines: { viewModel.toggleShowLines(in: dataStore) },
                    onToggleZones: { viewModel.toggleShowZones(in: dataStore) },
                    onToggleDrawingsVisible: { viewModel.toggleDrawingsVisible(in: dataStore) },
                    onAddNeutralMarker: { viewModel.addNeutralMarker(in: dataStore) },
                    onDecreasePlayerTokenSize: {
                        playerTokenScale = max(0.65, playerTokenScale - 0.1)
                    },
                    onIncreasePlayerTokenSize: {
                        playerTokenScale = min(1.3, playerTokenScale + 0.1)
                    },
                    onResetScenario: { viewModel.resetLayout(in: dataStore) }
                )

                ScenarioStripView(
                    scenarios: dataStore.tacticsScenarios,
                    activeScenarioID: viewModel.activeScenarioID,
                    onSelect: { viewModel.setScenario($0, in: dataStore) },
                    onCreate: { viewModel.createScenario(in: dataStore) },
                    onDuplicate: { scenarioID in
                        viewModel.setScenario(scenarioID, in: dataStore)
                        viewModel.duplicateScenario(in: dataStore)
                    },
                    onRename: { scenarioID in
                        viewModel.setScenario(scenarioID, in: dataStore)
                        viewModel.beginRenamePrompt(in: dataStore)
                    },
                    onDelete: { scenarioID in
                        viewModel.setScenario(scenarioID, in: dataStore)
                        viewModel.deleteScenario(in: dataStore)
                    },
                    onReset: { scenarioID in
                        viewModel.setScenario(scenarioID, in: dataStore)
                        viewModel.resetLayout(in: dataStore)
                    }
                )

                Divider()

                contentLayout(for: proxy.size)
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppTheme.background)
            .environment(\.colorScheme, .light)
        }
        .onAppear {
            viewModel.bootstrap(with: dataStore)
        }
        .onChange(of: dataStore.players) { _, _ in
            dataStore.ensureDefaultTacticsScenario()
        }
        #if os(macOS)
        .onMoveCommand { direction in
            viewModel.nudgeSelection(direction: direction, in: dataStore)
        }
        .onDeleteCommand {
            viewModel.deleteSelection(in: dataStore)
        }
        #endif
        .alert("Szenario umbenennen", isPresented: $viewModel.isRenamePromptVisible) {
            TextField("Name", text: $viewModel.renameDraft)
            Button("Abbrechen", role: .cancel) {}
            Button("Speichern") {
                viewModel.commitRename(in: dataStore)
            }
        }
        .overlay(shortcutLayer)
    }

    @ViewBuilder
    private func contentLayout(for size: CGSize) -> some View {
        let usesSplitLayout = size.width >= 980 && size.height >= 620
        if usesSplitLayout {
            HStack(spacing: 12) {
                fieldPane
                ScrollView {
                    sidePane(compact: false)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                .frame(width: min(360, max(300, size.width * 0.3)))
            }
        } else {
            VStack(spacing: 12) {
                fieldPane
                    .frame(height: min(420, max(250, size.height * 0.48)))
                ScrollView {
                    sidePane(compact: true)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
    }

    private var fieldPane: some View {
        FieldView(
            placements: board.placements,
            playersByID: playersByID,
            selectedPlayerIDs: viewModel.selection.playerIDs,
            showZones: scenario?.showZones ?? false,
            showLines: scenario?.showLines ?? false,
            showOpponent: scenario?.showOpponent ?? false,
            opponentMode: board.opponentMode,
            opponentMarkers: board.opponentMarkers,
            neutralMarkers: board.neutralMarkers,
            drawingsVisible: scenario?.drawingsVisible ?? true,
            drawings: board.drawings,
            draftDrawing: drawingViewModel.draftDrawing,
            isDrawingMode: isDrawingMode,
            playerTokenScale: playerTokenScale,
            selectedDrawingIDs: viewModel.selection.drawingIDs,
            onSelectPlayer: { playerID, additive in
                viewModel.selectPlayer(playerID, additive: additive)
            },
            onDropPlayer: { playerID, point in
                viewModel.dropPlayerOnField(playerID: playerID, at: point, in: dataStore)
            },
            onOpenProfile: { appState.openPlayerProfileWindow(playerID: $0) },
            onSendToBench: {
                viewModel.sendPlayerToBench(playerID: $0, in: dataStore)
            },
            onRemoveFromLineup: {
                viewModel.removeFromLineup(playerID: $0, in: dataStore)
            },
            onToggleExclude: {
                viewModel.toggleExcluded(playerID: $0, in: dataStore)
            },
            onUpdateRole: { id, role in
                viewModel.updateRole(playerID: id, roleName: role, in: dataStore)
            },
            onUpdateZone: { id, zone in
                viewModel.updateZone(playerID: id, zone: zone, in: dataStore)
            },
            onSelectDrawing: { id, additive in
                viewModel.selectDrawing(id, additive: additive)
            },
            onDeleteDrawing: { id in
                viewModel.deleteDrawing(id: id, in: dataStore)
            },
            onToggleTemporary: { id in
                viewModel.toggleDrawingTemporary(id: id, in: dataStore)
            },
            onPersistDrawing: { id in
                viewModel.persistTemporaryDrawing(id: id, in: dataStore)
            },
            onMoveOpponentMarker: { index, point in
                viewModel.moveOpponentMarker(at: index, to: point, in: dataStore)
            },
            onRenameOpponentMarker: { index in
                promptOpponentMarkerName(index)
            },
            onMoveNeutralMarker: { index, point in
                viewModel.moveNeutralMarker(at: index, to: point, in: dataStore)
            },
            onRenameNeutralMarker: { markerID in
                promptNeutralMarkerName(markerID)
            },
            onDeleteNeutralMarker: { markerID in
                viewModel.deleteNeutralMarker(id: markerID, in: dataStore)
            },
            onBeginDrawing: { point in
                drawingViewModel.begin(at: point)
            },
            onUpdateDrawing: { point in
                drawingViewModel.update(to: point)
            },
            onFinishDrawing: {
                if let drawing = drawingViewModel.finish() {
                    viewModel.addDrawing(drawing, in: dataStore)
                }
            },
            onClearSelection: {
                viewModel.clearSelection()
            }
        )
    }

    private func promptOpponentMarkerName(_ index: Int) {
        guard board.opponentMarkers.indices.contains(index) else { return }
        let marker = board.opponentMarkers[index]

        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = marker.name.isEmpty ? "Gegner benennen" : "Gegnernamen ändern"
        alert.informativeText = "Name für den gegnerischen Marker eingeben."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Speichern")
        alert.addButton(withTitle: "Abbrechen")

        let field = NSTextField(string: marker.name)
        field.placeholderString = "Gegnername"
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field

        if alert.runModal() == .alertFirstButtonReturn {
            viewModel.updateOpponentMarkerName(at: index, name: field.stringValue, in: dataStore)
        }
        #else
        let fallbackName = marker.name.isEmpty ? "Gegner \(index + 1)" : marker.name
        viewModel.updateOpponentMarkerName(at: index, name: fallbackName, in: dataStore)
        #endif
    }

    private func promptNeutralMarkerName(_ markerID: UUID) {
        guard let marker = board.neutralMarkers.first(where: { $0.id == markerID }) else { return }
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = marker.name.isEmpty ? "Kreis benennen" : "Kreisnamen ändern"
        alert.informativeText = "Name für den neutralen Kreis eingeben."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Speichern")
        alert.addButton(withTitle: "Abbrechen")

        let field = NSTextField(string: marker.name)
        field.placeholderString = "Kreisname"
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field

        if alert.runModal() == .alertFirstButtonReturn {
            viewModel.updateNeutralMarkerName(id: markerID, name: field.stringValue, in: dataStore)
        }
        #else
        let fallbackName = marker.name.isEmpty ? "Neutraler Kreis" : marker.name
        viewModel.updateNeutralMarkerName(id: markerID, name: fallbackName, in: dataStore)
        #endif
    }

    @ViewBuilder
    private func sidePane(compact: Bool) -> some View {
        VStack(spacing: 12) {
            BenchView(
                players: viewModel.benchPlayers(in: dataStore),
                selectedIDs: viewModel.selection.playerIDs,
                playerTokenScale: playerTokenScale,
                onSelectPlayer: { playerID, additive in
                    viewModel.selectPlayer(playerID, additive: additive)
                },
                onDropPlayerToBench: { playerID in
                    viewModel.sendPlayerToBench(playerID: playerID, in: dataStore)
                    viewModel.selectPlayer(playerID)
                },
                onOpenProfile: { appState.openPlayerProfileWindow(playerID: $0) },
                onToggleExclude: { playerID in
                    viewModel.toggleExcluded(playerID: playerID, in: dataStore)
                }
            )
            .frame(minHeight: compact ? 150 : 180, maxHeight: compact ? 220 : 260)
            .layoutPriority(1)

            if compact {
                HStack(alignment: .top, spacing: 12) {
                    if viewModel.showInspector {
                        inspectorCard
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    excludedPlayersCard
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                if viewModel.showInspector {
                    inspectorCard
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                excludedPlayersCard
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var inspectorCard: some View {
        TacticsInspectorView(
            selectedPlayer: selectedPlayer,
            selectedPlacement: selectedPlacement,
            onUpdateRole: { value in
                guard let id = selectedPlayerID else { return }
                viewModel.updateRole(playerID: id, roleName: value, in: dataStore)
            },
            onUpdateZone: { zone in
                guard let id = selectedPlayerID else { return }
                viewModel.updateZone(playerID: id, zone: zone, in: dataStore)
            },
            onSendToBench: {
                guard let id = selectedPlayerID else { return }
                viewModel.sendPlayerToBench(playerID: id, in: dataStore)
            },
            onToggleExclude: {
                guard let id = selectedPlayerID else { return }
                viewModel.toggleExcluded(playerID: id, in: dataStore)
            },
            onOpenProfile: {
                guard let id = selectedPlayerID else { return }
                appState.openPlayerProfileWindow(playerID: id)
            }
        )
    }

    private var excludedPlayersCard: some View {
        let excluded = viewModel.excludedPlayers(in: dataStore)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Ausgeblendete Spieler")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            if excluded.isEmpty {
                Text("Keine")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(excluded) { player in
                    HStack {
                        Text(player.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Button("Einblenden") {
                            viewModel.toggleExcluded(playerID: player.id, in: dataStore)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryDark)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    // Hidden keyboard shortcuts for macOS-like workflow.
    private var shortcutLayer: some View {
        HStack(spacing: 0) {
            Button("") {
                viewModel.createScenario(in: dataStore)
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("") {
                viewModel.duplicateScenario(in: dataStore)
            }
            .keyboardShortcut("d", modifiers: [.command])

            Button("") {
                viewModel.showInspector = true
            }
            .keyboardShortcut(.return, modifiers: [])

            Button("") {
                viewModel.clearSelection()
                drawingViewModel.cancel()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .hidden()
    }
}

#Preview {
    TacticsBoardView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 1100, height: 740)
}

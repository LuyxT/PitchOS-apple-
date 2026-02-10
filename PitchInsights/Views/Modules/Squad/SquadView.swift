import SwiftUI

struct SquadView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dataStore: AppDataStore

    @StateObject private var squadViewModel = SquadViewModel()
    @StateObject private var filterViewModel = SquadFilterViewModel()
    @StateObject private var analyticsViewModel = SquadAnalyticsViewModel()

    @State private var isQuickCreateShown = false
    @FocusState private var searchFocused: Bool

    private var filteredPlayers: [Player] {
        squadViewModel.apply(players: dataStore.players, filters: filterViewModel.filters)
    }

    var body: some View {
        VStack(spacing: 0) {
            SquadToolbarView(
                filterViewModel: filterViewModel,
                squadViewModel: squadViewModel,
                roleOptions: filterViewModel.availableRoles,
                groupOptions: filterViewModel.availableGroups,
                onNewPlayer: { isQuickCreateShown = true },
                searchFocus: $searchFocused
            )

            Divider()

            activeFilterChips

            HStack(alignment: .top, spacing: 14) {
                SquadTableView(
                    viewModel: squadViewModel,
                    players: filteredPlayers,
                    onOpenProfile: { player in
                        appState.openPlayerProfileWindow(playerID: player.id)
                    },
                    onDuplicate: { player in
                        Task { @MainActor in
                            dataStore.duplicatePlayer(player)
                        }
                    },
                    onDelete: { player in
                        Task { @MainActor in
                            dataStore.deletePlayer(id: player.id)
                            squadViewModel.selectedPlayerIDs.remove(player.id)
                        }
                    },
                    onSetAvailability: { ids, status in
                        Task { @MainActor in
                            dataStore.setAvailability(ids: ids, value: status)
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if filterViewModel.isAnalysisVisible {
                    SquadAnalyticsPanel(snapshot: analyticsViewModel.snapshot)
                        .frame(width: 300)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(14)
        }
        .background(AppTheme.background)
        .popover(isPresented: $isQuickCreateShown, arrowEdge: .top) {
            PlayerQuickCreatePopover { name, number, position in
                Task { @MainActor in
                    dataStore.createPlayerQuick(name: name, number: number, primaryPosition: position)
                }
            }
        }
        .onAppear {
            refreshDerivedState()
        }
        .onChange(of: dataStore.players) { _ in
            refreshDerivedState()
            squadViewModel.selectedPlayerIDs = squadViewModel.selectedPlayerIDs.intersection(Set(dataStore.players.map { $0.id }))
        }
        .onChange(of: filterViewModel.filters) { _ in
            analyticsViewModel.update(players: filteredPlayers)
        }
        #if os(macOS)
        .onMoveCommand { direction in
            squadViewModel.moveSelection(direction: direction, orderedPlayers: filteredPlayers)
        }
        .onDeleteCommand {
            Task { @MainActor in
                dataStore.deletePlayers(ids: squadViewModel.selectedPlayerIDs)
                squadViewModel.selectedPlayerIDs.removeAll()
            }
        }
        #endif
        .overlay(shortcutLayer)
    }

    private var activeFilterChips: some View {
        let chips = filterViewModel.activeChips()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(AppTheme.surfaceAlt)
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(AppTheme.surface.opacity(chips.isEmpty ? 0 : 1))
        .frame(height: chips.isEmpty ? 0 : nil)
    }

    // Hidden shortcuts keep macOS-style keyboard flow without adding custom key event handling.
    private var shortcutLayer: some View {
        HStack(spacing: 0) {
            Button("") {
                if let player = squadViewModel.selectedPlayer(from: filteredPlayers) {
                    appState.openPlayerProfileWindow(playerID: player.id)
                }
            }
            .keyboardShortcut(.return, modifiers: [])

            Button("") {
                isQuickCreateShown = true
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("") {
                searchFocused = true
            }
            .keyboardShortcut("f", modifiers: [.command])

            Button("") {
                Task { @MainActor in
                    dataStore.deletePlayers(ids: squadViewModel.selectedPlayerIDs)
                    squadViewModel.selectedPlayerIDs.removeAll()
                }
            }
            .keyboardShortcut(.delete, modifiers: [.command])
        }
        .hidden()
    }

    private func refreshDerivedState() {
        filterViewModel.refreshOptions(players: dataStore.players)
        analyticsViewModel.update(players: filteredPlayers)
    }
}

#Preview {
    SquadView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 1080, height: 720)
}

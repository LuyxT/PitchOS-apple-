import SwiftUI

struct SquadToolbarView: View {
    @ObservedObject var filterViewModel: SquadFilterViewModel
    @ObservedObject var squadViewModel: SquadViewModel
    let roleOptions: [String]
    let groupOptions: [String]
    let onNewPlayer: () -> Void
    let searchFocus: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                expandedTopRow
                compactTopRow
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    menu(title: "Position") {
                        ForEach(PlayerPosition.allCases) { position in
                            toggleMenuItem(
                                title: position.rawValue,
                                isOn: filterViewModel.filters.positions.contains(position)
                            ) {
                                filterViewModel.toggle(position)
                            }
                        }
                    }

                    menu(title: "Verfügbarkeit") {
                        ForEach(AvailabilityStatus.allCases) { state in
                            toggleMenuItem(
                                title: state.rawValue,
                                isOn: filterViewModel.filters.availability.contains(state)
                            ) {
                                filterViewModel.toggle(state)
                            }
                        }
                    }

                    menu(title: "Teamstatus") {
                        ForEach(SquadStatus.allCases) { state in
                            toggleMenuItem(
                                title: state.rawValue,
                                isOn: filterViewModel.filters.squadStatus.contains(state)
                            ) {
                                filterViewModel.toggle(state)
                            }
                        }
                    }

                    if !roleOptions.isEmpty {
                        menu(title: "Rollen") {
                            ForEach(roleOptions, id: \.self) { role in
                                toggleMenuItem(
                                    title: role,
                                    isOn: filterViewModel.filters.roles.contains(role)
                                ) {
                                    filterViewModel.toggleRole(role)
                                }
                            }
                        }
                    }

                    if !groupOptions.isEmpty {
                        menu(title: "Gruppen") {
                            ForEach(groupOptions, id: \.self) { group in
                                toggleMenuItem(
                                    title: group,
                                    isOn: filterViewModel.filters.groups.contains(group)
                                ) {
                                    filterViewModel.toggleGroup(group)
                                }
                            }
                        }
                    }

                    Menu("Sortierung") {
                        ForEach(SquadSortField.allCases) { field in
                            Button {
                                squadViewModel.toggleSort(field)
                            } label: {
                                if squadViewModel.sortField == field {
                                    Label(field.rawValue, systemImage: squadViewModel.sortAscending ? "arrow.up" : "arrow.down")
                                } else {
                                    Text(field.rawValue)
                                }
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                .frame(height: 30)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
    }

    private var expandedTopRow: some View {
        HStack(spacing: 10) {
            searchField
                .frame(minWidth: 220, maxWidth: 320)

            Spacer(minLength: 8)

            analysisToggleButton
            resetButton
            createButton
        }
    }

    private var compactTopRow: some View {
        HStack(spacing: 8) {
            searchField
                .frame(maxWidth: .infinity)

            Menu("Aktionen") {
                Button(filterViewModel.isAnalysisVisible ? "Analyse ausblenden" : "Analyse anzeigen") {
                    Haptics.trigger(.light)
                    withAnimation(AppMotion.settle) {
                        filterViewModel.isAnalysisVisible.toggle()
                    }
                }
                Button("Filter zurücksetzen") {
                    Haptics.trigger(.soft)
                    filterViewModel.reset()
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: true, vertical: false)

            createButton
        }
    }

    private var searchField: some View {
        TextField("Spieler suchen", text: $filterViewModel.filters.searchText)
            .textFieldStyle(.roundedBorder)
            .focused(searchFocus)
    }

    private var analysisToggleButton: some View {
        Button(filterViewModel.isAnalysisVisible ? "Analyse ausblenden" : "Analyse anzeigen") {
            Haptics.trigger(.light)
            withAnimation(AppMotion.settle) {
                filterViewModel.isAnalysisVisible.toggle()
            }
        }
        .buttonStyle(SecondaryActionButtonStyle())
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var resetButton: some View {
        Button("Filter zurücksetzen") {
            Haptics.trigger(.soft)
            filterViewModel.reset()
        }
        .buttonStyle(SecondaryActionButtonStyle())
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var createButton: some View {
        Button {
            Haptics.trigger(.soft)
            onNewPlayer()
        } label: {
            Label("Neuer Spieler", systemImage: "plus")
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func menu<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        Menu(title) {
            content()
        }
        .menuStyle(.borderlessButton)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func toggleMenuItem(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Haptics.trigger(.soft)
            if isOn {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}

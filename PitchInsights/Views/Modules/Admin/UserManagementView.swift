import SwiftUI

struct UserManagementView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: UserManagementViewModel

    private var persons: [AdminPerson] {
        viewModel.filteredPersons(from: dataStore.adminPersons)
    }

    private var selectedPerson: AdminPerson? {
        guard let selected = viewModel.selectedPersonID else { return nil }
        return dataStore.adminPersons.first(where: { $0.id == selected })
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Person suchen", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                Spacer()
                Button("Neu") {
                    viewModel.beginCreate(defaultTeam: dataStore.profile.team)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                Button("Bearbeiten") {
                    if let selectedPerson {
                        viewModel.beginEdit(selectedPerson)
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(selectedPerson == nil)
                Button("Löschen") {
                    Task { await viewModel.deleteSelected(store: dataStore) }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(selectedPerson == nil)
            }

            HStack(alignment: .top, spacing: 10) {
                peopleTable
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                userDetail
                    .frame(width: 280)
            }
        }
        .padding(12)
        .onAppear {
            viewModel.ensureSelection(in: persons)
        }
        .onChange(of: persons) { _, newValue in
            viewModel.ensureSelection(in: newValue)
        }
        .popover(isPresented: $viewModel.isEditorPresented, arrowEdge: .bottom) {
            UserEditorPopover(viewModel: viewModel)
                .environmentObject(dataStore)
        }
    }

    @ViewBuilder
    private var peopleTable: some View {
        #if os(macOS)
        Table(persons, selection: $viewModel.selectedPersonID) {
            TableColumn("#") { person in
                Text("\(displayNumber(for: person))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }
            .width(44)
            TableColumn("Name") { person in
                Text(person.fullName)
                    .foregroundStyle(AppTheme.textPrimary)
                    .contextMenu {
                        contextMenu(for: person)
                    }
            }
            TableColumn("Typ") { person in
                Text(person.personType.title)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Rolle") { person in
                Text(person.role?.title ?? "-")
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Team") { person in
                Text(person.teamName)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Status") { person in
                Text(person.presenceStatus.title)
                    .foregroundStyle(person.presenceStatus == .active ? AppTheme.primary : AppTheme.textSecondary)
            }
        }
        #else
        List(selection: $viewModel.selectedPersonID) {
            ForEach(persons) { person in
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.fullName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(person.personType.title) • \(person.teamName)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .contextMenu {
                    contextMenu(for: person)
                }
                .tag(person.id)
            }
        }
        #endif
    }

    private var userDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.system(size: 13, weight: .semibold))
            if let selectedPerson {
                detailRow("Name", selectedPerson.fullName)
                detailRow("E-Mail", selectedPerson.email)
                detailRow("Rolle", selectedPerson.role?.title ?? selectedPerson.personType.title)
                detailRow("Team", selectedPerson.teamName)
                detailRow("Online", selectedPerson.isOnline ? "Ja" : "Nein")
                detailRow("Gruppen", groupNames(for: selectedPerson).joined(separator: ", ").isEmpty ? "-" : groupNames(for: selectedPerson).joined(separator: ", "))

                if let linkedPlayerID = selectedPerson.linkedPlayerID {
                    Button("Spielerprofil öffnen") {
                        appState.openPlayerProfileWindow(playerID: linkedPlayerID)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            } else {
                Text("Person auswählen.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(cardBackground)
    }

    private func contextMenu(for person: AdminPerson) -> some View {
        Group {
            Button("Bearbeiten") {
                viewModel.beginEdit(person)
            }
            if let playerID = person.linkedPlayerID {
                Button("Spielerprofil öffnen") {
                    appState.openPlayerProfileWindow(playerID: playerID)
                }
            }
            Button("Löschen", role: .destructive) {
                viewModel.selectedPersonID = person.id
                Task { await viewModel.deleteSelected(store: dataStore) }
            }
        }
    }

    private func groupNames(for person: AdminPerson) -> [String] {
        dataStore.adminGroups
            .filter { person.groupIDs.contains($0.id) }
            .map(\.name)
            .sorted()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private func displayNumber(for person: AdminPerson) -> Int {
        guard let linkedPlayerID = person.linkedPlayerID,
              let player = dataStore.players.first(where: { $0.id == linkedPlayerID }) else {
            return 0
        }
        return player.number
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

private struct UserEditorPopover: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: UserManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Person bearbeiten")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            TextField("Name", text: $viewModel.draft.fullName)
                .textFieldStyle(.roundedBorder)
            TextField("E-Mail", text: $viewModel.draft.email)
                .textFieldStyle(.roundedBorder)
            Picker("Typ", selection: $viewModel.draft.personType) {
                ForEach(AdminPersonType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.draft.personType == .trainer {
                Picker("Rolle", selection: Binding(
                    get: { viewModel.draft.role ?? .coTrainer },
                    set: { viewModel.draft.role = $0 }
                )) {
                    ForEach(AdminRole.allCases) { role in
                        Text(role.title).tag(role)
                    }
                }
                .labelsHidden()

                Text("Rechte")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                FlowLayout(items: AdminPermission.allCases, spacing: 6) { permission in
                    if viewModel.draft.permissions.contains(permission) {
                        Button(permission.title) {
                            viewModel.togglePermission(permission)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    } else {
                        Button(permission.title) {
                            viewModel.togglePermission(permission)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }

            Picker("Status", selection: $viewModel.draft.presenceStatus) {
                ForEach(AdminPresenceStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            }
            .labelsHidden()

            Text("Gruppen")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(dataStore.adminGroups) { group in
                        Toggle(isOn: Binding(
                            get: { viewModel.draft.groupIDs.contains(group.id) },
                            set: { isOn in
                                if isOn {
                                    viewModel.draft.groupIDs.insert(group.id)
                                } else {
                                    viewModel.draft.groupIDs.remove(group.id)
                                }
                            }
                        )) {
                            Text(group.name)
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .adminCheckboxStyle()
                    }
                }
            }
            .frame(height: 110)

            HStack {
                Button("Abbrechen") {
                    viewModel.isEditorPresented = false
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Spacer()

                Button("Speichern") {
                    Task { await viewModel.save(store: dataStore) }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(viewModel.isSaving)
            }
        }
        .padding(14)
        .frame(width: 420)
        .background(AppTheme.surface)
    }
}

private struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let content: (Item) -> Content

    init(
        items: [Item],
        spacing: CGFloat,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            let columns = [
                GridItem(.adaptive(minimum: 120), spacing: spacing)
            ]
            LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
        }
    }
}

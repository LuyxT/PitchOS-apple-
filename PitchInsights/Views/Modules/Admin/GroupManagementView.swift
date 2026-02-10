import SwiftUI

struct GroupManagementView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: GroupManagementViewModel

    private var groups: [AdminGroup] {
        dataStore.adminGroups.sorted { $0.name < $1.name }
    }

    private var selectedGroup: AdminGroup? {
        guard let selectedGroupID = viewModel.selectedGroupID else { return nil }
        return dataStore.adminGroups.first(where: { $0.id == selectedGroupID })
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button("Neue Gruppe") {
                    viewModel.beginCreate()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                Button("Bearbeiten") {
                    if let selectedGroup {
                        viewModel.beginEdit(selectedGroup)
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(selectedGroup == nil)
                Button("Löschen") {
                    Task { await viewModel.deleteSelected(store: dataStore) }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(selectedGroup == nil)
                Spacer()
            }

            HStack(alignment: .top, spacing: 10) {
                groupTable
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                detailPanel
                    .frame(width: 320)
            }
        }
        .padding(12)
        .onAppear {
            viewModel.ensureSelection(in: groups)
        }
        .onChange(of: groups) { _, value in
            viewModel.ensureSelection(in: value)
        }
        .popover(isPresented: $viewModel.isEditorPresented) {
            GroupEditorPopover(viewModel: viewModel)
                .environmentObject(dataStore)
        }
    }

    @ViewBuilder
    private var groupTable: some View {
        #if os(macOS)
        Table(groups, selection: $viewModel.selectedGroupID) {
            TableColumn("Gruppe") { group in
                Text(group.name)
                    .foregroundStyle(AppTheme.textPrimary)
                    .contextMenu {
                        Button("Bearbeiten") { viewModel.beginEdit(group) }
                        Button("Löschen", role: .destructive) {
                            viewModel.selectedGroupID = group.id
                            Task { await viewModel.deleteSelected(store: dataStore) }
                        }
                    }
            }
            TableColumn("Typ") { group in
                Text(group.groupType.title)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Mitglieder") { group in
                Text("\(group.memberIDs.count)")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            TableColumn("Verantwortlich") { group in
                Text(personName(for: group.responsibleCoachID) ?? "-")
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        #else
        List(selection: $viewModel.selectedGroupID) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(group.groupType.title) • \(group.memberIDs.count) Mitglieder")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .tag(group.id)
                .contextMenu {
                    Button("Bearbeiten") { viewModel.beginEdit(group) }
                    Button("Löschen", role: .destructive) {
                        viewModel.selectedGroupID = group.id
                        Task { await viewModel.deleteSelected(store: dataStore) }
                    }
                }
            }
        }
        #endif
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gruppendetails")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            if let selectedGroup {
                detailRow("Name", selectedGroup.name)
                detailRow("Ziel", selectedGroup.goal.isEmpty ? "-" : selectedGroup.goal)
                detailRow("Typ", selectedGroup.groupType.title)
                detailRow("Verantwortlich", personName(for: selectedGroup.responsibleCoachID) ?? "-")
                detailRow("Co-Trainer", personName(for: selectedGroup.assistantCoachID) ?? "-")
                detailRow("Mitglieder", "\(selectedGroup.memberIDs.count)")
                if selectedGroup.groupType == .temporary {
                    if let startsAt = selectedGroup.startsAt {
                        detailRow("Start", DateFormatters.shortDate.string(from: startsAt))
                    }
                    if let endsAt = selectedGroup.endsAt {
                        detailRow("Ende", DateFormatters.shortDate.string(from: endsAt))
                    }
                }
            } else {
                Text("Gruppe auswählen.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(cardBackground)
    }

    private func personName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return dataStore.adminPersons.first(where: { $0.id == id })?.fullName
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
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

private struct GroupEditorPopover: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: GroupManagementViewModel

    private var trainers: [AdminPerson] {
        dataStore.adminPersons.filter { $0.personType == .trainer }.sorted { $0.fullName < $1.fullName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gruppe bearbeiten")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            TextField("Name", text: $viewModel.draft.name)
                .textFieldStyle(.roundedBorder)
            TextField("Ziel", text: $viewModel.draft.goal)
                .textFieldStyle(.roundedBorder)

            Picker("Typ", selection: $viewModel.draft.groupType) {
                ForEach(AdminGroupType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.draft.groupType == .temporary {
                DatePicker("Start", selection: $viewModel.draft.startsAt, displayedComponents: .date)
                DatePicker("Ende", selection: $viewModel.draft.endsAt, displayedComponents: .date)
            }

            Picker("Verantwortlicher", selection: $viewModel.draft.responsibleCoachID) {
                Text("Nicht gesetzt").tag(Optional<UUID>.none)
                ForEach(trainers) { trainer in
                    Text(trainer.fullName).tag(Optional(trainer.id))
                }
            }

            Picker("Co-Trainer", selection: $viewModel.draft.assistantCoachID) {
                Text("Nicht gesetzt").tag(Optional<UUID>.none)
                ForEach(trainers) { trainer in
                    Text(trainer.fullName).tag(Optional(trainer.id))
                }
            }

            Text("Mitglieder")
                .font(.system(size: 12, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(dataStore.adminPersons.sorted { $0.fullName < $1.fullName }) { person in
                        Toggle(isOn: Binding(
                            get: { viewModel.draft.memberIDs.contains(person.id) },
                            set: { isOn in
                                if isOn {
                                    viewModel.draft.memberIDs.insert(person.id)
                                } else {
                                    viewModel.draft.memberIDs.remove(person.id)
                                }
                            }
                        )) {
                            Text(person.fullName)
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .adminCheckboxStyle()
                    }
                }
            }
            .frame(height: 120)

            HStack {
                Button("Abbrechen") { viewModel.isEditorPresented = false }
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
        .frame(width: 440)
        .background(AppTheme.surface)
    }
}

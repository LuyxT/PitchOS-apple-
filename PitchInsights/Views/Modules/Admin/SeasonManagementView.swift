import SwiftUI

struct SeasonManagementView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: SeasonManagementViewModel

    private var seasons: [AdminSeason] {
        dataStore.adminSeasons.sorted { $0.startsAt > $1.startsAt }
    }

    private var selectedSeason: AdminSeason? {
        guard let selectedSeasonID = viewModel.selectedSeasonID else { return nil }
        return seasons.first(where: { $0.id == selectedSeasonID })
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button("Neue Saison") { viewModel.beginCreate() }
                    .buttonStyle(PrimaryActionButtonStyle())
                Button("Bearbeiten") {
                    if let selectedSeason {
                        viewModel.beginEdit(selectedSeason)
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(selectedSeason == nil)
                Button("Aktiv setzen") {
                    Task { await viewModel.setActive(store: dataStore) }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(selectedSeason == nil)
                Button("Archivieren") {
                    Task { await viewModel.archiveSelected(store: dataStore) }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(selectedSeason == nil)
                Menu("Kader übernehmen") {
                    ForEach(seasons.filter { $0.id != viewModel.selectedSeasonID }) { season in
                        Button("Aus \(season.name)") {
                            Task { await viewModel.copyRoster(from: season.id, store: dataStore) }
                        }
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(selectedSeason == nil || seasons.count < 2)
                Spacer()
            }

            seasonTable
        }
        .padding(12)
        .onAppear {
            viewModel.ensureSelection(in: seasons)
        }
        .onChange(of: seasons) { _, value in
            viewModel.ensureSelection(in: value)
        }
        .popover(isPresented: $viewModel.isEditorPresented) {
            SeasonEditorPopover(viewModel: viewModel)
                .environmentObject(dataStore)
        }
    }

    @ViewBuilder
    private var seasonTable: some View {
        #if os(macOS)
        Table(seasons, selection: $viewModel.selectedSeasonID) {
            TableColumn("Saison") { season in
                Text(season.name)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Status") { season in
                Text(season.status.title)
                    .foregroundStyle(color(for: season.status))
            }
            TableColumn("Teams") { season in
                Text("\(season.teamCount)")
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Spieler") { season in
                Text("\(season.playerCount)")
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Trainer") { season in
                Text("\(season.trainerCount)")
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Zeitraum") { season in
                Text("\(DateFormatters.shortDate.string(from: season.startsAt)) - \(DateFormatters.shortDate.string(from: season.endsAt))")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        #else
        List(selection: $viewModel.selectedSeasonID) {
            ForEach(seasons) { season in
                VStack(alignment: .leading, spacing: 2) {
                    Text(season.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(season.status.title) • \(season.playerCount) Spieler")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .tag(season.id)
            }
        }
        #endif
    }

    private func color(for status: AdminSeasonStatus) -> Color {
        switch status {
        case .active:
            return AppTheme.primary
        case .locked:
            return .orange
        case .archived:
            return AppTheme.textSecondary
        }
    }
}

private struct SeasonEditorPopover: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: SeasonManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saison bearbeiten")
                .font(.system(size: 14, weight: .semibold))
            TextField("Saisonname", text: $viewModel.draft.name)
                .textFieldStyle(.roundedBorder)
            DatePicker("Start", selection: $viewModel.draft.startsAt, displayedComponents: .date)
            DatePicker("Ende", selection: $viewModel.draft.endsAt, displayedComponents: .date)
            Picker("Status", selection: $viewModel.draft.status) {
                ForEach(AdminSeasonStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            }

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
        .frame(width: 360)
        .background(AppTheme.surface)
    }
}


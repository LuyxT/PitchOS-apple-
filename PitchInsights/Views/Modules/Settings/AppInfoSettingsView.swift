import SwiftUI

struct AppInfoSettingsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: AppInfoSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryCard
            changelogCard
        }
        .onAppear {
            viewModel.load(store: dataStore)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("App-Information")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black)
                Spacer()
                Button("Aktualisieren") {
                    Task { await viewModel.refresh(store: dataStore) }
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            infoRow(title: "Version", value: viewModel.state.version)
            infoRow(title: "Build", value: viewModel.state.buildNumber)
            infoRow(title: "Letztes Update", value: viewModel.state.lastUpdateAt.formatted(date: .abbreviated, time: .shortened))
            infoRow(title: "Update-Status", value: viewModel.state.updateState.title)
        }
        .padding(12)
        .background(cardBackground)
    }

    private var changelogCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Changelog")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)
            ForEach(viewModel.state.changelog.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(AppTheme.primaryDark)
                    Text(viewModel.state.changelog[index])
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.72))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black)
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

import SwiftUI

struct DisplaySettingsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: DisplaySettingsViewModel
    let focus: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if focus == .languageRegion {
                languageRegionCard
            } else if focus == .displayBehavior {
                displayBehaviorCard
            }

            HStack {
                Spacer()
                Button {
                    Task { await viewModel.save(store: dataStore) }
                } label: {
                    Label("Einstellungen speichern", systemImage: "checkmark")
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(viewModel.isSaving)
            }
        }
        .onAppear {
            viewModel.load(store: dataStore)
        }
    }

    private var languageRegionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: "Sprache & Region", subtitle: "Darstellung von Datum, Zeit und Maßeinheiten")

            HStack(spacing: 10) {
                labeledPicker(
                    "Sprache",
                    selection: $viewModel.draft.language,
                    values: AppLanguage.allCases
                ) { $0.title }

                labeledPicker(
                    "Region",
                    selection: $viewModel.draft.region,
                    values: AppRegionFormat.allCases
                ) { $0.title }

                labeledPicker(
                    "Einheitensystem",
                    selection: $viewModel.draft.unitSystem,
                    values: AppUnitSystem.allCases
                ) { $0.title }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Zeitzone")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black)
                Picker("Zeitzone", selection: $viewModel.draft.timeZoneID) {
                    ForEach(viewModel.timeZoneIDs, id: \.self) { zoneID in
                        Text(zoneID).tag(zoneID)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var displayBehaviorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(title: "Darstellung & Verhalten", subtitle: "Nur app-interne Darstellung wird geändert")

            HStack(spacing: 10) {
                labeledPicker(
                    "Darstellungsmodus",
                    selection: $viewModel.draft.appearanceMode,
                    values: AppAppearanceMode.allCases
                ) { $0.title }

                labeledPicker(
                    "Kontrast",
                    selection: $viewModel.draft.contrastMode,
                    values: AppContrastMode.allCases
                ) { $0.title }

                labeledPicker(
                    "UI-Skalierung",
                    selection: $viewModel.draft.uiScale,
                    values: AppUIScale.allCases
                ) { $0.title }
            }

            Toggle("Reduzierte Animationen", isOn: $viewModel.draft.reduceAnimations)
                .toggleStyle(.switch)
                .foregroundStyle(Color.black)

            Toggle("Interaktive Vorschauen", isOn: $viewModel.draft.interactivePreviews)
                .toggleStyle(.switch)
                .foregroundStyle(Color.black)
        }
        .padding(12)
        .background(cardBackground)
    }

    private func cardHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.62))
        }
    }

    private func labeledPicker<Value: Hashable, Source: RandomAccessCollection>(
        _ title: String,
        selection: Binding<Value>,
        values: Source,
        text: @escaping (Source.Element) -> String
    ) -> some View where Source.Element == Value {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black)
            Picker(title, selection: selection) {
                ForEach(Array(values), id: \.self) { item in
                    Text(text(item)).tag(item)
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity, alignment: .leading)
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

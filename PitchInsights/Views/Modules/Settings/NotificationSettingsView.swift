import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: NotificationSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerCard
            moduleListCard
            HStack {
                Spacer()
                Button {
                    Task { await viewModel.save(store: dataStore) }
                } label: {
                    Label("Benachrichtigungen speichern", systemImage: "bell.badge")
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Benachrichtigungen")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)
            Text("Modulbezogene Zustellung für Push, In-App und E-Mail")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.62))
            Toggle("Benachrichtigungen global aktiv", isOn: $viewModel.draft.globalEnabled)
                .toggleStyle(.switch)
                .foregroundStyle(Color.black)
        }
        .padding(12)
        .background(cardBackground)
    }

    private var moduleListCard: some View {
        VStack(spacing: 0) {
            ForEach(NotificationModuleKey.allCases) { module in
                if let setting = viewModel.bindingForModule(module) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(module.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.black)
                            Text(module.subtitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.58))
                        }

                        Spacer()

                        Toggle("Push", isOn: Binding(
                            get: { setting.channels.push },
                            set: { viewModel.setPush($0, module: module) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .disabled(!viewModel.draft.globalEnabled)

                        Text("Push")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.black)

                        Toggle("In-App", isOn: Binding(
                            get: { setting.channels.inApp },
                            set: { viewModel.setInApp($0, module: module) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .disabled(!viewModel.draft.globalEnabled)

                        Text("In-App")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.black)

                        Toggle("E-Mail", isOn: Binding(
                            get: { setting.channels.email },
                            set: { viewModel.setEmail($0, module: module) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .disabled(!viewModel.draft.globalEnabled)

                        Text("E-Mail")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.black)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }

                if module != NotificationModuleKey.allCases.last {
                    Divider()
                }
            }
        }
        .background(cardBackground)
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

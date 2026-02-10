import SwiftUI

struct RoleManagementView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: RoleManagementViewModel

    private var trainers: [AdminPerson] {
        viewModel.trainerPersons(from: dataStore.adminPersons)
    }

    private var selectedTrainer: AdminPerson? {
        guard let selected = viewModel.selectedPersonID else { return nil }
        return trainers.first(where: { $0.id == selected })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            trainerTable
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            permissionEditor
                .frame(width: 380)
        }
        .padding(12)
        .onAppear {
            viewModel.ensureSelection(in: trainers)
        }
        .onChange(of: trainers) { _, value in
            viewModel.ensureSelection(in: value)
        }
    }

    @ViewBuilder
    private var trainerTable: some View {
        #if os(macOS)
        Table(trainers, selection: $viewModel.selectedPersonID) {
            TableColumn("Name") { trainer in
                Text(trainer.fullName)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Rolle") { trainer in
                Text(trainer.role?.title ?? "-")
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Rechte") { trainer in
                Text("\(trainer.permissions.count)")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            TableColumn("Team") { trainer in
                Text(trainer.teamName)
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        #else
        List(selection: $viewModel.selectedPersonID) {
            ForEach(trainers) { trainer in
                VStack(alignment: .leading, spacing: 2) {
                    Text(trainer.fullName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(trainer.role?.title ?? "Trainer") • \(trainer.permissions.count) Rechte")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .tag(trainer.id)
            }
        }
        #endif
    }

    private var permissionEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rollen & Rechte")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            if let selectedTrainer {
                Picker("Rolle", selection: Binding(
                    get: { selectedTrainer.role ?? .coTrainer },
                    set: { role in
                        Task { await viewModel.setRole(role, for: selectedTrainer, store: dataStore) }
                    }
                )) {
                    ForEach(AdminRole.allCases) { role in
                        Text(role.title).tag(role)
                    }
                }
                .labelsHidden()

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(AdminPermission.allCases) { permission in
                            HStack {
                                Text(permission.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { selectedTrainer.permissions.contains(permission) },
                                        set: { _ in
                                            Task {
                                                await viewModel.togglePermission(permission, for: selectedTrainer, store: dataStore)
                                            }
                                        }
                                    )
                                )
                                .labelsHidden()
                                .toggleStyle(.switch)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else {
                Text("Trainer auswählen.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }
}


import SwiftUI

struct AuditLogView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: AuditLogViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Person oder Ziel", text: $viewModel.filter.personName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)
                Picker("Bereich", selection: $viewModel.filter.area) {
                    Text("Alle").tag(Optional<AdminAuditArea>.none)
                    ForEach(AdminAuditArea.allCases) { area in
                        Text(area.title).tag(Optional(area))
                    }
                }
                .frame(width: 220)
                DatePicker(
                    "Von",
                    selection: Binding(
                        get: { viewModel.filter.from ?? Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() },
                        set: { viewModel.filter.from = $0 }
                    ),
                    displayedComponents: .date
                )
                .frame(width: 160)
                DatePicker(
                    "Bis",
                    selection: Binding(
                        get: { viewModel.filter.to ?? Date() },
                        set: { viewModel.filter.to = $0 }
                    ),
                    displayedComponents: .date
                )
                .frame(width: 160)
                Button("Filter anwenden") {
                    Task { await viewModel.apply(store: dataStore) }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                Spacer()
            }

            auditTable
        }
        .padding(12)
    }

    @ViewBuilder
    private var auditTable: some View {
        #if os(macOS)
        Table(dataStore.adminAuditEntries.sorted { $0.timestamp > $1.timestamp }) {
            TableColumn("Zeit") { entry in
                Text(DateFormatters.shortDate.string(from: entry.timestamp) + " " + DateFormatters.dayTime.string(from: entry.timestamp))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            TableColumn("Bereich") { entry in
                Text(entry.area.title)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Aktion") { entry in
                Text(entry.action)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Ausgeführt von") { entry in
                Text(entry.actorName)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Ziel") { entry in
                Text(entry.targetName)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Details") { entry in
                Text(entry.details)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        #else
        List {
            ForEach(dataStore.adminAuditEntries.sorted { $0.timestamp > $1.timestamp }) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.action)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(entry.actorName) → \(entry.targetName)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        #endif
    }
}


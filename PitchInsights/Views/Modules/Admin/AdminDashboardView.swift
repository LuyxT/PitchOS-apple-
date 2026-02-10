import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: AdminDashboardViewModel

    var onOpenInvitations: () -> Void
    var onOpenRights: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                metricsRow
                HStack(alignment: .top, spacing: 12) {
                    openInvitationsCard
                    rightsAlertsCard
                }
                recentAuditCard
            }
            .padding(12)
        }
        .onAppear {
            viewModel.refresh(store: dataStore)
        }
        .onChange(of: dataStore.adminPersons) { _, _ in
            viewModel.refresh(store: dataStore)
        }
        .onChange(of: dataStore.adminInvitations) { _, _ in
            viewModel.refresh(store: dataStore)
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            metricTile(title: "Personen", value: "\(viewModel.metrics.totalPersons)")
            metricTile(title: "Trainer aktiv", value: "\(viewModel.metrics.activeTrainers)")
            metricTile(title: "Spieler aktiv", value: "\(viewModel.metrics.activePlayers)")
            metricTile(title: "Offene Einladungen", value: "\(viewModel.metrics.openInvitations)")
            metricTile(title: "Rechte-Alarme", value: "\(viewModel.metrics.rightsAlerts)")
            metricTile(title: "Gruppen", value: "\(viewModel.metrics.activeGroups)")
        }
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(cardBackground)
    }

    private var openInvitationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Offene Einladungen")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Verwalten", action: onOpenInvitations)
                    .buttonStyle(SecondaryActionButtonStyle())
            }
            if viewModel.openInvitations.isEmpty {
                Text("Keine offenen Einladungen.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(viewModel.openInvitations.prefix(6)) { invitation in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(invitation.recipientName)
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(invitation.role.title) • \(invitation.teamName)")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Text(DateFormatters.shortDate.string(from: invitation.expiresAt))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    if invitation.id != viewModel.openInvitations.prefix(6).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var rightsAlertsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rechte-Alarm")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Rechte öffnen", action: onOpenRights)
                    .buttonStyle(SecondaryActionButtonStyle())
            }
            if viewModel.rightsAlerts.isEmpty {
                Text("Keine fehlenden Trainer-Rechte.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(viewModel.rightsAlerts.prefix(6)) { person in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.fullName)
                                .font(.system(size: 12, weight: .semibold))
                            Text(person.role?.title ?? "Trainer")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Text("Keine Rechte")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                    if person.id != viewModel.rightsAlerts.prefix(6).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var recentAuditCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Letzte Änderungen")
                .font(.system(size: 13, weight: .semibold))
            if dataStore.adminAuditEntries.isEmpty {
                Text("Noch keine Protokolleinträge.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(dataStore.adminAuditEntries.prefix(8)) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.action)
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(entry.actorName) → \(entry.targetName)")
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Text(DateFormatters.dayTime.string(from: entry.timestamp))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    if entry.id != dataStore.adminAuditEntries.prefix(8).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(12)
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


import SwiftUI
import Combine

struct HomeWidgetCardView: View {
    @EnvironmentObject private var dataStore: AppDataStore

    let module: Module
    let size: DesktopWidgetSize
    var isPreview: Bool = false

    @State private var displayedSnapshot: HomeWidgetSnapshot = .placeholder

    private var snapshot: HomeWidgetSnapshot {
        HomeWidgetSnapshotFactory.snapshot(for: module, store: dataStore)
    }

    var body: some View {
        let current = displayedSnapshot
        VStack(alignment: .leading, spacing: 10) {
            header
            switch size {
            case .small:
                smallBody(snapshot: current)
            case .medium:
                mediumBody(snapshot: current)
            case .large:
                largeBody(snapshot: current)
            }
        }
        .padding(12)
        .frame(width: size.dimensions.width, height: size.dimensions.height, alignment: .topLeading)
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.surface.opacity(isPreview ? 0.94 : 0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow.opacity(isPreview ? 0.2 : 0.12), radius: isPreview ? 8 : 6, x: 0, y: 4)
        .onAppear {
            displayedSnapshot = snapshot
        }
        .onReceive(
            dataStore.objectWillChange
                .debounce(for: .milliseconds(280), scheduler: RunLoop.main)
        ) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                displayedSnapshot = snapshot
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: module.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(AppTheme.hover)
                )
            Text(module.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.82)
                .layoutPriority(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private func smallBody(snapshot: HomeWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            Text(snapshot.primaryValue)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(snapshot.secondaryValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.86)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .clipped()
    }

    private func mediumBody(snapshot: HomeWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(snapshot.primaryValue)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(snapshot.secondaryValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.86)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(snapshot.lines.prefix(3), id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.86)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private func largeBody(snapshot: HomeWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(snapshot.primaryValue)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(snapshot.secondaryValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.86)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(snapshot.trend.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppTheme.primary.opacity(0.85))
                        .frame(width: 10, height: max(8, value))
                }
                Spacer(minLength: 0)
            }
            .frame(height: 56)
            .padding(.horizontal, 2)

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                ForEach(snapshot.lines.prefix(5), id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.86)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }
}

struct HomeWidgetSnapshot: Equatable {
    let primaryValue: String
    let secondaryValue: String
    let lines: [String]
    let trend: [CGFloat]

    static let placeholder = HomeWidgetSnapshot(
        primaryValue: "0",
        secondaryValue: "",
        lines: [],
        trend: [8, 8, 8, 8, 8, 8, 8]
    )
}

enum HomeWidgetSnapshotFactory {
    static func snapshot(for module: Module, store: AppDataStore) -> HomeWidgetSnapshot {
        switch module {
        case .trainerProfil:
            let profilesCount = max(store.personProfiles.count, 0)
            let active = store.personProfiles.filter { $0.core.isActive }.count
            let roles = Set(store.personProfiles.flatMap { $0.core.roles }).count
            return HomeWidgetSnapshot(
                primaryValue: "\(profilesCount)",
                secondaryValue: "Profile im Verein",
                lines: [
                    "Aktiv: \(active)",
                    "Rollen: \(roles)",
                    "Notizen gesamt: \(store.personProfiles.reduce(0) { $0 + max(0, $1.core.internalNotes.count) })"
                ],
                trend: [22, 26, 24, 28, 30, 32, 29]
            )

        case .kader:
            let fit = store.players.filter { $0.status == .fit }.count
            let limited = store.players.filter { $0.status == .limited }.count
            let unavailable = store.players.filter { $0.status == .unavailable }.count
            return HomeWidgetSnapshot(
                primaryValue: "\(store.players.count)",
                secondaryValue: "Spieler im Kader",
                lines: [
                    "Fit: \(fit)",
                    "Angeschlagen: \(limited)",
                    "Nicht verfügbar: \(unavailable)"
                ],
                trend: [20, 24, 26, 22, 28, 30, 32]
            )

        case .kalender:
            let now = Date()
            let nextSevenDays = now.addingTimeInterval(7 * 24 * 3600)
            let upcoming = store.calendarEvents
                .filter { $0.startDate >= now && $0.startDate <= nextSevenDays }
                .sorted { $0.startDate < $1.startDate }
            let nextTitle = upcoming.first?.title ?? "Keine Termine"
            return HomeWidgetSnapshot(
                primaryValue: "\(upcoming.count)",
                secondaryValue: "Termine in 7 Tagen",
                lines: [
                    "Nächster Termin: \(nextTitle)",
                    "Kategorien: \(store.calendarCategories.count)",
                    "Heute gesamt: \(store.calendarEvents.filter { Calendar.current.isDateInToday($0.startDate) }.count)"
                ],
                trend: [18, 20, 24, 16, 22, 26, 21]
            )

        case .trainingsplanung:
            let open = store.trainingPlans.filter { $0.status != .completed }.count
            let templates = store.trainingTemplates.count
            let live = store.trainingPlans.filter { $0.status == .live }.count
            return HomeWidgetSnapshot(
                primaryValue: "\(store.trainingPlans.count)",
                secondaryValue: "Trainingspläne",
                lines: [
                    "Aktiv: \(open)",
                    "Live: \(live)",
                    "Vorlagen: \(templates)"
                ],
                trend: [14, 18, 17, 20, 23, 22, 24]
            )

        case .spielanalyse:
            return HomeWidgetSnapshot(
                primaryValue: "\(store.analysisSessions.count)",
                secondaryValue: "Analysen",
                lines: [
                    "Marker: \(store.analysisMarkers.count)",
                    "Clips: \(store.analysisClips.count)",
                    "Videos: \(store.analysisVideoAssets.count)"
                ],
                trend: [16, 18, 15, 21, 25, 23, 27]
            )

        case .taktiktafel:
            let activeState = store.activeTacticsScenarioID.flatMap { store.tacticsBoardStates[$0] }
            let placements = activeState?.placements.count ?? 0
            return HomeWidgetSnapshot(
                primaryValue: "\(store.tacticsScenarios.count)",
                secondaryValue: "Szenarien",
                lines: [
                    "Aufstellung: \(placements)",
                    "Bank: \(activeState?.benchPlayerIDs.count ?? 0)",
                    "Zeichnungen: \(activeState?.drawings.count ?? 0)"
                ],
                trend: [12, 13, 15, 17, 16, 19, 21]
            )

        case .messenger:
            let unread = store.messengerChats.reduce(0) { $0 + $1.unreadCount }
            let archived = store.messengerArchivedChats.count
            return HomeWidgetSnapshot(
                primaryValue: "\(unread)",
                secondaryValue: "Ungelesene Nachrichten",
                lines: [
                    "Chats aktiv: \(store.messengerChats.count)",
                    "Archiviert: \(archived)",
                    "Outbox: \(store.messengerOutboxCount)"
                ],
                trend: [8, 10, 9, 14, 11, 13, 15]
            )

        case .dateien:
            let usedGB = Double(store.cloudUsage.usedBytes) / 1_073_741_824
            let quotaGB = Double(store.cloudUsage.quotaBytes) / 1_073_741_824
            return HomeWidgetSnapshot(
                primaryValue: String(format: "%.1f / %.1f GB", usedGB, quotaGB),
                secondaryValue: "Cloudspeicher",
                lines: [
                    "Dateien: \(store.cloudFiles.count)",
                    "Uploads aktiv: \(store.cloudUploads.filter { $0.state != .failed }.count)",
                    "Papierkorb: \(store.cloudFiles.filter { $0.deletedAt != nil }.count)"
                ],
                trend: [12, 13, 14, 16, 17, 19, 21]
            )

        case .verwaltung:
            let openInvitations = store.adminInvitations.filter { $0.status == .open }.count
            return HomeWidgetSnapshot(
                primaryValue: "\(store.adminPersons.count)",
                secondaryValue: "Personen verwaltet",
                lines: [
                    "Gruppen: \(store.adminGroups.count)",
                    "Einladungen offen: \(openInvitations)",
                    "Audit-Einträge: \(store.adminAuditEntries.count)"
                ],
                trend: [10, 12, 11, 13, 16, 15, 17]
            )

        case .mannschaftskasse:
            let balance = store.cashTransactions.reduce(0.0) { partial, tx in
                partial + (tx.type == .income ? tx.amount : -tx.amount)
            }
            let openPayments = store.cashMonthlyContributions.filter { $0.status != .paid }.count
            return HomeWidgetSnapshot(
                primaryValue: CurrencyFormatter.compact.string(from: NSNumber(value: balance)) ?? "\(balance)",
                secondaryValue: "Kontostand",
                lines: [
                    "Buchungen: \(store.cashTransactions.count)",
                    "Offene Zahlungen: \(openPayments)",
                    "Ziele: \(store.cashGoals.count)"
                ],
                trend: [20, 21, 18, 24, 26, 25, 28]
            )

        case .einstellungen:
            return HomeWidgetSnapshot(
                primaryValue: store.settingsPresentation.appearanceMode.title,
                secondaryValue: "Darstellung",
                lines: [
                    "Sprache: \(store.settingsPresentation.language.title)",
                    "UI-Skalierung: \(store.settingsPresentation.uiScale.title)",
                    "Animationen reduziert: \(store.settingsPresentation.reduceAnimations ? "Ja" : "Nein")"
                ],
                trend: [14, 14, 16, 16, 18, 17, 18]
            )
        }
    }
}

private enum CurrencyFormatter {
    static let compact: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

#Preview {
    HomeWidgetCardView(module: .kalender, size: .medium)
        .environmentObject(AppDataStore())
        .padding()
        .frame(width: 460, height: 220)
}

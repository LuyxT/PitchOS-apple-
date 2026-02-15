import SwiftUI

struct PhoneRootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var session: AppSessionStore

    @State private var selectedTabID: String = PhoneTabID.dashboard.rawValue
    @State private var sheetDestination: PhoneSheetDestination?

    private var availableModules: Set<Module> {
        Set(ModuleRegistry.modules(for: .iphoneMobile))
    }

    private var hasCalendar: Bool { availableModules.contains(.kalender) }
    private var hasMessenger: Bool { availableModules.contains(.messenger) }
    private var hasProfile: Bool { availableModules.contains(.trainerProfil) }
    private var hasSquad: Bool { availableModules.contains(.kader) }

    var body: some View {
        TabView(selection: $selectedTabID) {
            NavigationStack {
                PhoneDashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "square.grid.2x2")
            }
            .tag(PhoneTabID.dashboard.rawValue)

            if hasCalendar {
                PhoneModuleTabView(module: .kalender)
                    .tabItem {
                        Label("Kalender", systemImage: ModuleRegistry.definition(for: .kalender).iconName)
                    }
                    .tag(PhoneTabID.calendar.rawValue)
            }

            if hasMessenger {
                PhoneModuleTabView(module: .messenger)
                    .tabItem {
                        Label("Messenger", systemImage: ModuleRegistry.definition(for: .messenger).iconName)
                    }
                    .tag(PhoneTabID.messenger.rawValue)
            }

            if hasProfile {
                NavigationStack {
                    PhoneProfileView()
                }
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
                .tag(PhoneTabID.profile.rawValue)
            }

            if hasSquad {
                NavigationStack {
                    PhoneSquadView()
                }
                .tabItem {
                    Label("Kader", systemImage: ModuleRegistry.definition(for: .kader).iconName)
                }
                .tag(PhoneTabID.squad.rawValue)
            }
        }
        .tint(AppTheme.primary)
        .background(AppTheme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: selectedTabID)
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case .playerProfile(let id):
                NavigationStack {
                    PhonePlayerCardView(playerID: id)
                        .navigationTitle("Spieler")
                }
            }
        }
        .onAppear {
            normalizeSelectedTab()
        }
        .onChange(of: appState.activeModule) { _, newValue in
            if let tab = PhoneTabID(module: newValue), isAvailable(tab: tab) {
                selectedTabID = tab.rawValue
            }
        }
        .onChange(of: appState.floatingWindows) { _, windows in
            handleFloatingWindowRequests(windows)
        }
    }

    private func isAvailable(tab: PhoneTabID) -> Bool {
        switch tab {
        case .dashboard:
            return true
        case .calendar:
            return hasCalendar
        case .messenger:
            return hasMessenger
        case .profile:
            return hasProfile
        case .squad:
            return hasSquad
        }
    }

    private func normalizeSelectedTab() {
        guard !isAvailable(tab: PhoneTabID(rawValue: selectedTabID) ?? .dashboard) else { return }
        if hasCalendar {
            selectedTabID = PhoneTabID.calendar.rawValue
            return
        }
        if hasMessenger {
            selectedTabID = PhoneTabID.messenger.rawValue
            return
        }
        if hasProfile {
            selectedTabID = PhoneTabID.profile.rawValue
            return
        }
        if hasSquad {
            selectedTabID = PhoneTabID.squad.rawValue
            return
        }
        selectedTabID = PhoneTabID.dashboard.rawValue
    }

    private func handleFloatingWindowRequests(_ windows: [FloatingWindowState]) {
        guard let latest = windows.last else { return }

        switch latest.kind {
        case .module(let module):
            if let tab = PhoneTabID(module: module), isAvailable(tab: tab) {
                selectedTabID = tab.rawValue
                appState.setActive(module)
            }
        case .folder:
            break
        case .playerProfile(let id):
            sheetDestination = .playerProfile(id)
        }

        appState.closeFloatingWindow(latest.id)
    }
}

private enum PhoneTabID: String {
    case dashboard
    case calendar
    case messenger
    case profile
    case squad

    init?(module: Module) {
        switch module {
        case .kalender:
            self = .calendar
        case .messenger:
            self = .messenger
        case .trainerProfil:
            self = .profile
        case .kader:
            self = .squad
        default:
            return nil
        }
    }
}

private enum PhoneSheetDestination: Identifiable {
    case playerProfile(UUID)

    var id: String {
        switch self {
        case .playerProfile(let id):
            return "player.\(id.uuidString)"
        }
    }
}

private struct PhoneDashboardView: View {
    @EnvironmentObject private var dataStore: AppDataStore

    private var balance: Double {
        dataStore.cashTransactions.reduce(0.0) { partial, tx in
            partial + (tx.type == .income ? tx.amount : -tx.amount)
        }
    }

    private let dashboardModules: [Module] = [.kalender, .messenger, .kader, .trainerProfil]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Heute")
                    .font(.system(size: 22, weight: .bold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    PhoneMetricCard(title: "Termine", value: "\(dataStore.calendarEvents.count)", icon: "calendar")
                    PhoneMetricCard(title: "Kader", value: "\(dataStore.players.count)", icon: "person.3")
                    PhoneMetricCard(title: "Ungelesen", value: "\(dataStore.messengerChats.reduce(0) { $0 + $1.unreadCount })", icon: "bubble.left.and.bubble.right")
                    PhoneMetricCard(title: "Kasse", value: CurrencyFormatter.compact.string(from: NSNumber(value: balance)) ?? "0 €", icon: "banknote")
                }

                Text("Schnellüberblick")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.top, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(dashboardModules.filter { ModuleRegistry.modules(for: .iphoneMobile).contains($0) }) { module in
                            HomeWidgetCardView(module: module, size: .small)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.background)
        .navigationTitle("Dashboard")
    }
}

private struct PhoneMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct PhoneModuleTabView: View {
    let module: Module

    var body: some View {
        NavigationStack {
            ScrollView {
                ModuleRegistry.makeView(for: module)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(AppTheme.background)
            .navigationTitle(ModuleRegistry.definition(for: module).title)
        }
    }
}

private struct PhoneProfileView: View {
    @EnvironmentObject private var session: AppSessionStore

    private var fullName: String {
        let first = session.authUser?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let last = session.authUser?.lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let merged = "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
        return merged.isEmpty ? "Profil" : merged
    }

    var body: some View {
        List {
            Section("Benutzer") {
                LabeledContent("Name", value: fullName)
                LabeledContent("E-Mail", value: session.authUser?.email ?? "-")
                LabeledContent("Rolle", value: session.authUser?.role ?? "-")
            }

            Section("Verein") {
                LabeledContent("Club ID", value: session.authUser?.clubId ?? "-")
                LabeledContent("Team ID", value: session.authUser?.teamId ?? "-")
            }
        }
        .navigationTitle("Profil")
    }
}

private struct PhoneSquadView: View {
    @EnvironmentObject private var dataStore: AppDataStore

    var body: some View {
        List(dataStore.players) { player in
            NavigationLink {
                PhonePlayerCardView(playerID: player.id)
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(.system(size: 15, weight: .semibold))
                        Text("#\(player.number) • \(player.primaryPosition.rawValue)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text(player.status.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Kader")
    }
}

private struct PhonePlayerCardView: View {
    @EnvironmentObject private var dataStore: AppDataStore

    let playerID: UUID

    private var player: Player? {
        dataStore.player(with: playerID)
    }

    var body: some View {
        Group {
            if let player {
                List {
                    Section("Basis") {
                        LabeledContent("Name", value: player.name)
                        LabeledContent("Nummer", value: "#\(player.number)")
                        LabeledContent("Position", value: player.primaryPosition.displayName)
                        LabeledContent("Status", value: player.availability.rawValue)
                    }

                    Section("Team") {
                        LabeledContent("Team", value: player.teamName)
                        LabeledContent("Kaderstatus", value: player.squadStatus.rawValue)
                    }
                }
            } else {
                ContentUnavailableView("Spieler nicht gefunden", systemImage: "person.crop.circle.badge.xmark")
            }
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
    PhoneRootView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .environmentObject(AppSessionStore())
}

import SwiftUI

struct CashWorkspaceView: View {
    @EnvironmentObject private var dataStore: AppDataStore

    @StateObject private var workspaceViewModel = CashWorkspaceViewModel()
    @StateObject private var dashboardViewModel = CashDashboardViewModel()
    @StateObject private var listViewModel = CashTransactionListViewModel()
    @StateObject private var paymentsViewModel = CashPlayerPaymentsViewModel()
    @StateObject private var detailViewModel = CashTransactionDetailViewModel(
        draft: CashTransactionDraft(
            amount: 0,
            date: Date(),
            categoryID: UUID(),
            description: "",
            type: .income,
            playerID: nil,
            responsibleTrainerID: nil,
            comment: "",
            paymentStatus: .paid,
            contextLabel: nil
        )
    )

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            sectionPicker
            if workspaceViewModel.selectedSection == .transactions {
                transactionFilterBar
            }
            Divider()
            content
            statusFooter
        }
        .background(AppTheme.background)
        .environment(\.colorScheme, .light)
        .sheet(isPresented: $workspaceViewModel.isTransactionEditorPresented) {
            CashTransactionDetailView(
                viewModel: detailViewModel,
                categories: dataStore.cashCategories,
                players: dataStore.players,
                trainers: dataStore.adminPersons.filter { $0.personType == .trainer },
                onCancel: {
                    workspaceViewModel.isTransactionEditorPresented = false
                },
                onSave: {
                    workspaceViewModel.transactionDraft = detailViewModel.localDraft
                    Task { await workspaceViewModel.saveTransaction(store: dataStore) }
                }
            )
            .frame(minWidth: 460, minHeight: 560)
        }
        .sheet(isPresented: $workspaceViewModel.isGoalEditorPresented) {
            goalEditorSheet
                .frame(minWidth: 420, minHeight: 340)
        }
        .task {
            await workspaceViewModel.bootstrap(store: dataStore)
            detailViewModel.sync(with: workspaceViewModel.transactionDraft)
        }
        .onChange(of: workspaceViewModel.transactionDraft) { _, draft in
            detailViewModel.sync(with: draft)
        }
        .onReceive(NotificationCenter.default.publisher(for: .cashCommandCreateTransaction)) { _ in
            guard dataStore.cashAccessContext.canManageTransactions else { return }
            workspaceViewModel.presentCreateTransaction(store: dataStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: .cashCommandRefresh)) { _ in
            Task { await workspaceViewModel.bootstrap(store: dataStore) }
        }
    }

    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            expandedToolbar
            compactToolbar
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
    }

    private var expandedToolbar: some View {
        HStack(spacing: 10) {
            directActionButtons
            Spacer(minLength: 8)
            connectionBadge
        }
    }

    private var compactToolbar: some View {
        HStack(spacing: 8) {
            if dataStore.cashAccessContext.canManageTransactions {
                Button {
                    workspaceViewModel.presentCreateTransaction(store: dataStore)
                } label: {
                    Label("Buchung", systemImage: "plus")
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .keyboardShortcut("n", modifiers: [.command])
            }

            Menu("Aktionen") {
                if dataStore.cashAccessContext.permissions.contains(.manageGoals) {
                    Button("Ziel hinzufügen") {
                        workspaceViewModel.presentCreateGoal()
                    }
                }
                if dataStore.cashAccessContext.permissions.contains(.manageContributions) {
                    Button("Monatsbeiträge erzeugen") {
                        Task { await paymentsViewModel.generateCurrentMonthContributions(store: dataStore, amount: 35) }
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 8)
            connectionBadge
        }
    }

    @ViewBuilder
    private var directActionButtons: some View {
        if dataStore.cashAccessContext.canManageTransactions {
            Button {
                workspaceViewModel.presentCreateTransaction(store: dataStore)
            } label: {
                Label("Buchung", systemImage: "plus")
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .keyboardShortcut("n", modifiers: [.command])
        }

        if dataStore.cashAccessContext.permissions.contains(.manageGoals) {
            Button {
                workspaceViewModel.presentCreateGoal()
            } label: {
                Label("Ziel", systemImage: "flag")
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }

        if dataStore.cashAccessContext.permissions.contains(.manageContributions) {
            Button {
                Task { await paymentsViewModel.generateCurrentMonthContributions(store: dataStore, amount: 35) }
            } label: {
                Label("Monatsbeiträge", systemImage: "calendar.badge.plus")
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private var connectionBadge: some View {
        Text(connectionLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(connectionColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(connectionColor.opacity(0.12))
            )
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var sectionPicker: some View {
        let visible = workspaceViewModel.visibleSections(for: dataStore.cashAccessContext)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visible) { section in
                    if section == workspaceViewModel.selectedSection {
                        Button(section.rawValue) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                workspaceViewModel.selectedSection = section
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    } else {
                        Button(section.rawValue) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                workspaceViewModel.selectedSection = section
                            }
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .padding(.top, 6)
        .background(AppTheme.surface)
    }

    private var transactionFilterBar: some View {
        ViewThatFits(in: .horizontal) {
            expandedFilterBar
            compactFilterBar
        }
        .background(AppTheme.surface)
    }

    private var expandedFilterBar: some View {
        HStack(spacing: 10) {
            searchField
                .frame(width: 220)
            typePicker
            statusPicker
            categoryPicker
            resetFiltersButton
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var compactFilterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                searchField
                resetFiltersButton
            }
            HStack(spacing: 8) {
                typePicker
                statusPicker
                categoryPicker
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        TextField("Suche", text: Binding(
            get: { workspaceViewModel.filter.query },
            set: { workspaceViewModel.applySearch($0) }
        ))
        .textFieldStyle(.roundedBorder)
        .foregroundStyle(Color.black)
    }

    private var typePicker: some View {
        Picker("Typ", selection: Binding(
            get: { workspaceViewModel.filter.transactionType },
            set: {
                workspaceViewModel.filter.transactionType = $0
                workspaceViewModel.transactionPage = 1
            }
        )) {
            Text("Alle").tag(Optional<CashTransactionKind>.none)
            ForEach(CashTransactionKind.allCases) { type in
                Text(type.title).tag(Optional(type))
            }
        }
        .pickerStyle(.menu)
        .foregroundStyle(Color.black)
    }

    private var statusPicker: some View {
        Picker("Status", selection: Binding(
            get: { workspaceViewModel.filter.statuses.first },
            set: { newValue in
                workspaceViewModel.filter.statuses = newValue.map { [$0] } ?? []
                workspaceViewModel.transactionPage = 1
            }
        )) {
            Text("Alle").tag(Optional<CashPaymentStatus>.none)
            ForEach(CashPaymentStatus.allCases) { status in
                Text(status.title).tag(Optional(status))
            }
        }
        .pickerStyle(.menu)
        .foregroundStyle(Color.black)
    }

    private var categoryPicker: some View {
        Picker("Kategorie", selection: Binding(
            get: { workspaceViewModel.filter.categoryIDs.first },
            set: { newValue in
                workspaceViewModel.filter.categoryIDs = newValue.map { [$0] } ?? []
                workspaceViewModel.transactionPage = 1
            }
        )) {
            Text("Alle Kategorien").tag(Optional<UUID>.none)
            ForEach(dataStore.cashCategories) { category in
                Text(category.name).tag(Optional(category.id))
            }
        }
        .pickerStyle(.menu)
        .foregroundStyle(Color.black)
    }

    private var resetFiltersButton: some View {
        Button {
            workspaceViewModel.resetFilters()
        } label: {
            Text("Filter zurücksetzen")
                .foregroundStyle(Color.black)
        }
        .buttonStyle(SecondaryActionButtonStyle())
    }

    @ViewBuilder
    private var content: some View {
        switch workspaceViewModel.selectedSection {
        case .dashboard:
            CashDashboardView(
                viewModel: dashboardViewModel,
                summary: dashboardViewModel.summary(store: dataStore),
                timelinePoints: dashboardViewModel.timeline(store: dataStore),
                categoryBreakdown: dashboardViewModel.categoryBreakdown(store: dataStore),
                topExpense: dashboardViewModel.topExpenseCategories(store: dataStore),
                topIncome: dashboardViewModel.topIncomeCategories(store: dataStore),
                goals: dataStore.cashGoals,
                canViewBalance: dataStore.cashAccessContext.canViewBalance,
                canManageGoals: dataStore.cashAccessContext.permissions.contains(.manageGoals),
                onCreateGoal: {
                    workspaceViewModel.presentCreateGoal()
                }
            )
            .padding(12)
        case .transactions:
            CashTransactionListView(
                viewModel: listViewModel,
                transactions: workspaceViewModel.pagedTransactions(store: dataStore),
                categories: dataStore.cashCategories,
                playersByID: Dictionary(uniqueKeysWithValues: dataStore.players.map { ($0.id, $0.name) }),
                trainerName: { trainerID in dataStore.trainerDisplayName(for: trainerID) },
                canEdit: dataStore.cashAccessContext.canManageTransactions,
                canDelete: dataStore.cashAccessContext.canDeleteTransactions,
                onEdit: { transaction in
                    workspaceViewModel.presentEditTransaction(transaction)
                },
                onDuplicate: { transaction in
                    Task { await workspaceViewModel.duplicateTransaction(transaction.id, store: dataStore) }
                },
                onDelete: { transaction in
                    Task { await workspaceViewModel.deleteTransaction(transaction.id, store: dataStore) }
                },
                onLoadMore: {
                    workspaceViewModel.loadMoreTransactions()
                },
                canLoadMore: workspaceViewModel.canLoadMoreTransactions(store: dataStore)
            )
            .padding(12)
        case .payments:
            CashPlayerPaymentsView(
                viewModel: paymentsViewModel,
                contributions: paymentsViewModel.filteredContributions(store: dataStore),
                playersByID: Dictionary(uniqueKeysWithValues: dataStore.players.map { ($0.id, $0.name) }),
                accessContext: dataStore.cashAccessContext,
                onMarkStatus: { status in
                    Task { await paymentsViewModel.markSelected(status: status, store: dataStore) }
                },
                onSendReminder: {
                    Task { await paymentsViewModel.sendReminders(store: dataStore) }
                }
            )
            .padding(12)
        case .goals:
            CashGoalsView(
                goals: dataStore.cashGoals,
                canEdit: dataStore.cashAccessContext.permissions.contains(.manageGoals),
                onCreate: {
                    workspaceViewModel.presentCreateGoal()
                },
                onEdit: { goal in
                    workspaceViewModel.presentEditGoal(goal)
                },
                onDelete: { goal in
                    Task { await workspaceViewModel.deleteGoal(goal.id, store: dataStore) }
                }
            )
            .padding(12)
        }
    }

    private var statusFooter: some View {
        HStack {
            let firstMessage = [
                workspaceViewModel.statusMessage,
                paymentsViewModel.statusMessage,
                dataStore.cashLastErrorMessage
            ].compactMap { $0 }.first ?? ""
            Text(firstMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private var goalEditorSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(workspaceViewModel.editingGoalID == nil ? "Kassenziel anlegen" : "Kassenziel bearbeiten")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black)

            TextField("Name", text: $workspaceViewModel.goalDraft.name)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color.black)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Zielbetrag")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black)
                    TextField(
                        "",
                        value: $workspaceViewModel.goalDraft.targetAmount,
                        formatter: Self.currencyFormatter
                    )
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aktueller Stand")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black)
                    TextField(
                        "",
                        value: $workspaceViewModel.goalDraft.currentProgress,
                        formatter: Self.currencyFormatter
                    )
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                }
            }

            HStack(spacing: 12) {
                DatePicker("Start", selection: $workspaceViewModel.goalDraft.startDate, displayedComponents: .date)
                    .foregroundStyle(Color.black)
                DatePicker("Ende", selection: $workspaceViewModel.goalDraft.endDate, displayedComponents: .date)
                    .foregroundStyle(Color.black)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Abbrechen") {
                    workspaceViewModel.isGoalEditorPresented = false
                }
                .foregroundStyle(Color.black)
                .buttonStyle(SecondaryActionButtonStyle())

                Button("Speichern") {
                    Task { await workspaceViewModel.saveGoal(store: dataStore) }
                }
                .foregroundStyle(Color.black)
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(18)
        .background(AppTheme.background)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }

    private var connectionLabel: String {
        switch dataStore.cashConnectionState {
        case .placeholder:
            return "Lokal"
        case .syncing:
            return "Sync läuft"
        case .live:
            return "Live"
        case .failed:
            return "Fehler"
        }
    }

    private var connectionColor: Color {
        switch dataStore.cashConnectionState {
        case .placeholder:
            return .orange
        case .syncing:
            return .blue
        case .live:
            return AppTheme.primary
        case .failed:
            return .red
        }
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}

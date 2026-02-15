import Foundation

@MainActor
extension AppDataStore {
    func bootstrapCashModule() async {
        updateCashAccessContext()
        ensureCashCategories()

        if AppConfiguration.isPlaceholder {
            cashConnectionState = .placeholder
            seedCashPlaceholderDataIfNeeded()
            return
        }

        cashConnectionState = .syncing
        do {
            let bootstrap = try await backend.fetchCashBootstrap()
            cashCategories = bootstrap.categories.map { mapCashCategory(dto: $0) }
            cashTransactions = bootstrap.transactions.map { mapCashTransaction(dto: $0) }
            cashMonthlyContributions = bootstrap.contributions.map { mapCashContribution(dto: $0) }
            cashGoals = bootstrap.goals.map { mapCashGoal(dto: $0) }
            cashConnectionState = .live
            syncLegacyTransactionsFromCash()
        } catch {
            if isConnectivityFailure(error) {
                cashConnectionState = .failed(error.localizedDescription)
                cashLastErrorMessage = error.localizedDescription
                motionError(error, scope: .mannschaftskasse, title: "Kassenmodul offline")
            } else {
                print("[client] bootstrapCashModule: endpoint not available — \(error.localizedDescription)")
                cashConnectionState = .live
                motionError(error, scope: .mannschaftskasse, title: "Kassendaten konnten nicht geladen werden")
            }
        }
    }

    func loadCashTransactions(
        cursor: String? = nil,
        limit: Int = 120,
        filter: CashFilterState
    ) async {
        guard !AppConfiguration.isPlaceholder else {
            cashTransactionsNextCursor = nil
            return
        }

        do {
            let from = filter.range?.start
            let to = filter.range?.end
            let categoryID = filter.categoryIDs.count == 1 ? filter.categoryIDs.first : nil
            let response = try await backend.fetchCashTransactions(
                cursor: cursor,
                limit: limit,
                from: from,
                to: to,
                categoryID: categoryID,
                playerID: filter.playerID,
                status: filter.statuses.count == 1 ? filter.statuses.first : nil,
                type: filter.transactionType,
                query: filter.query
            )

            let mapped = response.items.map { mapCashTransaction(dto: $0) }
            if cursor == nil {
                cashTransactions = mapped
            } else {
                let existingIDs = Set(cashTransactions.map(\.id))
                cashTransactions.append(contentsOf: mapped.filter { !existingIDs.contains($0.id) })
            }
            cashTransactionsNextCursor = response.nextCursor
            syncLegacyTransactionsFromCash()
            cashConnectionState = .live
        } catch {
            cashLastErrorMessage = error.localizedDescription
            if case .failed = cashConnectionState {} else {
                cashConnectionState = .failed(error.localizedDescription)
            }
            motionError(error, scope: .mannschaftskasse, title: "Transaktionen konnten nicht geladen werden")
        }
    }

    func upsertCashTransaction(
        draft: CashTransactionDraft,
        editingID: UUID? = nil
    ) async throws -> CashTransaction {
        if !cashAccessContext.canManageTransactions {
            throw CashStoreError.missingPermission
        }

        let validator = CashValidationService()
        if let message = validator.validateTransactionDraft(draft) {
            throw NSError(domain: "CashValidation", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }

        let normalizedAmount = abs(draft.amount)
        var transaction = CashTransaction(
            id: editingID ?? UUID(),
            amount: normalizedAmount,
            date: draft.date,
            categoryID: draft.categoryID,
            description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
            type: draft.type,
            playerID: draft.playerID,
            responsibleTrainerID: draft.responsibleTrainerID,
            comment: draft.comment.trimmingCharacters(in: .whitespacesAndNewlines),
            paymentStatus: draft.paymentStatus,
            contextLabel: draft.contextLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date(),
            updatedAt: Date(),
            syncState: AppConfiguration.isPlaceholder ? .synced : .pending
        )

        if let editingID,
           let index = cashTransactions.firstIndex(where: { $0.id == editingID }) {
            transaction.createdAt = cashTransactions[index].createdAt
            transaction.backendID = cashTransactions[index].backendID
            cashTransactions[index] = transaction
        } else {
            cashTransactions.insert(transaction, at: 0)
        }

        if !AppConfiguration.isPlaceholder {
            do {
                if let backendID = transaction.backendID {
                    let dto = try await backend.updateCashTransaction(
                        transactionID: backendID,
                        request: UpsertCashTransactionRequest(
                            amount: transaction.amount,
                            date: transaction.date,
                            categoryID: categoryBackendID(for: transaction.categoryID) ?? transaction.categoryID.uuidString,
                            description: transaction.description,
                            type: transaction.type.rawValue,
                            playerID: transaction.playerID,
                            responsibleTrainerID: transaction.responsibleTrainerID,
                            comment: transaction.comment,
                            paymentStatus: transaction.paymentStatus.rawValue,
                            contextLabel: transaction.contextLabel
                        )
                    )
                    transaction = mapCashTransaction(dto: dto, fallbackLocalID: transaction.id)
                } else {
                    let dto = try await backend.createCashTransaction(
                        UpsertCashTransactionRequest(
                            amount: transaction.amount,
                            date: transaction.date,
                            categoryID: categoryBackendID(for: transaction.categoryID) ?? transaction.categoryID.uuidString,
                            description: transaction.description,
                            type: transaction.type.rawValue,
                            playerID: transaction.playerID,
                            responsibleTrainerID: transaction.responsibleTrainerID,
                            comment: transaction.comment,
                            paymentStatus: transaction.paymentStatus.rawValue,
                            contextLabel: transaction.contextLabel
                        )
                    )
                    transaction = mapCashTransaction(dto: dto, fallbackLocalID: transaction.id)
                }
            } catch {
                markCashTransactionSyncState(id: transaction.id, state: .syncFailed)
                throw error
            }
        }

        if let index = cashTransactions.firstIndex(where: { $0.id == transaction.id }) {
            cashTransactions[index] = transaction
        } else {
            cashTransactions.insert(transaction, at: 0)
        }
        syncLegacyTransactionsFromCash()
        if editingID == nil {
            motionCreate(
                transaction.type == .income ? "Einnahme gebucht" : "Ausgabe gebucht",
                subtitle: transaction.description,
                scope: .mannschaftskasse,
                contextId: transaction.id.uuidString,
                icon: transaction.type == .income ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"
            )
        } else {
            motionUpdate(
                "Buchung aktualisiert",
                subtitle: transaction.description,
                scope: .mannschaftskasse,
                contextId: transaction.id.uuidString,
                icon: "checkmark.circle.fill"
            )
        }
        return transaction
    }

    func deleteCashTransaction(id: UUID) async throws {
        guard cashAccessContext.canDeleteTransactions else {
            throw CashStoreError.missingPermission
        }
        guard let index = cashTransactions.firstIndex(where: { $0.id == id }) else {
            throw CashStoreError.transactionNotFound
        }
        let backup = cashTransactions[index]
        cashTransactions.remove(at: index)

        if !AppConfiguration.isPlaceholder, let backendID = backup.backendID {
            do {
                _ = try await backend.deleteCashTransaction(transactionID: backendID)
            } catch {
                cashTransactions.insert(backup, at: index)
                motionError(error, scope: .mannschaftskasse, title: "Buchung konnte nicht gelöscht werden", contextId: id.uuidString)
                throw error
            }
        }
        syncLegacyTransactionsFromCash()
        motionDelete(
            "Buchung gelöscht",
            subtitle: backup.description,
            scope: .mannschaftskasse,
            contextId: id.uuidString,
            icon: "trash.fill"
        )
    }

    func duplicateCashTransaction(id: UUID) async throws -> CashTransaction {
        guard let source = cashTransactions.first(where: { $0.id == id }) else {
            throw CashStoreError.transactionNotFound
        }
        var duplicated = CashTransaction(
            id: UUID(),
            backendID: nil,
            amount: source.amount,
            date: Date(),
            categoryID: source.categoryID,
            description: "\(source.description) Kopie",
            type: source.type,
            playerID: source.playerID,
            responsibleTrainerID: source.responsibleTrainerID,
            comment: source.comment,
            paymentStatus: source.paymentStatus,
            contextLabel: source.contextLabel,
            createdAt: Date(),
            updatedAt: Date(),
            syncState: AppConfiguration.isPlaceholder ? .synced : .pending
        )
        cashTransactions.insert(duplicated, at: 0)

        if !AppConfiguration.isPlaceholder {
            do {
                let dto = try await backend.createCashTransaction(
                    UpsertCashTransactionRequest(
                        amount: duplicated.amount,
                        date: duplicated.date,
                        categoryID: categoryBackendID(for: duplicated.categoryID) ?? duplicated.categoryID.uuidString,
                        description: duplicated.description,
                        type: duplicated.type.rawValue,
                        playerID: duplicated.playerID,
                        responsibleTrainerID: duplicated.responsibleTrainerID,
                        comment: duplicated.comment,
                        paymentStatus: duplicated.paymentStatus.rawValue,
                        contextLabel: duplicated.contextLabel
                    )
                )
                duplicated = mapCashTransaction(dto: dto, fallbackLocalID: duplicated.id)
                if let idx = cashTransactions.firstIndex(where: { $0.id == duplicated.id }) {
                    cashTransactions[idx] = duplicated
                }
            } catch {
                markCashTransactionSyncState(id: duplicated.id, state: .syncFailed)
                motionError(error, scope: .mannschaftskasse, title: "Buchung konnte nicht dupliziert werden", contextId: duplicated.id.uuidString)
                throw error
            }
        }
        syncLegacyTransactionsFromCash()
        motionCreate(
            "Buchung dupliziert",
            subtitle: duplicated.description,
            scope: .mannschaftskasse,
            contextId: duplicated.id.uuidString,
            icon: "doc.on.doc.fill"
        )
        return duplicated
    }

    func updateCashContributionStatus(contributionID: UUID, status: CashPaymentStatus) async throws {
        guard let index = cashMonthlyContributions.firstIndex(where: { $0.id == contributionID }) else {
            throw CashStoreError.contributionNotFound
        }

        if cashAccessContext.role == .player,
           cashMonthlyContributions[index].playerID != cashAccessContext.currentPlayerID {
            throw CashStoreError.missingPermission
        }

        cashMonthlyContributions[index].status = status
        cashMonthlyContributions[index].updatedAt = Date()

        guard !AppConfiguration.isPlaceholder else { return }
        guard let backendID = cashMonthlyContributions[index].backendID else { return }
        let dto = try await backend.upsertCashContribution(
            contributionID: backendID,
            request: UpsertMonthlyContributionRequest(
                playerID: cashMonthlyContributions[index].playerID,
                amount: cashMonthlyContributions[index].amount,
                dueDate: cashMonthlyContributions[index].dueDate,
                status: status.rawValue,
                monthKey: cashMonthlyContributions[index].monthKey
            )
        )
        cashMonthlyContributions[index] = mapCashContribution(dto: dto, fallbackLocalID: cashMonthlyContributions[index].id)
    }

    func sendCashPaymentReminder(contributionIDs: [UUID]) async throws {
        guard cashAccessContext.permissions.contains(.sendPaymentReminder) else {
            throw CashStoreError.missingPermission
        }
        let validIDs = Set(contributionIDs)
        guard !validIDs.isEmpty else { return }

        let now = Date()
        for index in cashMonthlyContributions.indices where validIDs.contains(cashMonthlyContributions[index].id) {
            cashMonthlyContributions[index].lastReminderAt = now
        }

        guard !AppConfiguration.isPlaceholder else { return }
        let backendIDs = cashMonthlyContributions
            .filter { validIDs.contains($0.id) }
            .compactMap(\.backendID)
        if !backendIDs.isEmpty {
            _ = try await backend.sendCashPaymentReminder(
                request: SendCashReminderRequest(contributionIDs: backendIDs)
            )
        }
    }

    func generateRecurringMonthlyContributions(
        monthDate: Date = Date(),
        defaultAmount: Double = 35
    ) async throws {
        guard cashAccessContext.permissions.contains(.manageContributions) else {
            throw CashStoreError.missingPermission
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        guard let monthStart = calendar.date(from: components) else { return }
        guard let dueDate = calendar.date(byAdding: .day, value: 7, to: monthStart) else { return }
        let key = Self.monthKey(for: monthStart)

        let existingPlayerIDs = Set(
            cashMonthlyContributions
                .filter { $0.monthKey == key }
                .map(\.playerID)
        )

        let createPlayers = players.filter { !existingPlayerIDs.contains($0.id) }
        guard !createPlayers.isEmpty else { return }

        let isOverdue = dueDate < Date()
        let createdContributions: [MonthlyContribution] = createPlayers.map { player in
            MonthlyContribution(
                playerID: player.id,
                amount: defaultAmount,
                dueDate: dueDate,
                status: isOverdue ? .overdue : .open,
                monthKey: key
            )
        }
        cashMonthlyContributions.append(contentsOf: createdContributions)

        guard !AppConfiguration.isPlaceholder else { return }
        for index in createdContributions.indices {
            let contribution = createdContributions[index]
            let dto = try await backend.createCashContribution(
                request: UpsertMonthlyContributionRequest(
                    playerID: contribution.playerID,
                    amount: contribution.amount,
                    dueDate: contribution.dueDate,
                    status: contribution.status.rawValue,
                    monthKey: contribution.monthKey
                )
            )
            if let localIndex = cashMonthlyContributions.firstIndex(where: { $0.id == contribution.id }) {
                cashMonthlyContributions[localIndex] = mapCashContribution(dto: dto, fallbackLocalID: contribution.id)
            }
        }
    }

    func upsertCashGoal(
        draft: CashGoalDraft,
        editingID: UUID? = nil
    ) async throws -> CashGoal {
        guard cashAccessContext.permissions.contains(.manageGoals) else {
            throw CashStoreError.missingPermission
        }

        let validator = CashValidationService()
        if let message = validator.validateGoalDraft(draft) {
            throw NSError(domain: "CashValidation", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }

        var goal = CashGoal(
            id: editingID ?? UUID(),
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            targetAmount: draft.targetAmount,
            currentProgress: draft.currentProgress,
            startDate: draft.startDate,
            endDate: draft.endDate,
            createdAt: Date(),
            updatedAt: Date()
        )

        if let editingID,
           let index = cashGoals.firstIndex(where: { $0.id == editingID }) {
            goal.createdAt = cashGoals[index].createdAt
            goal.backendID = cashGoals[index].backendID
            cashGoals[index] = goal
        } else {
            cashGoals.insert(goal, at: 0)
        }

        guard !AppConfiguration.isPlaceholder else { return goal }

        do {
            let dto: CashGoalDTO
            if let backendID = goal.backendID {
                dto = try await backend.updateCashGoal(
                    goalID: backendID,
                    request: UpsertCashGoalRequest(
                        name: goal.name,
                        targetAmount: goal.targetAmount,
                        currentProgress: goal.currentProgress,
                        startDate: goal.startDate,
                        endDate: goal.endDate
                    )
                )
            } else {
                dto = try await backend.createCashGoal(
                    request: UpsertCashGoalRequest(
                        name: goal.name,
                        targetAmount: goal.targetAmount,
                        currentProgress: goal.currentProgress,
                        startDate: goal.startDate,
                        endDate: goal.endDate
                    )
                )
            }
            goal = mapCashGoal(dto: dto, fallbackLocalID: goal.id)
            if let index = cashGoals.firstIndex(where: { $0.id == goal.id }) {
                cashGoals[index] = goal
            }
            if editingID == nil {
                motionCreate(
                    "Kassenziel erstellt",
                    subtitle: goal.name,
                    scope: .mannschaftskasse,
                    contextId: goal.id.uuidString,
                    icon: "target"
                )
            } else {
                motionUpdate(
                    "Kassenziel aktualisiert",
                    subtitle: goal.name,
                    scope: .mannschaftskasse,
                    contextId: goal.id.uuidString,
                    icon: "target"
                )
            }
            return goal
        } catch {
            motionError(error, scope: .mannschaftskasse, title: "Kassenziel konnte nicht gespeichert werden", contextId: goal.id.uuidString)
            throw error
        }
    }

    func deleteCashGoal(id: UUID) async throws {
        guard cashAccessContext.permissions.contains(.manageGoals) else {
            throw CashStoreError.missingPermission
        }
        guard let index = cashGoals.firstIndex(where: { $0.id == id }) else {
            throw CashStoreError.goalNotFound
        }
        let backup = cashGoals[index]
        cashGoals.remove(at: index)

        guard !AppConfiguration.isPlaceholder else { return }
        if let backendID = backup.backendID {
            do {
                _ = try await backend.deleteCashGoal(goalID: backendID)
            } catch {
                cashGoals.insert(backup, at: index)
                motionError(error, scope: .mannschaftskasse, title: "Kassenziel konnte nicht gelöscht werden", contextId: id.uuidString)
                throw error
            }
        }
        motionDelete(
            "Kassenziel gelöscht",
            subtitle: backup.name,
            scope: .mannschaftskasse,
            contextId: id.uuidString,
            icon: "target"
        )
    }

    func filteredCashTransactions(_ filter: CashFilterState) -> [CashTransaction] {
        let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return cashTransactions
            .filter { transaction in
                if let range = filter.range, !range.contains(transaction.date) {
                    return false
                }
                if let type = filter.transactionType, type != transaction.type {
                    return false
                }
                if !filter.categoryIDs.isEmpty && !filter.categoryIDs.contains(transaction.categoryID) {
                    return false
                }
                if let playerID = filter.playerID, playerID != transaction.playerID {
                    return false
                }
                if let responsibleTrainerID = filter.responsibleTrainerID,
                   responsibleTrainerID != transaction.responsibleTrainerID {
                    return false
                }
                if !filter.statuses.isEmpty && !filter.statuses.contains(transaction.paymentStatus) {
                    return false
                }
                if !query.isEmpty {
                    let categoryName = category(for: transaction.categoryID)?.name.lowercased() ?? ""
                    let playerName = players.first(where: { $0.id == transaction.playerID })?.name.lowercased() ?? ""
                    let trainerName = adminPerson(matchingTrainerIdentifier: transaction.responsibleTrainerID)?.fullName.lowercased() ?? ""
                    if !transaction.description.lowercased().contains(query)
                        && !transaction.comment.lowercased().contains(query)
                        && !categoryName.contains(query)
                        && !playerName.contains(query)
                        && !trainerName.contains(query) {
                        return false
                    }
                }
                return true
            }
            .sorted { $0.date > $1.date }
    }

    func cashVisibleContributions() -> [MonthlyContribution] {
        if cashAccessContext.role == .player, let currentPlayerID = cashAccessContext.currentPlayerID {
            return cashMonthlyContributions
                .filter { $0.playerID == currentPlayerID }
                .sorted { $0.dueDate > $1.dueDate }
        }
        return cashMonthlyContributions.sorted { $0.dueDate > $1.dueDate }
    }

    func cashSummary(for range: DateInterval? = nil) -> CashSummary {
        let scoped = cashTransactions.filter { transaction in
            guard let range else { return true }
            return range.contains(transaction.date)
        }
        let totalIncome = scoped
            .filter { $0.type == .income }
            .reduce(0) { $0 + abs($1.amount) }
        let totalExpense = scoped
            .filter { $0.type == .expense }
            .reduce(0) { $0 + abs($1.amount) }
        let currentBalance = totalIncome - totalExpense
        let openAmount = scoped
            .filter { $0.paymentStatus == .open }
            .reduce(0) { $0 + abs($1.amount) }
        let overdueAmount = scoped
            .filter { $0.paymentStatus == .overdue }
            .reduce(0) { $0 + abs($1.amount) }
        return CashSummary(
            openingBalance: 0,
            currentBalance: currentBalance,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            projectedBalance: currentBalance + openAmount + overdueAmount,
            openAmount: openAmount,
            overdueAmount: overdueAmount
        )
    }

    func cashCategoryBreakdown(for range: DateInterval? = nil) -> [CashCategoryBreakdown] {
        let scoped = cashTransactions.filter { transaction in
            guard let range else { return true }
            return range.contains(transaction.date)
        }
        let grouped = Dictionary(grouping: scoped, by: \.categoryID)
        let total = grouped.values.flatMap { $0 }.reduce(0.0) { partial, transaction in
            partial + abs(transaction.amount)
        }

        return grouped.compactMap { categoryID, entries in
            guard let category = category(for: categoryID) else { return nil }
            let amount = entries.reduce(0.0) { $0 + abs($1.amount) }
            let ratio = total > 0 ? amount / total : 0
            return CashCategoryBreakdown(
                categoryID: categoryID,
                categoryName: category.name,
                colorHex: category.colorHex,
                amount: amount,
                ratio: ratio
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    func cashTimeline(
        granularity: CashTimelineGranularity,
        range: DateInterval? = nil
    ) -> [CashTimelinePoint] {
        let calendar = Calendar.current
        let sortedTransactions = cashTransactions.sorted { $0.date < $1.date }
        guard !sortedTransactions.isEmpty else { return [] }

        func bucketStart(for date: Date) -> Date {
            switch granularity {
            case .daily:
                return calendar.startOfDay(for: date)
            case .weekly:
                let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
                return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
            case .monthly:
                let comps = calendar.dateComponents([.year, .month], from: date)
                return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
            case .yearly:
                let comps = calendar.dateComponents([.year], from: date)
                return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
            }
        }

        func nextBucket(after date: Date) -> Date {
            switch granularity {
            case .daily:
                return calendar.date(byAdding: .day, value: 1, to: date) ?? date
            case .weekly:
                return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
            case .monthly:
                return calendar.date(byAdding: .month, value: 1, to: date) ?? date
            case .yearly:
                return calendar.date(byAdding: .year, value: 1, to: date) ?? date
            }
        }

        let lowerBound = range?.start ?? sortedTransactions.first!.date
        let upperBound = range?.end ?? sortedTransactions.last!.date
        var bucketDate = bucketStart(for: lowerBound)
        let endBucketDate = bucketStart(for: upperBound)

        var buckets: [Date: (income: Double, expense: Double)] = [:]
        while bucketDate <= endBucketDate {
            buckets[bucketDate] = (0, 0)
            let next = nextBucket(after: bucketDate)
            if next == bucketDate {
                break
            }
            bucketDate = next
        }

        let scoped = sortedTransactions.filter { transaction in
            guard let range else { return true }
            return range.contains(transaction.date)
        }

        for item in scoped {
            let keyDate = bucketStart(for: item.date)
            var existing = buckets[keyDate] ?? (0, 0)
            if item.type == .income {
                existing.income += abs(item.amount)
            } else {
                existing.expense += abs(item.amount)
            }
            buckets[keyDate] = existing
        }

        let sortedDates = buckets.keys.sorted()
        let formatter: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "de_DE")
            switch granularity {
            case .daily:
                df.dateFormat = "dd.MM"
            case .weekly:
                df.dateFormat = "'KW' ww"
            case .monthly:
                df.dateFormat = "MMM yy"
            case .yearly:
                df.dateFormat = "yyyy"
            }
            return df
        }()

        let openingBalance = sortedTransactions.reduce(0.0) { partial, transaction in
            guard transaction.date < lowerBound else { return partial }
            return partial + (transaction.type == .income ? abs(transaction.amount) : -abs(transaction.amount))
        }

        var runningBalance = openingBalance
        return sortedDates.map { bucketDate in
            let value = buckets[bucketDate] ?? (0, 0)
            runningBalance += value.income - value.expense
            return CashTimelinePoint(
                label: formatter.string(from: bucketDate),
                income: value.income,
                expense: value.expense,
                balance: runningBalance
            )
        }
    }

    func contributionStatusSummary() -> (paid: Int, open: Int, overdue: Int) {
        let visible = cashVisibleContributions()
        return (
            paid: visible.filter { $0.status == .paid }.count,
            open: visible.filter { $0.status == .open }.count,
            overdue: visible.filter { $0.status == .overdue }.count
        )
    }

    func category(for id: UUID) -> CashCategory? {
        cashCategories.first(where: { $0.id == id })
    }

    func trainerDisplayName(for trainerID: String?) -> String {
        guard let trainerID else { return "Nicht gesetzt" }
        return adminPerson(matchingTrainerIdentifier: trainerID)?.fullName ?? trainerID
    }

    func syncLegacyTransactionsFromCash() {
        transactions = cashTransactions
            .sorted { $0.date > $1.date }
            .map {
                TransactionEntry(
                    title: $0.description,
                    amount: $0.type == .expense ? -abs($0.amount) : abs($0.amount),
                    date: $0.date,
                    type: $0.type == .income ? .income : .expense
                )
            }
    }

    func reconcileCashTransactionsFromLegacy(_ legacyTransactions: [TransactionEntryDTO]) {
        ensureCashCategories()
        if !cashTransactions.isEmpty { return }

        let incomeCategory = cashCategories.first(where: { $0.name == "Beiträge" }) ?? cashCategories[0]
        let expenseCategory = cashCategories.first(where: { $0.name == "Material" }) ?? cashCategories[0]

        cashTransactions = legacyTransactions.map { dto in
            CashTransaction(
                amount: abs(dto.amount),
                date: dto.date,
                categoryID: dto.type.lowercased() == "income" ? incomeCategory.id : expenseCategory.id,
                description: dto.title,
                type: dto.type.lowercased() == "income" ? .income : .expense,
                paymentStatus: .paid,
                syncState: .synced
            )
        }
        syncLegacyTransactionsFromCash()
    }

    func seedCashPlaceholderDataIfNeeded() {
        // Placeholder seed data removed — backend is the source of truth.
        ensureCashCategories()
        updateCashAccessContext()
    }

    private func ensureCashCategories() {
        if cashCategories.isEmpty {
            cashCategories = CashCategory.defaultCategories
        }
    }

    private func updateCashAccessContext() {
        let userID = messengerCurrentUser?.userID
        let roleHint = messengerCurrentUser?.role.rawValue.lowercased() ?? ""
        let linkedPerson = adminPersons.first(where: { $0.linkedMessengerUserID == userID })

        let role: CashUserRole
        if roleHint.contains("player") || roleHint.contains("spieler") {
            role = .player
        } else if linkedPerson?.role == .teamManager {
            role = .cashier
        } else if linkedPerson?.role == .chefTrainer || linkedPerson?.role == .coTrainer {
            role = .trainer
        } else if linkedPerson?.role == .analyst || linkedPerson?.role == .medicalStaff {
            role = .trainer
        } else {
            role = .trainer
        }

        let permissions: Set<CashPermission>
        switch role {
        case .admin:
            permissions = Set(CashPermission.allCases)
        case .cashier:
            permissions = [.createTransaction, .editTransaction, .deleteTransaction, .manageGoals, .manageContributions, .sendPaymentReminder, .viewClubBalance]
        case .trainer:
            permissions = [.createTransaction, .editTransaction, .manageGoals, .manageContributions, .sendPaymentReminder, .viewClubBalance]
        case .player:
            permissions = []
        }

        cashAccessContext = CashAccessContext(
            role: role,
            permissions: permissions,
            currentPlayerID: linkedPerson?.linkedPlayerID
        )
    }

    private func categoryBackendID(for localID: UUID) -> String? {
        cashCategories.first(where: { $0.id == localID })?.backendID
    }

    private func adminPerson(matchingTrainerIdentifier trainerID: String?) -> AdminPerson? {
        guard let trainerID else { return nil }
        return adminPersons.first { person in
            person.backendID == trainerID || person.id.uuidString == trainerID
        }
    }

    private func markCashTransactionSyncState(id: UUID, state: AnalysisSyncState) {
        guard let index = cashTransactions.firstIndex(where: { $0.id == id }) else { return }
        cashTransactions[index].syncState = state
        cashTransactions[index].updatedAt = Date()
    }

    private static func monthKey(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return "\(year)-\(String(format: "%02d", month))"
    }

    private func mapCashCategory(dto: CashCategoryDTO) -> CashCategory {
        CashCategory(
            id: UUID(),
            backendID: dto.id,
            name: dto.name,
            colorHex: dto.colorHex,
            isDefault: dto.isDefault
        )
    }

    private func mapCashTransaction(dto: CashTransactionDTO, fallbackLocalID: UUID? = nil) -> CashTransaction {
        let categoryID = cashCategories.first(where: { $0.backendID == dto.categoryID })?.id ?? cashCategories.first?.id ?? UUID()
        return CashTransaction(
            id: fallbackLocalID ?? UUID(),
            backendID: dto.id,
            amount: abs(dto.amount),
            date: dto.date,
            categoryID: categoryID,
            description: dto.description,
            type: CashTransactionKind(rawValue: dto.type) ?? .expense,
            playerID: dto.playerID,
            responsibleTrainerID: dto.responsibleTrainerID,
            comment: dto.comment,
            paymentStatus: CashPaymentStatus(rawValue: dto.paymentStatus) ?? .paid,
            contextLabel: dto.contextLabel,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            syncState: .synced
        )
    }

    private func mapCashContribution(dto: MonthlyContributionDTO, fallbackLocalID: UUID? = nil) -> MonthlyContribution {
        MonthlyContribution(
            id: fallbackLocalID ?? UUID(),
            backendID: dto.id,
            playerID: dto.playerID,
            amount: dto.amount,
            dueDate: dto.dueDate,
            status: CashPaymentStatus(rawValue: dto.status) ?? .open,
            monthKey: dto.monthKey,
            lastReminderAt: dto.lastReminderAt,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    private func mapCashGoal(dto: CashGoalDTO, fallbackLocalID: UUID? = nil) -> CashGoal {
        CashGoal(
            id: fallbackLocalID ?? UUID(),
            backendID: dto.id,
            name: dto.name,
            targetAmount: dto.targetAmount,
            currentProgress: dto.currentProgress,
            startDate: dto.startDate,
            endDate: dto.endDate,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }
}

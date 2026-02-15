import Foundation

@MainActor
extension AppDataStore {
    func seedAdminPlaceholderDataIfNeeded() {
        // Placeholder seed data removed — backend is the source of truth.
        adminConnectionState = .placeholder
    }

    func bootstrapAdministration() async {
        if AppConfiguration.isPlaceholder {
            adminConnectionState = .placeholder
            seedAdminPlaceholderDataIfNeeded()
            return
        }

        adminConnectionState = .syncing
        do {
            let bootstrap = try await backend.fetchAdminBootstrap()
            applyAdminBootstrap(bootstrap)
            adminConnectionState = .live
            MotionEngine.shared.emit(
                .sync,
                payload: MotionPayload(
                    title: "Verwaltung synchronisiert",
                    subtitle: "Alle Verwaltungsdaten sind aktuell.",
                    iconName: "building.2.crop.circle",
                    severity: .success,
                    scope: .verwaltung
                )
            )
        } catch {
            if isConnectivityFailure(error) {
                adminConnectionState = .failed(error.localizedDescription)
                motionError(error, scope: .verwaltung, title: "Verwaltung offline")
            } else {
                print("[client] bootstrapAdministration: endpoint not available — \(error.localizedDescription)")
                adminConnectionState = .failed(error.localizedDescription)
                motionError(error, scope: .verwaltung, title: "Verwaltung konnte nicht geladen werden")
            }
        }
    }

    func adminDashboardMetrics() -> AdminDashboardMetrics {
        let trainers = adminPersons.filter { $0.personType == .trainer }
        let players = adminPersons.filter { $0.personType == .player }
        let rightsAlerts = adminPersons.filter {
            $0.personType == .trainer && $0.permissions.isEmpty
        }.count
        return AdminDashboardMetrics(
            totalPersons: adminPersons.count,
            activeTrainers: trainers.count,
            activePlayers: players.count,
            openInvitations: adminInvitations.filter { $0.status == .open }.count,
            rightsAlerts: rightsAlerts,
            activeGroups: adminGroups.count
        )
    }

    func upsertAdminPerson(_ person: AdminPerson) async throws -> AdminPerson {
        try AdminValidationService().validatePerson(person)

        if AppConfiguration.isPlaceholder {
            let normalized = normalizeAdminPerson(person)
            upsertLocalAdminPerson(normalized)
            syncPlayerWithAdminPerson(normalized)
            syncProfileFromAdminPerson(normalized)
            syncAdminPersonsToMessengerDirectory()
            appendAdminAudit(
                area: .users,
                action: person.backendID == nil ? "Person angelegt" : "Person aktualisiert",
                actorName: currentAdminActorName(),
                targetName: normalized.fullName,
                details: "\(normalized.personType.title) in \(normalized.teamName)"
            )
            return normalized
        }

        let request = makeUpsertAdminPersonRequest(person)
        let dto: AdminPersonDTO
        if let backendID = person.backendID, !backendID.isEmpty {
            dto = try await backend.updateAdminPerson(personID: backendID, request: request)
        } else {
            dto = try await backend.createAdminPerson(request)
        }
        let mapped = mapAdminPerson(dto, fallback: person)
        upsertLocalAdminPerson(mapped)
        syncPlayerWithAdminPerson(mapped)
        syncProfileFromAdminPerson(mapped)
        syncAdminPersonsToMessengerDirectory()
        appendAdminAudit(
            area: .users,
            action: person.backendID == nil ? "Person angelegt" : "Person aktualisiert",
            actorName: currentAdminActorName(),
            targetName: mapped.fullName,
            details: "\(mapped.personType.title) in \(mapped.teamName)"
        )
        if person.backendID == nil {
            motionCreate(
                "Person angelegt",
                subtitle: mapped.fullName,
                scope: .verwaltung,
                contextId: mapped.id.uuidString,
                icon: "person.badge.plus"
            )
        } else {
            motionUpdate(
                "Person aktualisiert",
                subtitle: mapped.fullName,
                scope: .verwaltung,
                contextId: mapped.id.uuidString,
                icon: "person.crop.circle.badge.checkmark"
            )
        }
        return mapped
    }

    func deleteAdminPerson(_ personID: UUID) async throws {
        guard let index = adminPersons.firstIndex(where: { $0.id == personID }) else {
            throw AdminStoreError.entityNotFound
        }
        let person = adminPersons[index]

        if !AppConfiguration.isPlaceholder {
            guard let backendID = person.backendID else {
                throw AdminStoreError.entityNotFound
            }
            _ = try await backend.deleteAdminPerson(personID: backendID)
        }

        adminPersons.remove(at: index)
        removeProfileLinkedToAdminPerson(personID)
        for groupIndex in adminGroups.indices {
            adminGroups[groupIndex].memberIDs.removeAll { $0 == personID }
            if adminGroups[groupIndex].responsibleCoachID == personID {
                adminGroups[groupIndex].responsibleCoachID = nil
            }
            if adminGroups[groupIndex].assistantCoachID == personID {
                adminGroups[groupIndex].assistantCoachID = nil
            }
        }
        syncAdminPersonsToMessengerDirectory()
        appendAdminAudit(
            area: .users,
            action: "Person entfernt",
            actorName: currentAdminActorName(),
            targetName: person.fullName,
            details: "Eintrag wurde aus Verwaltung entfernt."
        )
        motionDelete(
            "Person entfernt",
            subtitle: person.fullName,
            scope: .verwaltung,
            contextId: personID.uuidString,
            icon: "person.badge.minus"
        )
    }

    func upsertAdminGroup(_ group: AdminGroup) async throws -> AdminGroup {
        try AdminValidationService().validateGroup(group)

        if AppConfiguration.isPlaceholder {
            let normalized = normalizeAdminGroup(group)
            upsertLocalAdminGroup(normalized)
            reconcilePersonGroupMemberships()
            appendAdminAudit(
                area: .groups,
                action: group.backendID == nil ? "Gruppe erstellt" : "Gruppe aktualisiert",
                actorName: currentAdminActorName(),
                targetName: normalized.name,
                details: "\(normalized.groupType.title), \(normalized.memberIDs.count) Mitglieder"
            )
            return normalized
        }

        let request = makeUpsertAdminGroupRequest(group)
        let dto: AdminGroupDTO
        if let backendID = group.backendID, !backendID.isEmpty {
            dto = try await backend.updateAdminGroup(groupID: backendID, request: request)
        } else {
            dto = try await backend.createAdminGroup(request)
        }
        let mapped = mapAdminGroup(dto: dto)
        upsertLocalAdminGroup(mapped)
        reconcilePersonGroupMemberships()
        appendAdminAudit(
            area: .groups,
            action: group.backendID == nil ? "Gruppe erstellt" : "Gruppe aktualisiert",
            actorName: currentAdminActorName(),
            targetName: mapped.name,
            details: "\(mapped.groupType.title), \(mapped.memberIDs.count) Mitglieder"
        )
        if group.backendID == nil {
            motionCreate(
                "Gruppe erstellt",
                subtitle: mapped.name,
                scope: .verwaltung,
                contextId: mapped.id.uuidString,
                icon: "person.3.sequence.fill"
            )
        } else {
            motionUpdate(
                "Gruppe aktualisiert",
                subtitle: mapped.name,
                scope: .verwaltung,
                contextId: mapped.id.uuidString,
                icon: "person.3.sequence.fill"
            )
        }
        return mapped
    }

    func deleteAdminGroup(_ groupID: UUID) async throws {
        guard let index = adminGroups.firstIndex(where: { $0.id == groupID }) else {
            throw AdminStoreError.entityNotFound
        }
        let group = adminGroups[index]

        if !AppConfiguration.isPlaceholder {
            guard let backendID = group.backendID else {
                throw AdminStoreError.entityNotFound
            }
            _ = try await backend.deleteAdminGroup(groupID: backendID)
        }

        adminGroups.remove(at: index)
        reconcilePersonGroupMemberships()
        appendAdminAudit(
            area: .groups,
            action: "Gruppe gelöscht",
            actorName: currentAdminActorName(),
            targetName: group.name,
            details: "Gruppe wurde entfernt."
        )
        motionDelete(
            "Gruppe gelöscht",
            subtitle: group.name,
            scope: .verwaltung,
            contextId: groupID.uuidString,
            icon: "person.3.sequence.fill"
        )
    }

    func createAdminInvitation(_ invitation: AdminInvitation) async throws -> AdminInvitation {
        try AdminValidationService().validateInvitation(invitation)

        if AppConfiguration.isPlaceholder {
            let normalized = normalizeAdminInvitation(invitation)
            adminInvitations.insert(normalized, at: 0)
            appendAdminAudit(
                area: .invitations,
                action: "Einladung versendet",
                actorName: currentAdminActorName(),
                targetName: normalized.recipientName,
                details: "\(normalized.role.title) für \(normalized.teamName)"
            )
            return normalized
        }

        let request = CreateAdminInvitationRequest(
            recipientName: invitation.recipientName,
            email: invitation.email,
            method: invitation.method.rawValue,
            role: invitation.role.rawValue,
            teamName: invitation.teamName,
            expiresAt: invitation.expiresAt
        )
        let dto = try await backend.createAdminInvitation(request)
        let mapped = mapAdminInvitation(dto)
        if let index = adminInvitations.firstIndex(where: { $0.id == mapped.id }) {
            adminInvitations[index] = mapped
        } else {
            adminInvitations.insert(mapped, at: 0)
        }
        appendAdminAudit(
            area: .invitations,
            action: "Einladung versendet",
            actorName: currentAdminActorName(),
            targetName: mapped.recipientName,
            details: "\(mapped.role.title) für \(mapped.teamName)"
        )
        motionCreate(
            "Einladung versendet",
            subtitle: mapped.recipientName,
            scope: .verwaltung,
            contextId: mapped.id.uuidString,
            icon: "envelope.badge.fill"
        )
        return mapped
    }

    func updateAdminInvitationStatus(invitationID: UUID, status: AdminInvitationStatus) async throws {
        guard let index = adminInvitations.firstIndex(where: { $0.id == invitationID }) else {
            throw AdminStoreError.entityNotFound
        }
        var invitation = adminInvitations[index]

        if AppConfiguration.isPlaceholder {
            invitation.status = status
            invitation.updatedAt = Date()
            adminInvitations[index] = invitation
        } else {
            guard let backendID = invitation.backendID else {
                throw AdminStoreError.entityNotFound
            }
            let dto = try await backend.updateAdminInvitationStatus(
                invitationID: backendID,
                request: UpdateAdminInvitationStatusRequest(status: status.rawValue)
            )
            invitation = mapAdminInvitation(dto, fallback: invitation)
            adminInvitations[index] = invitation
        }

        appendAdminAudit(
            area: .invitations,
            action: "Einladungsstatus geändert",
            actorName: currentAdminActorName(),
            targetName: invitation.recipientName,
            details: "Status: \(status.title)"
        )
    }

    func resendAdminInvitation(invitationID: UUID) async throws {
        guard let index = adminInvitations.firstIndex(where: { $0.id == invitationID }) else {
            throw AdminStoreError.entityNotFound
        }
        var invitation = adminInvitations[index]

        if AppConfiguration.isPlaceholder {
            invitation.status = .open
            invitation.sentAt = Date()
            invitation.updatedAt = Date()
            adminInvitations[index] = invitation
        } else {
            guard let backendID = invitation.backendID else {
                throw AdminStoreError.entityNotFound
            }
            let dto = try await backend.resendAdminInvitation(invitationID: backendID)
            invitation = mapAdminInvitation(dto, fallback: invitation)
            adminInvitations[index] = invitation
        }

        appendAdminAudit(
            area: .invitations,
            action: "Einladung erneut versendet",
            actorName: currentAdminActorName(),
            targetName: invitation.recipientName,
            details: invitation.email
        )
    }

    func upsertAdminSeason(_ season: AdminSeason) async throws -> AdminSeason {
        try AdminValidationService().validateSeason(season)

        if AppConfiguration.isPlaceholder {
            let normalized = normalizeAdminSeason(season)
            upsertLocalAdminSeason(normalized)
            appendAdminAudit(
                area: .seasons,
                action: season.backendID == nil ? "Saison erstellt" : "Saison aktualisiert",
                actorName: currentAdminActorName(),
                targetName: normalized.name,
                details: "\(normalized.status.title)"
            )
            return normalized
        }

        let request = UpsertAdminSeasonRequest(
            id: season.backendID,
            name: season.name,
            startsAt: season.startsAt,
            endsAt: season.endsAt,
            status: season.status.rawValue
        )

        let dto: AdminSeasonDTO
        if let backendID = season.backendID, !backendID.isEmpty {
            dto = try await backend.updateAdminSeason(seasonID: backendID, request: request)
        } else {
            dto = try await backend.createAdminSeason(request)
        }

        let mapped = mapAdminSeason(dto, fallback: season)
        upsertLocalAdminSeason(mapped)
        appendAdminAudit(
            area: .seasons,
            action: season.backendID == nil ? "Saison erstellt" : "Saison aktualisiert",
            actorName: currentAdminActorName(),
            targetName: mapped.name,
            details: "\(mapped.status.title)"
        )
        return mapped
    }

    func setActiveAdminSeason(_ seasonID: UUID) async throws {
        guard let season = adminSeasons.first(where: { $0.id == seasonID }) else {
            throw AdminStoreError.entityNotFound
        }
        if !AppConfiguration.isPlaceholder {
            guard let backendID = season.backendID else {
                throw AdminStoreError.entityNotFound
            }
            _ = try await backend.setAdminActiveSeason(SetActiveSeasonRequest(seasonID: backendID))
        }

        for index in adminSeasons.indices {
            adminSeasons[index].status = adminSeasons[index].id == seasonID ? .active : (adminSeasons[index].status == .active ? .locked : adminSeasons[index].status)
            adminSeasons[index].updatedAt = Date()
        }
        activeAdminSeasonID = seasonID
        appendAdminAudit(
            area: .seasons,
            action: "Saison aktiviert",
            actorName: currentAdminActorName(),
            targetName: season.name,
            details: "Aktive Saison gewechselt."
        )
    }

    func archiveAdminSeason(_ seasonID: UUID) async throws {
        guard let index = adminSeasons.firstIndex(where: { $0.id == seasonID }) else {
            throw AdminStoreError.entityNotFound
        }
        var season = adminSeasons[index]

        if !AppConfiguration.isPlaceholder {
            guard let backendID = season.backendID else {
                throw AdminStoreError.entityNotFound
            }
            let dto = try await backend.updateAdminSeasonStatus(
                seasonID: backendID,
                request: UpdateAdminSeasonStatusRequest(status: AdminSeasonStatus.archived.rawValue)
            )
            season = mapAdminSeason(dto, fallback: season)
        } else {
            season.status = .archived
            season.updatedAt = Date()
        }

        adminSeasons[index] = season
        if activeAdminSeasonID == seasonID {
            activeAdminSeasonID = adminSeasons.first(where: { $0.status == .active })?.id
        }
        appendAdminAudit(
            area: .seasons,
            action: "Saison archiviert",
            actorName: currentAdminActorName(),
            targetName: season.name,
            details: "Saison wurde archiviert."
        )
    }

    func duplicateRosterToSeason(sourceSeasonID: UUID, targetSeasonID: UUID) async throws {
        guard let source = adminSeasons.first(where: { $0.id == sourceSeasonID }),
              let targetIndex = adminSeasons.firstIndex(where: { $0.id == targetSeasonID }) else {
            throw AdminStoreError.entityNotFound
        }
        if !AppConfiguration.isPlaceholder {
            guard let sourceBackend = source.backendID,
                  let targetBackend = adminSeasons[targetIndex].backendID else {
                throw AdminStoreError.entityNotFound
            }
            _ = try await backend.duplicateAdminSeasonRoster(
                targetSeasonID: targetBackend,
                request: DuplicateSeasonRosterRequest(sourceSeasonID: sourceBackend)
            )
        }

        adminSeasons[targetIndex].playerCount = source.playerCount
        adminSeasons[targetIndex].trainerCount = source.trainerCount
        adminSeasons[targetIndex].updatedAt = Date()
        appendAdminAudit(
            area: .seasons,
            action: "Kader übernommen",
            actorName: currentAdminActorName(),
            targetName: adminSeasons[targetIndex].name,
            details: "Bestand aus \(source.name) übernommen."
        )
    }

    func saveAdminClubSettings(_ settings: AdminClubSettings) async throws {
        if AppConfiguration.isPlaceholder {
            adminClubSettings = settings
            appendAdminAudit(
                area: .settings,
                action: "Vereinseinstellungen geändert",
                actorName: currentAdminActorName(),
                targetName: settings.clubName,
                details: "Standardwerte aktualisiert."
            )
            return
        }

        let dto = try await backend.saveAdminClubSettings(
            UpsertAdminClubSettingsRequest(
                clubName: settings.clubName,
                clubLogoPath: settings.clubLogoPath,
                primaryColorHex: settings.primaryColorHex,
                secondaryColorHex: settings.secondaryColorHex,
                standardTrainingTypes: settings.standardTrainingTypes,
                defaultVisibility: settings.defaultVisibility,
                teamNameConvention: settings.teamNameConvention,
                globalPermissions: settings.globalPermissions.map(\.rawValue)
            )
        )
        adminClubSettings = mapAdminClubSettings(dto)
        appendAdminAudit(
            area: .settings,
            action: "Vereinseinstellungen geändert",
            actorName: currentAdminActorName(),
            targetName: adminClubSettings.clubName,
            details: "Serverseitig gespeichert."
        )
        motionUpdate(
            "Berechtigung aktualisiert",
            subtitle: adminClubSettings.clubName,
            scope: .verwaltung,
            icon: "building.2.crop.circle"
        )
    }

    func saveAdminMessengerRules(_ rules: AdminMessengerRules) async throws {
        if AppConfiguration.isPlaceholder {
            adminMessengerRules = rules
            appendAdminAudit(
                area: .messengerRules,
                action: "Messenger-Regeln geändert",
                actorName: currentAdminActorName(),
                targetName: "Messenger",
                details: rules.groupRuleDescription
            )
            return
        }

        let dto = try await backend.saveAdminMessengerRules(
            UpsertAdminMessengerRulesRequest(
                allowPrivatePlayerChat: rules.allowPrivatePlayerChat,
                allowDirectTrainerPlayerChat: rules.allowDirectTrainerPlayerChat,
                defaultReadOnlyForPlayers: rules.defaultReadOnlyForPlayers,
                defaultGroups: rules.defaultGroups,
                allowedChatTypes: rules.allowedChatTypes,
                groupRuleDescription: rules.groupRuleDescription
            )
        )
        adminMessengerRules = mapAdminMessengerRules(dto)
        appendAdminAudit(
            area: .messengerRules,
            action: "Messenger-Regeln geändert",
            actorName: currentAdminActorName(),
            targetName: "Messenger",
            details: rules.groupRuleDescription
        )
        motionUpdate(
            "Berechtigung aktualisiert",
            subtitle: "Messenger-Regeln übernommen",
            scope: .verwaltung,
            icon: "checkmark.shield"
        )
    }

    func loadAdminAuditEntries(filter: AdminAuditFilter, cursor: String? = nil, limit: Int = 120) async {
        if AppConfiguration.isPlaceholder {
            let filtered = adminAuditEntries.filter { entry in
                if !filter.personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let needle = filter.personName.lowercased()
                    if !entry.actorName.lowercased().contains(needle) &&
                        !entry.targetName.lowercased().contains(needle) {
                        return false
                    }
                }
                if let area = filter.area, entry.area != area {
                    return false
                }
                if let from = filter.from, entry.timestamp < from {
                    return false
                }
                if let to = filter.to, entry.timestamp > to {
                    return false
                }
                return true
            }
            adminAuditEntries = filtered.sorted { $0.timestamp > $1.timestamp }
            return
        }

        do {
            let page = try await backend.fetchAdminAuditLogs(
                cursor: cursor,
                limit: limit,
                personName: filter.personName.isEmpty ? nil : filter.personName,
                area: filter.area?.rawValue,
                from: filter.from,
                to: filter.to
            )
            adminAuditEntries = page.items.map(mapAdminAuditEntry(dto:))
        } catch {
            adminConnectionState = .failed(error.localizedDescription)
        }
    }

    func refreshMessengerDirectoryFromAdminProfiles() {
        syncAdminPersonsToMessengerDirectory()
    }
}

private extension AppDataStore {
    func currentAdminActorName() -> String {
        messengerCurrentUser?.displayName ?? profile.name
    }

    func applyAdminBootstrap(_ bootstrap: AdminBootstrapDTO) {
        let existingPersonsByBackend = Dictionary(uniqueKeysWithValues: adminPersons.compactMap { person in
            person.backendID.map { ($0, person) }
        })
        var persons = bootstrap.persons.map { dto in
            mapAdminPerson(dto, fallback: existingPersonsByBackend[dto.id])
        }

        let existingGroupsByBackend = Dictionary(uniqueKeysWithValues: adminGroups.compactMap { group in
            group.backendID.map { ($0, group.id) }
        })
        var groups = bootstrap.groups.map { dto in
            mapAdminGroup(dto: dto, existingLocalID: existingGroupsByBackend[dto.id])
        }

        var backendToPersonID: [String: UUID] = [:]
        for person in persons {
            if let backendID = person.backendID {
                backendToPersonID[backendID] = person.id
            }
        }

        var backendToGroupID: [String: UUID] = [:]
        for group in groups {
            if let backendID = group.backendID {
                backendToGroupID[backendID] = group.id
            }
        }

        for index in groups.indices {
            let source = bootstrap.groups[index]
            groups[index].memberIDs = source.memberIDs.compactMap { backendToPersonID[$0] }
            groups[index].responsibleCoachID = source.responsibleCoachID.flatMap { backendToPersonID[$0] }
            groups[index].assistantCoachID = source.assistantCoachID.flatMap { backendToPersonID[$0] }
        }

        for index in persons.indices {
            let source = bootstrap.persons[index]
            persons[index].groupIDs = source.groupIDs.compactMap { backendToGroupID[$0] }
        }

        adminPersons = persons
        adminGroups = groups
        adminInvitations = bootstrap.invitations.map { mapAdminInvitation($0) }
        adminAuditEntries = bootstrap.auditEntries.map(mapAdminAuditEntry(dto:))
            .sorted { $0.timestamp > $1.timestamp }
        let existingSeasonsByBackend = Dictionary(uniqueKeysWithValues: adminSeasons.compactMap { season in
            season.backendID.map { ($0, season) }
        })
        adminSeasons = bootstrap.seasons.map { dto in
            mapAdminSeason(dto, fallback: existingSeasonsByBackend[dto.id])
        }
        activeAdminSeasonID = bootstrap.activeSeasonID.flatMap { backendID in
            adminSeasons.first(where: { $0.backendID == backendID })?.id
        } ?? adminSeasons.first(where: { $0.status == .active })?.id
        adminClubSettings = mapAdminClubSettings(bootstrap.clubSettings)
        adminMessengerRules = mapAdminMessengerRules(bootstrap.messengerRules)

        syncPlayerDataWithAdminPersons()
        syncAdminPersonsToMessengerDirectory()
        seedProfilesFromCurrentStateIfNeeded(forceRebuild: true)
    }

    func syncPlayerDataWithAdminPersons() {
        for person in adminPersons where person.personType == .player {
            guard let linkedPlayerID = person.linkedPlayerID,
                  let index = players.firstIndex(where: { $0.id == linkedPlayerID }) else {
                continue
            }
            players[index].name = person.fullName
            players[index].teamName = person.teamName
            players[index].groups = person.groupIDs.compactMap { groupID in
                adminGroups.first(where: { $0.id == groupID })?.name
            }
            players[index].availability = person.presenceStatus == .away ? .unavailable : players[index].availability
        }
    }

    func syncPlayerWithAdminPerson(_ person: AdminPerson) {
        guard person.personType == .player else { return }

        if let linkedPlayerID = person.linkedPlayerID,
           let playerIndex = players.firstIndex(where: { $0.id == linkedPlayerID }) {
            players[playerIndex].name = person.fullName
            players[playerIndex].teamName = person.teamName
            players[playerIndex].groups = person.groupIDs.compactMap { groupID in
                adminGroups.first(where: { $0.id == groupID })?.name
            }
            players[playerIndex].availability = person.presenceStatus == .away ? .unavailable : players[playerIndex].availability
            syncProfileFromAdminPerson(person)
            return
        }

        let nextNumber = (players.map(\.number).max() ?? 0) + 1
        let newPlayer = Player(
            id: person.linkedPlayerID ?? UUID(),
            name: person.fullName,
            number: nextNumber,
            position: "ZM",
            status: person.presenceStatus == .away ? .unavailable : .fit,
            teamName: person.teamName,
            squadStatus: .active,
            roles: [],
            groups: person.groupIDs.compactMap { groupID in
                adminGroups.first(where: { $0.id == groupID })?.name
            },
            injuryStatus: "",
            notes: "",
            developmentGoals: ""
        )
        players.append(newPlayer)
        syncProfileFromAdminPerson(person)
    }

    func syncAdminPersonsToMessengerDirectory() {
        let existing = Dictionary(uniqueKeysWithValues: messengerUserDirectory.map { ($0.backendUserID, $0) })
        let mapped: [MessengerParticipant] = adminPersons.compactMap { person in
            let backendUserID = person.linkedMessengerUserID ?? person.backendID ?? "admin.user.\(person.id.uuidString.lowercased())"
            let base = existing[backendUserID]
            return MessengerParticipant(
                id: base?.id ?? UUID(),
                backendUserID: backendUserID,
                displayName: person.fullName,
                role: person.personType == .trainer ? .trainer : .player,
                playerID: person.linkedPlayerID,
                mutedUntil: base?.mutedUntil,
                canWrite: person.personType == .trainer || adminMessengerRules.allowPrivatePlayerChat,
                joinedAt: base?.joinedAt ?? person.createdAt
            )
        }
        messengerUserDirectory = mapped.sorted { $0.displayName < $1.displayName }
    }

    func reconcilePersonGroupMemberships() {
        var groupsByPersonID: [UUID: Set<UUID>] = [:]
        for group in adminGroups {
            for personID in group.memberIDs {
                groupsByPersonID[personID, default: []].insert(group.id)
            }
        }

        for index in adminPersons.indices {
            adminPersons[index].groupIDs = Array(groupsByPersonID[adminPersons[index].id] ?? [])
            adminPersons[index].updatedAt = Date()
            syncPlayerWithAdminPerson(adminPersons[index])
        }
    }

    func upsertLocalAdminPerson(_ person: AdminPerson) {
        if let index = adminPersons.firstIndex(where: { $0.id == person.id }) {
            adminPersons[index] = person
        } else if let backendID = person.backendID,
                  let index = adminPersons.firstIndex(where: { $0.backendID == backendID }) {
            adminPersons[index] = person
        } else {
            adminPersons.append(person)
        }
        adminPersons.sort { $0.fullName < $1.fullName }
    }

    func upsertLocalAdminGroup(_ group: AdminGroup) {
        if let index = adminGroups.firstIndex(where: { $0.id == group.id }) {
            adminGroups[index] = group
        } else if let backendID = group.backendID,
                  let index = adminGroups.firstIndex(where: { $0.backendID == backendID }) {
            adminGroups[index] = group
        } else {
            adminGroups.append(group)
        }
        adminGroups.sort { $0.name < $1.name }
    }

    func upsertLocalAdminSeason(_ season: AdminSeason) {
        if let index = adminSeasons.firstIndex(where: { $0.id == season.id }) {
            adminSeasons[index] = season
        } else if let backendID = season.backendID,
                  let index = adminSeasons.firstIndex(where: { $0.backendID == backendID }) {
            adminSeasons[index] = season
        } else {
            adminSeasons.append(season)
        }
        adminSeasons.sort { $0.startsAt > $1.startsAt }
    }

    func appendAdminAudit(
        area: AdminAuditArea,
        action: String,
        actorName: String,
        targetName: String,
        details: String
    ) {
        let entry = AdminAuditEntry(
            backendID: AppConfiguration.isPlaceholder ? nil : "local.audit.\(UUID().uuidString.lowercased())",
            actorName: actorName,
            targetName: targetName,
            area: area,
            action: action,
            details: details
        )
        adminAuditEntries.insert(entry, at: 0)
    }

    func normalizeAdminPerson(_ person: AdminPerson) -> AdminPerson {
        var value = person
        value.fullName = value.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        value.email = value.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        value.teamName = value.teamName.trimmingCharacters(in: .whitespacesAndNewlines)
        value.updatedAt = Date()
        if value.backendID == nil {
            value.backendID = "local.admin.person.\(value.id.uuidString.lowercased())"
        }
        if value.personType == .trainer && value.permissions.isEmpty {
            value.permissions = [.trainingCreate, .trainingEdit]
        }
        return value
    }

    func normalizeAdminGroup(_ group: AdminGroup) -> AdminGroup {
        var value = group
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.goal = value.goal.trimmingCharacters(in: .whitespacesAndNewlines)
        value.updatedAt = Date()
        if value.backendID == nil {
            value.backendID = "local.admin.group.\(value.id.uuidString.lowercased())"
        }
        return value
    }

    func normalizeAdminInvitation(_ invitation: AdminInvitation) -> AdminInvitation {
        var value = invitation
        value.recipientName = value.recipientName.trimmingCharacters(in: .whitespacesAndNewlines)
        value.email = value.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        value.updatedAt = Date()
        if value.backendID == nil {
            value.backendID = "local.admin.invitation.\(value.id.uuidString.lowercased())"
        }
        return value
    }

    func normalizeAdminSeason(_ season: AdminSeason) -> AdminSeason {
        var value = season
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.updatedAt = Date()
        if value.backendID == nil {
            value.backendID = "local.admin.season.\(value.id.uuidString.lowercased())"
        }
        return value
    }

    func makeUpsertAdminPersonRequest(_ person: AdminPerson) -> UpsertAdminPersonRequest {
        let groupBackendIDs = person.groupIDs.compactMap { groupID in
            adminGroups.first(where: { $0.id == groupID })?.backendID
        }
        return UpsertAdminPersonRequest(
            id: person.backendID,
            fullName: person.fullName,
            email: person.email,
            personType: person.personType.rawValue,
            role: person.role?.rawValue,
            teamName: person.teamName,
            groupIDs: groupBackendIDs,
            permissions: person.permissions.map(\.rawValue),
            presenceStatus: person.presenceStatus.rawValue,
            linkedPlayerID: person.linkedPlayerID
        )
    }

    func makeUpsertAdminGroupRequest(_ group: AdminGroup) -> UpsertAdminGroupRequest {
        let memberBackendIDs = group.memberIDs.compactMap { personID in
            adminPersons.first(where: { $0.id == personID })?.backendID
        }
        return UpsertAdminGroupRequest(
            id: group.backendID,
            name: group.name,
            goal: group.goal,
            groupType: group.groupType.rawValue,
            memberIDs: memberBackendIDs,
            responsibleCoachID: group.responsibleCoachID.flatMap { id in
                adminPersons.first(where: { $0.id == id })?.backendID
            },
            assistantCoachID: group.assistantCoachID.flatMap { id in
                adminPersons.first(where: { $0.id == id })?.backendID
            },
            startsAt: group.startsAt,
            endsAt: group.endsAt
        )
    }

    func mapAdminPerson(_ dto: AdminPersonDTO, fallback: AdminPerson?) -> AdminPerson {
        AdminPerson(
            id: fallback?.id ?? UUID(),
            backendID: dto.id,
            fullName: dto.fullName,
            email: dto.email,
            personType: AdminPersonType(rawValue: dto.personType) ?? .player,
            role: dto.role.flatMap { AdminRole(rawValue: $0) },
            teamName: dto.teamName,
            groupIDs: [],
            permissions: Set(dto.permissions.compactMap { AdminPermission(rawValue: $0) }),
            presenceStatus: AdminPresenceStatus(rawValue: dto.presenceStatus) ?? .active,
            isOnline: dto.isOnline,
            linkedPlayerID: dto.linkedPlayerID,
            linkedMessengerUserID: dto.linkedMessengerUserID,
            lastActiveAt: dto.lastActiveAt,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    func mapAdminGroup(dto: AdminGroupDTO, existingLocalID: UUID? = nil) -> AdminGroup {
        let memberIDs = dto.memberIDs.compactMap { backendID in
            adminPersons.first(where: { $0.backendID == backendID })?.id
        }
        let responsibleCoachID = dto.responsibleCoachID.flatMap { backendID in
            adminPersons.first(where: { $0.backendID == backendID })?.id
        }
        let assistantCoachID = dto.assistantCoachID.flatMap { backendID in
            adminPersons.first(where: { $0.backendID == backendID })?.id
        }
        return AdminGroup(
            id: existingLocalID ?? UUID(),
            backendID: dto.id,
            name: dto.name,
            goal: dto.goal,
            groupType: AdminGroupType(rawValue: dto.groupType) ?? .permanent,
            memberIDs: memberIDs,
            responsibleCoachID: responsibleCoachID,
            assistantCoachID: assistantCoachID,
            startsAt: dto.startsAt,
            endsAt: dto.endsAt,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    func mapAdminInvitation(_ dto: AdminInvitationDTO, fallback: AdminInvitation? = nil) -> AdminInvitation {
        AdminInvitation(
            id: fallback?.id ?? UUID(),
            backendID: dto.id,
            recipientName: dto.recipientName,
            email: dto.email,
            method: AdminInvitationMethod(rawValue: dto.method) ?? .email,
            role: AdminRole(rawValue: dto.role) ?? .coTrainer,
            teamName: dto.teamName,
            status: AdminInvitationStatus(rawValue: dto.status) ?? .open,
            inviteLink: dto.inviteLink,
            sentBy: dto.sentBy,
            sentAt: dto.sentAt,
            expiresAt: dto.expiresAt,
            updatedAt: dto.updatedAt
        )
    }

    func mapAdminAuditEntry(dto: AdminAuditEntryDTO) -> AdminAuditEntry {
        AdminAuditEntry(
            backendID: dto.id,
            actorName: dto.actorName,
            targetName: dto.targetName,
            area: AdminAuditArea(rawValue: dto.area) ?? .users,
            action: dto.action,
            details: dto.details,
            timestamp: dto.timestamp
        )
    }

    func mapAdminSeason(_ dto: AdminSeasonDTO, fallback: AdminSeason?) -> AdminSeason {
        AdminSeason(
            id: fallback?.id ?? UUID(),
            backendID: dto.id,
            name: dto.name,
            startsAt: dto.startsAt,
            endsAt: dto.endsAt,
            status: AdminSeasonStatus(rawValue: dto.status) ?? .locked,
            teamCount: dto.teamCount,
            playerCount: dto.playerCount,
            trainerCount: dto.trainerCount,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    func mapAdminClubSettings(_ dto: AdminClubSettingsDTO) -> AdminClubSettings {
        AdminClubSettings(
            backendID: dto.id,
            clubName: dto.clubName,
            clubLogoPath: dto.clubLogoPath,
            primaryColorHex: dto.primaryColorHex,
            secondaryColorHex: dto.secondaryColorHex,
            standardTrainingTypes: dto.standardTrainingTypes,
            defaultVisibility: dto.defaultVisibility,
            teamNameConvention: dto.teamNameConvention,
            globalPermissions: Set(dto.globalPermissions.compactMap { AdminPermission(rawValue: $0) })
        )
    }

    func mapAdminMessengerRules(_ dto: AdminMessengerRulesDTO) -> AdminMessengerRules {
        AdminMessengerRules(
            backendID: dto.id,
            allowPrivatePlayerChat: dto.allowPrivatePlayerChat,
            allowDirectTrainerPlayerChat: dto.allowDirectTrainerPlayerChat,
            defaultReadOnlyForPlayers: dto.defaultReadOnlyForPlayers,
            defaultGroups: dto.defaultGroups,
            allowedChatTypes: dto.allowedChatTypes,
            groupRuleDescription: dto.groupRuleDescription
        )
    }
}

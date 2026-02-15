import Foundation

@MainActor
extension AppDataStore {
    func bootstrapProfiles() async {
        profileConnectionState = .syncing
        do {
            let profileDTOs = try await backend.fetchPersonProfiles()
            personProfiles = profileDTOs.map { mapPersonProfile($0) }.sorted { $0.displayName < $1.displayName }
            if personProfiles.isEmpty {
                seedProfilesFromCurrentStateIfNeeded()
                ensureCurrentUserProfileExists()
            }
            // Always re-evaluate preferred selection (seeding may have added the
            // user profile after activePersonProfileID was already set to a player).
            activePersonProfileID = preferredProfileSelection()?.id
            profileConnectionState = .live
        } catch {
            if isConnectivityFailure(error) {
                profileConnectionState = .failed(error.localizedDescription)
            } else {
                print("[client] bootstrapProfiles: endpoint not available — \(error.localizedDescription)")
                seedProfilesFromCurrentStateIfNeeded()
                ensureCurrentUserProfileExists()
                activePersonProfileID = preferredProfileSelection()?.id
                profileConnectionState = .live
            }
        }
    }

    func loadProfileAudit(profileID: UUID?) async {
        do {
            let backendID = profileID.flatMap { id in
                personProfiles.first(where: { $0.id == id })?.backendID
            }
            let items = try await backend.fetchProfileAudit(profileID: backendID)
            profileAuditEntries = items.map { mapProfileAuditEntry($0) }.sorted { $0.timestamp > $1.timestamp }
        } catch {
            profileConnectionState = .failed(error.localizedDescription)
        }
    }

    func upsertProfile(_ value: PersonProfile) async throws -> PersonProfile {
        let normalized = normalizeProfile(value)
        let previous = personProfiles.first(where: { $0.id == normalized.id })

        do {
            let request = makeUpsertProfileRequest(normalized)
            let dto = try await backend.upsertPersonProfile(request)
            let mapped = mapPersonProfile(dto, fallback: normalized)
            upsertLocalProfile(mapped)
            applyProfileToLinkedModules(mapped)
            appendProfileAudit(previous: previous, current: mapped, actorName: currentProfileActorName())
            profileConnectionState = .live
            return mapped
        } catch {
            profileConnectionState = .failed(error.localizedDescription)
            throw error
        }
    }

    func deleteProfile(_ profileID: UUID) async throws {
        guard let profileToDelete = personProfiles.first(where: { $0.id == profileID }) else { return }

        guard let backendID = profileToDelete.backendID else {
            throw ProfileStoreError.missingBackendID
        }
        do {
            _ = try await backend.deletePersonProfile(profileID: backendID)
            profileConnectionState = .live
        } catch {
            profileConnectionState = .failed(error.localizedDescription)
            throw error
        }

        personProfiles.removeAll { $0.id == profileID }
        profileAuditEntries.removeAll { $0.profileID == profileID }
        if activePersonProfileID == profileID {
            activePersonProfileID = preferredProfileSelection()?.id
        }
        syncLegacyCoachProfileFromProfiles()
    }

    func profile(with id: UUID) -> PersonProfile? {
        personProfiles.first(where: { $0.id == id })
    }

    func profile(forPlayerID playerID: UUID) -> PersonProfile? {
        personProfiles.first(where: { $0.linkedPlayerID == playerID })
    }

    func currentViewerProfile() -> PersonProfile? {
        // Email match is the strongest identity signal — always prefer the
        // profile that belongs to the authenticated user.
        if let email = currentAuthEmail?.lowercased(), !email.isEmpty,
           let matched = personProfiles.first(where: { $0.core.email.lowercased() == email }) {
            return matched
        }
        if let activePersonProfileID,
           let active = personProfiles.first(where: { $0.id == activePersonProfileID }) {
            return active
        }
        if let messengerUserID = messengerCurrentUser?.userID,
           let person = adminPersons.first(where: { $0.linkedMessengerUserID == messengerUserID }),
           let linked = personProfiles.first(where: { $0.linkedAdminPersonID == person.id }) {
            return linked
        }
        return preferredProfileSelection()
    }

    func seedProfilesFromCurrentStateIfNeeded(forceRebuild: Bool = false) {
        if !forceRebuild, !personProfiles.isEmpty {
            mergeMissingProfilesFromCurrentState()
            if activePersonProfileID == nil {
                activePersonProfileID = preferredProfileSelection()?.id
            }
            syncLegacyCoachProfileFromProfiles()
            return
        }

        var generated: [PersonProfile] = []
        let existingByAdmin = Dictionary(uniqueKeysWithValues: personProfiles.compactMap { profile in
            profile.linkedAdminPersonID.map { ($0, profile) }
        })
        let existingByPlayer = Dictionary(uniqueKeysWithValues: personProfiles.compactMap { profile in
            profile.linkedPlayerID.map { ($0, profile) }
        })

        for person in adminPersons {
            let source = existingByAdmin[person.id]
            let player = person.linkedPlayerID.flatMap { linkedID in
                players.first(where: { $0.id == linkedID })
            }
            let profile = buildProfileFromAdminPerson(person, player: player, previous: source)
            generated.append(profile)
        }

        for player in players where !generated.contains(where: { $0.linkedPlayerID == player.id }) {
            let source = existingByPlayer[player.id]
            generated.append(buildProfileFromPlayer(player, previous: source))
        }

        personProfiles = generated.sorted { $0.displayName < $1.displayName }
        activePersonProfileID = preferredProfileSelection()?.id
        syncLegacyCoachProfileFromProfiles()
    }

    func mergeMissingProfilesFromCurrentState() {
        guard !adminPersons.isEmpty || !players.isEmpty else { return }

        var mergedProfiles = personProfiles
        var adminIDs = Set(mergedProfiles.compactMap(\.linkedAdminPersonID))
        var playerIDs = Set(mergedProfiles.compactMap(\.linkedPlayerID))

        for person in adminPersons where !adminIDs.contains(person.id) {
            let linkedPlayer = person.linkedPlayerID.flatMap { linkedID in
                players.first(where: { $0.id == linkedID })
            }
            let profile = buildProfileFromAdminPerson(person, player: linkedPlayer, previous: nil)
            mergedProfiles.append(profile)
            adminIDs.insert(person.id)
            if let linkedPlayerID = profile.linkedPlayerID {
                playerIDs.insert(linkedPlayerID)
            }
        }

        for player in players where !playerIDs.contains(player.id) {
            let profile = buildProfileFromPlayer(player, previous: nil)
            mergedProfiles.append(profile)
            playerIDs.insert(player.id)
        }

        personProfiles = mergedProfiles.sorted { $0.displayName < $1.displayName }
        syncLegacyCoachProfileFromProfiles()
    }

    func syncProfileFromPlayerChange(_ player: Player) {
        if let existingIndex = personProfiles.firstIndex(where: { $0.linkedPlayerID == player.id }) {
            var profile = personProfiles[existingIndex]
            profile.core = applyPlayerToCore(player: player, core: profile.core)
            profile.player = applyPlayerToRole(player: player, existing: profile.player)
            profile.updatedAt = Date()
            personProfiles[existingIndex] = profile
        } else {
            personProfiles.append(buildProfileFromPlayer(player, previous: nil))
        }
        personProfiles.sort { $0.displayName < $1.displayName }
        syncLegacyCoachProfileFromProfiles()
    }

    func removeProfileLinkedToPlayer(_ playerID: UUID) {
        personProfiles.removeAll { $0.linkedPlayerID == playerID }
        if activePersonProfileID != nil && !personProfiles.contains(where: { $0.id == activePersonProfileID }) {
            activePersonProfileID = preferredProfileSelection()?.id
        }
        syncLegacyCoachProfileFromProfiles()
    }

    func syncProfileFromAdminPerson(_ person: AdminPerson) {
        let linkedPlayer = person.linkedPlayerID.flatMap { linkedID in
            players.first(where: { $0.id == linkedID })
        }
        if let index = personProfiles.firstIndex(where: { $0.linkedAdminPersonID == person.id }) {
            let previous = personProfiles[index]
            let updated = buildProfileFromAdminPerson(person, player: linkedPlayer, previous: previous)
            personProfiles[index] = updated
        } else {
            personProfiles.append(buildProfileFromAdminPerson(person, player: linkedPlayer, previous: nil))
        }
        personProfiles.sort { $0.displayName < $1.displayName }
        syncLegacyCoachProfileFromProfiles()
    }

    func removeProfileLinkedToAdminPerson(_ personID: UUID) {
        personProfiles.removeAll { $0.linkedAdminPersonID == personID }
        if activePersonProfileID != nil && !personProfiles.contains(where: { $0.id == activePersonProfileID }) {
            activePersonProfileID = preferredProfileSelection()?.id
        }
        syncLegacyCoachProfileFromProfiles()
    }

    func ensureCurrentUserProfileExists() {
        guard let email = currentAuthEmail?.lowercased(), !email.isEmpty else { return }
        guard !personProfiles.contains(where: { $0.core.email.lowercased() == email }) else { return }

        let firstName: String
        let lastName: String
        if let fn = currentAuthFirstName, !fn.isEmpty {
            firstName = fn
            lastName = currentAuthLastName ?? ""
        } else {
            let emailUser = email.components(separatedBy: "@").first ?? ""
            firstName = emailUser.prefix(1).uppercased() + emailUser.dropFirst()
            lastName = ""
        }

        let userProfile = PersonProfile(
            core: ProfileCoreData(
                avatarPath: nil,
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: nil,
                email: email,
                phone: nil,
                clubName: profile.team,
                roles: [.headCoach],
                isActive: true,
                internalNotes: ""
            ),
            headCoach: defaultHeadCoachData(),
            updatedBy: "System"
        )
        personProfiles.append(userProfile)
        personProfiles.sort { $0.displayName < $1.displayName }
    }
}

enum ProfileStoreError: LocalizedError {
    case missingBackendID

    var errorDescription: String? {
        switch self {
        case .missingBackendID:
            return "Server-ID fehlt für diese Aktion."
        }
    }
}

extension AppDataStore {
    func preferredProfileSelection() -> PersonProfile? {
        // Email match first — the logged-in user's own profile always wins.
        if let email = currentAuthEmail?.lowercased(), !email.isEmpty,
           let matched = personProfiles.first(where: { $0.core.email.lowercased() == email }) {
            return matched
        }
        if let activePersonProfileID,
           let active = personProfiles.first(where: { $0.id == activePersonProfileID }) {
            return active
        }
        if let messengerUserID = messengerCurrentUser?.userID,
           let person = adminPersons.first(where: { $0.linkedMessengerUserID == messengerUserID }),
           let linked = personProfiles.first(where: { $0.linkedAdminPersonID == person.id }) {
            return linked
        }
        if let headCoach = personProfiles.first(where: { $0.core.roles.contains(.headCoach) }) {
            return headCoach
        }
        if let trainer = personProfiles.first(where: { $0.core.roles.contains(where: { $0.isTrainerFamily }) }) {
            return trainer
        }
        return personProfiles.first
    }

    func currentProfileActorName() -> String {
        if let viewer = currentViewerProfile() {
            return viewer.displayName
        }
        return messengerCurrentUser?.displayName ?? profile.name
    }

    func normalizeProfile(_ value: PersonProfile) -> PersonProfile {
        var profile = value
        profile.core.firstName = profile.core.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.core.lastName = profile.core.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.core.email = profile.core.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        profile.core.phone = profile.core.phone?.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.core.clubName = profile.core.clubName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.core.internalNotes = profile.core.internalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.core.roles = Array(Set(profile.core.roles)).sorted { $0.title < $1.title }
        if profile.core.roles.isEmpty {
            profile.core.roles = [.player]
        }
        profile.updatedAt = Date()
        return profile
    }

    func upsertLocalProfile(_ profile: PersonProfile) {
        if let index = personProfiles.firstIndex(where: { $0.id == profile.id }) {
            personProfiles[index] = profile
        } else if let backendID = profile.backendID,
                  let index = personProfiles.firstIndex(where: { $0.backendID == backendID }) {
            personProfiles[index] = profile
        } else {
            personProfiles.append(profile)
        }
        personProfiles.sort { $0.displayName < $1.displayName }
        activePersonProfileID = profile.id
        syncLegacyCoachProfileFromProfiles()
    }

    func syncLegacyCoachProfileFromProfiles() {
        guard let source = preferredProfileSelection() else { return }
        let license = source.headCoach?.licenses.first
            ?? source.assistantCoach?.licenses.first
            ?? source.athleticCoach?.certifications.first
            ?? "Vereinsprofil"
        profile = CoachProfile(
            name: source.displayName,
            license: license,
            team: source.core.clubName.isEmpty ? profile.team : source.core.clubName,
            seasonGoal: source.player?.seasonGoals ?? source.headCoach?.personalGoals ?? profile.seasonGoal
        )
    }

    func buildProfileFromAdminPerson(
        _ person: AdminPerson,
        player: Player?,
        previous: PersonProfile?
    ) -> PersonProfile {
        let roleSet = profileRoles(for: person, player: player)
        let core = ProfileCoreData(
            avatarPath: previous?.core.avatarPath,
            firstName: splitName(person.fullName).first,
            lastName: splitName(person.fullName).last,
            dateOfBirth: previous?.core.dateOfBirth ?? player?.dateOfBirth,
            email: person.email,
            phone: previous?.core.phone,
            clubName: person.teamName,
            roles: roleSet,
            isActive: person.presenceStatus != .inactive,
            internalNotes: previous?.core.internalNotes ?? ""
        )

        return PersonProfile(
            id: previous?.id ?? UUID(),
            backendID: previous?.backendID,
            linkedPlayerID: person.linkedPlayerID ?? previous?.linkedPlayerID,
            linkedAdminPersonID: person.id,
            core: core,
            player: player.map { applyPlayerToRole(player: $0, existing: previous?.player) } ?? previous?.player,
            headCoach: roleSet.contains(.headCoach) ? (previous?.headCoach ?? defaultHeadCoachData()) : previous?.headCoach,
            assistantCoach: roleSet.contains(.assistantCoach) || roleSet.contains(.coachingStaff) || roleSet.contains(.analyst)
                ? (previous?.assistantCoach ?? defaultAssistantCoachData())
                : previous?.assistantCoach,
            athleticCoach: roleSet.contains(.athleticCoach) ? (previous?.athleticCoach ?? defaultAthleticCoachData()) : previous?.athleticCoach,
            medical: roleSet.contains(.physiotherapist) ? (previous?.medical ?? defaultMedicalData(teamName: person.teamName)) : previous?.medical,
            teamManager: roleSet.contains(.teamManager) || roleSet.contains(.boardMember)
                ? (previous?.teamManager ?? defaultTeamManagerData())
                : previous?.teamManager,
            board: roleSet.contains(.boardMember) ? (previous?.board ?? defaultBoardData()) : previous?.board,
            facility: roleSet.contains(.facilityManager) ? (previous?.facility ?? defaultFacilityData()) : previous?.facility,
            lockedFieldKeys: previous?.lockedFieldKeys ?? [],
            updatedAt: Date(),
            updatedBy: currentProfileActorName()
        )
    }

    func buildProfileFromPlayer(_ player: Player, previous: PersonProfile?) -> PersonProfile {
        let names = splitName(player.name)
        let core = ProfileCoreData(
            avatarPath: previous?.core.avatarPath,
            firstName: names.first,
            lastName: names.last,
            dateOfBirth: player.dateOfBirth,
            email: previous?.core.email ?? "",
            phone: previous?.core.phone,
            clubName: player.teamName,
            roles: [.player],
            isActive: player.availability != .unavailable,
            internalNotes: previous?.core.internalNotes ?? ""
        )
        return PersonProfile(
            id: previous?.id ?? UUID(),
            backendID: previous?.backendID,
            linkedPlayerID: player.id,
            linkedAdminPersonID: previous?.linkedAdminPersonID,
            core: core,
            player: applyPlayerToRole(player: player, existing: previous?.player),
            headCoach: previous?.headCoach,
            assistantCoach: previous?.assistantCoach,
            athleticCoach: previous?.athleticCoach,
            medical: previous?.medical,
            teamManager: previous?.teamManager,
            board: previous?.board,
            facility: previous?.facility,
            lockedFieldKeys: previous?.lockedFieldKeys ?? [],
            updatedAt: Date(),
            updatedBy: currentProfileActorName()
        )
    }

    func profileRoles(for person: AdminPerson, player: Player?) -> [ProfileRoleType] {
        var roles: Set<ProfileRoleType> = []
        if person.personType == .player {
            roles.insert(.player)
        }
        if player != nil {
            roles.insert(.player)
        }
        switch person.role {
        case .chefTrainer:
            roles.insert(.headCoach)
        case .coTrainer:
            roles.insert(.assistantCoach)
            roles.insert(.coachingStaff)
        case .analyst:
            roles.insert(.analyst)
            roles.insert(.coachingStaff)
        case .teamManager:
            roles.insert(.teamManager)
        case .medicalStaff:
            roles.insert(.physiotherapist)
        case .none:
            if person.personType == .trainer {
                roles.insert(.coachingStaff)
            }
        }
        if roles.isEmpty {
            roles.insert(person.personType == .player ? .player : .coachingStaff)
        }
        return roles.sorted { $0.title < $1.title }
    }

    func splitName(_ fullName: String) -> (first: String, last: String) {
        let components = fullName
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let first = components.first else {
            return ("", "")
        }
        guard components.count > 1 else {
            return (first, "")
        }
        return (first, components.dropFirst().joined(separator: " "))
    }

    func applyPlayerToCore(player: Player, core: ProfileCoreData) -> ProfileCoreData {
        var updated = core
        let names = splitName(player.name)
        updated.firstName = names.first
        updated.lastName = names.last
        updated.dateOfBirth = player.dateOfBirth
        updated.clubName = player.teamName
        updated.isActive = player.availability != .unavailable
        if !updated.roles.contains(.player) {
            updated.roles.append(.player)
        }
        return updated
    }

    func applyPlayerToRole(player: Player, existing: PlayerRoleProfileData?) -> PlayerRoleProfileData {
        var value = existing ?? PlayerRoleProfileData(
            primaryPosition: player.primaryPosition,
            secondaryPositions: player.secondaryPositions,
            jerseyNumber: player.number,
            heightCm: player.heightCm,
            weightKg: player.weightKg,
            preferredFoot: player.preferredFoot,
            preferredSystemRole: "",
            seasonGoals: player.developmentGoals,
            longTermGoals: "",
            pathway: "",
            loadCapacity: player.availability == .fit ? .free : (player.availability == .limited ? .limited : .individual),
            injuryHistory: player.injuryStatus,
            availability: player.availability
        )
        value.primaryPosition = player.primaryPosition
        value.secondaryPositions = player.secondaryPositions
        value.jerseyNumber = player.number
        value.heightCm = player.heightCm
        value.weightKg = player.weightKg
        value.preferredFoot = player.preferredFoot
        if value.seasonGoals.isEmpty {
            value.seasonGoals = player.developmentGoals
        }
        value.injuryHistory = player.injuryStatus
        value.availability = player.availability
        return value
    }

    func defaultHeadCoachData() -> HeadCoachProfileData {
        HeadCoachProfileData(
            licenses: [],
            education: [],
            careerPath: [],
            preferredSystems: [],
            matchPhilosophy: "",
            trainingPhilosophy: "",
            personalGoals: "",
            responsibilities: [],
            isPrimaryContact: true
        )
    }

    func defaultAssistantCoachData() -> AssistantCoachProfileData {
        AssistantCoachProfileData(
            licenses: [],
            focusAreas: [],
            operationalFocus: "",
            groupResponsibilities: [],
            trainingInvolvement: ""
        )
    }

    func defaultAthleticCoachData() -> AthleticCoachProfileData {
        AthleticCoachProfileData(
            certifications: [],
            focusAreas: [],
            ageGroupExperience: [],
            planningInvolvement: "",
            groupResponsibilities: []
        )
    }

    func defaultMedicalData(teamName: String) -> MedicalProfileData {
        MedicalProfileData(
            education: [],
            additionalQualifications: [],
            specialties: [],
            assignedTeams: [teamName],
            organizationalAvailability: "",
            protectedInternalNotes: ""
        )
    }

    func defaultTeamManagerData() -> TeamManagerProfileData {
        TeamManagerProfileData(
            clubFunction: "",
            responsibilities: [],
            operationalTasks: [],
            communicationOwnership: "",
            internalAvailability: ""
        )
    }

    func defaultBoardData() -> BoardProfileData {
        BoardProfileData(
            boardFunction: "",
            termStart: nil,
            termEnd: nil,
            responsibilityAreas: [],
            contactOptions: []
        )
    }

    func defaultFacilityData() -> FacilityProfileData {
        FacilityProfileData(
            responsibilities: [],
            facilities: [],
            availability: ""
        )
    }

    func applyProfileToLinkedModules(_ profile: PersonProfile) {
        if let playerID = profile.linkedPlayerID,
           let index = players.firstIndex(where: { $0.id == playerID }) {
            players[index].name = profile.displayName
            players[index].dateOfBirth = profile.core.dateOfBirth
            players[index].teamName = profile.core.clubName

            if let playerRole = profile.player {
                players[index].primaryPosition = playerRole.primaryPosition
                players[index].secondaryPositions = playerRole.secondaryPositions
                if let number = playerRole.jerseyNumber {
                    players[index].number = number
                }
                players[index].heightCm = playerRole.heightCm
                players[index].weightKg = playerRole.weightKg
                players[index].preferredFoot = playerRole.preferredFoot
                players[index].developmentGoals = [playerRole.seasonGoals, playerRole.longTermGoals]
                    .filter { !$0.isEmpty }
                    .joined(separator: " | ")
                players[index].injuryStatus = playerRole.injuryHistory
                players[index].availability = playerRole.availability
            }
        }

        if let adminID = profile.linkedAdminPersonID,
           let adminIndex = adminPersons.firstIndex(where: { $0.id == adminID }) {
            adminPersons[adminIndex].fullName = profile.displayName
            adminPersons[adminIndex].email = profile.core.email
            adminPersons[adminIndex].teamName = profile.core.clubName
            adminPersons[adminIndex].presenceStatus = profile.core.isActive ? .active : .inactive
            adminPersons[adminIndex].role = mapProfileRolesToAdminRole(profile.core.roles)
            adminPersons[adminIndex].updatedAt = Date()
        }

        refreshMessengerDirectoryFromAdminProfiles()
        syncLegacyCoachProfileFromProfiles()
    }

    func mapProfileRolesToAdminRole(_ roles: [ProfileRoleType]) -> AdminRole? {
        if roles.contains(.headCoach) {
            return .chefTrainer
        }
        if roles.contains(.assistantCoach) || roles.contains(.athleticCoach) || roles.contains(.coachingStaff) {
            return .coTrainer
        }
        if roles.contains(.analyst) {
            return .analyst
        }
        if roles.contains(.physiotherapist) {
            return .medicalStaff
        }
        if roles.contains(.teamManager) || roles.contains(.boardMember) || roles.contains(.facilityManager) {
            return .teamManager
        }
        return nil
    }

    func appendProfileAudit(previous: PersonProfile?, current: PersonProfile, actorName: String) {
        guard let previous else {
            profileAuditEntries.insert(
                ProfileAuditEntry(
                    profileID: current.id,
                    actorName: actorName,
                    fieldPath: "profil",
                    area: .core,
                    oldValue: "-",
                    newValue: "Profil erstellt"
                ),
                at: 0
            )
            return
        }

        if previous.core.displayName != current.core.displayName {
            profileAuditEntries.insert(
                ProfileAuditEntry(
                    profileID: current.id,
                    actorName: actorName,
                    fieldPath: "core.displayName",
                    area: .core,
                    oldValue: previous.core.displayName,
                    newValue: current.core.displayName
                ),
                at: 0
            )
        }

        if previous.core.roles != current.core.roles {
            profileAuditEntries.insert(
                ProfileAuditEntry(
                    profileID: current.id,
                    actorName: actorName,
                    fieldPath: "core.roles",
                    area: .role,
                    oldValue: previous.core.roles.map(\.title).joined(separator: ", "),
                    newValue: current.core.roles.map(\.title).joined(separator: ", ")
                ),
                at: 0
            )
        }

        if previous.core.internalNotes != current.core.internalNotes {
            profileAuditEntries.insert(
                ProfileAuditEntry(
                    profileID: current.id,
                    actorName: actorName,
                    fieldPath: "core.internalNotes",
                    area: .permissions,
                    oldValue: previous.core.internalNotes,
                    newValue: current.core.internalNotes
                ),
                at: 0
            )
        }

        if previous.player?.injuryHistory != current.player?.injuryHistory {
            profileAuditEntries.insert(
                ProfileAuditEntry(
                    profileID: current.id,
                    actorName: actorName,
                    fieldPath: "player.injuryHistory",
                    area: .medical,
                    oldValue: previous.player?.injuryHistory ?? "-",
                    newValue: current.player?.injuryHistory ?? "-"
                ),
                at: 0
            )
        }
    }

    func makeUpsertProfileRequest(_ profile: PersonProfile) -> UpsertPersonProfileRequest {
        UpsertPersonProfileRequest(
            id: profile.backendID,
            linkedPlayerID: profile.linkedPlayerID,
            linkedAdminPersonID: profile.linkedAdminPersonID,
            core: ProfileCoreDTO(
                avatarPath: profile.core.avatarPath,
                firstName: profile.core.firstName,
                lastName: profile.core.lastName,
                dateOfBirth: profile.core.dateOfBirth,
                email: profile.core.email,
                phone: profile.core.phone,
                clubName: profile.core.clubName,
                roles: profile.core.roles.map(\.rawValue),
                isActive: profile.core.isActive,
                internalNotes: profile.core.internalNotes
            ),
            player: profile.player.map {
                PlayerRoleProfileDTO(
                    primaryPosition: $0.primaryPosition.rawValue,
                    secondaryPositions: $0.secondaryPositions.map(\.rawValue),
                    jerseyNumber: $0.jerseyNumber,
                    heightCm: $0.heightCm,
                    weightKg: $0.weightKg,
                    preferredFoot: $0.preferredFoot?.rawValue,
                    preferredSystemRole: $0.preferredSystemRole,
                    seasonGoals: $0.seasonGoals,
                    longTermGoals: $0.longTermGoals,
                    pathway: $0.pathway,
                    loadCapacity: $0.loadCapacity.rawValue,
                    injuryHistory: $0.injuryHistory,
                    availability: $0.availability.rawValue
                )
            },
            headCoach: profile.headCoach.map {
                HeadCoachProfileDTO(
                    licenses: $0.licenses,
                    education: $0.education,
                    careerPath: $0.careerPath,
                    preferredSystems: $0.preferredSystems,
                    matchPhilosophy: $0.matchPhilosophy,
                    trainingPhilosophy: $0.trainingPhilosophy,
                    personalGoals: $0.personalGoals,
                    responsibilities: $0.responsibilities,
                    isPrimaryContact: $0.isPrimaryContact
                )
            },
            assistantCoach: profile.assistantCoach.map {
                AssistantCoachProfileDTO(
                    licenses: $0.licenses,
                    focusAreas: $0.focusAreas,
                    operationalFocus: $0.operationalFocus,
                    groupResponsibilities: $0.groupResponsibilities,
                    trainingInvolvement: $0.trainingInvolvement
                )
            },
            athleticCoach: profile.athleticCoach.map {
                AthleticCoachProfileDTO(
                    certifications: $0.certifications,
                    focusAreas: $0.focusAreas,
                    ageGroupExperience: $0.ageGroupExperience,
                    planningInvolvement: $0.planningInvolvement,
                    groupResponsibilities: $0.groupResponsibilities
                )
            },
            medical: profile.medical.map {
                MedicalProfileDTO(
                    education: $0.education,
                    additionalQualifications: $0.additionalQualifications,
                    specialties: $0.specialties,
                    assignedTeams: $0.assignedTeams,
                    organizationalAvailability: $0.organizationalAvailability,
                    protectedInternalNotes: $0.protectedInternalNotes
                )
            },
            teamManager: profile.teamManager.map {
                TeamManagerProfileDTO(
                    clubFunction: $0.clubFunction,
                    responsibilities: $0.responsibilities,
                    operationalTasks: $0.operationalTasks,
                    communicationOwnership: $0.communicationOwnership,
                    internalAvailability: $0.internalAvailability
                )
            },
            board: profile.board.map {
                BoardProfileDTO(
                    boardFunction: $0.boardFunction,
                    termStart: $0.termStart,
                    termEnd: $0.termEnd,
                    responsibilityAreas: $0.responsibilityAreas,
                    contactOptions: $0.contactOptions
                )
            },
            facility: profile.facility.map {
                FacilityProfileDTO(
                    responsibilities: $0.responsibilities,
                    facilities: $0.facilities,
                    availability: $0.availability
                )
            },
            lockedFieldKeys: Array(profile.lockedFieldKeys)
        )
    }

    func mapPersonProfile(_ dto: PersonProfileDTO, fallback: PersonProfile? = nil) -> PersonProfile {
        let localID = fallback?.id ?? personProfiles.first(where: { $0.backendID == dto.id })?.id ?? UUID()
        return PersonProfile(
            id: localID,
            backendID: dto.id,
            linkedPlayerID: dto.linkedPlayerID,
            linkedAdminPersonID: dto.linkedAdminPersonID,
            core: ProfileCoreData(
                avatarPath: dto.core.avatarPath,
                firstName: dto.core.firstName,
                lastName: dto.core.lastName,
                dateOfBirth: dto.core.dateOfBirth,
                email: dto.core.email,
                phone: dto.core.phone,
                clubName: dto.core.clubName,
                roles: dto.core.roles.compactMap { ProfileRoleType(rawValue: $0) },
                isActive: dto.core.isActive,
                internalNotes: dto.core.internalNotes
            ),
            player: dto.player.map {
                PlayerRoleProfileData(
                    primaryPosition: PlayerPosition.from(code: $0.primaryPosition),
                    secondaryPositions: $0.secondaryPositions.map(PlayerPosition.from(code:)),
                    jerseyNumber: $0.jerseyNumber,
                    heightCm: $0.heightCm,
                    weightKg: $0.weightKg,
                    preferredFoot: preferredFoot(from: $0.preferredFoot),
                    preferredSystemRole: $0.preferredSystemRole,
                    seasonGoals: $0.seasonGoals,
                    longTermGoals: $0.longTermGoals,
                    pathway: $0.pathway,
                    loadCapacity: ProfilePlayerLoadCapacity(rawValue: $0.loadCapacity) ?? .free,
                    injuryHistory: $0.injuryHistory,
                    availability: AvailabilityStatus(rawValue: $0.availability) ?? .fit
                )
            },
            headCoach: dto.headCoach.map {
                HeadCoachProfileData(
                    licenses: $0.licenses,
                    education: $0.education,
                    careerPath: $0.careerPath,
                    preferredSystems: $0.preferredSystems,
                    matchPhilosophy: $0.matchPhilosophy,
                    trainingPhilosophy: $0.trainingPhilosophy,
                    personalGoals: $0.personalGoals,
                    responsibilities: $0.responsibilities,
                    isPrimaryContact: $0.isPrimaryContact
                )
            },
            assistantCoach: dto.assistantCoach.map {
                AssistantCoachProfileData(
                    licenses: $0.licenses,
                    focusAreas: $0.focusAreas,
                    operationalFocus: $0.operationalFocus,
                    groupResponsibilities: $0.groupResponsibilities,
                    trainingInvolvement: $0.trainingInvolvement
                )
            },
            athleticCoach: dto.athleticCoach.map {
                AthleticCoachProfileData(
                    certifications: $0.certifications,
                    focusAreas: $0.focusAreas,
                    ageGroupExperience: $0.ageGroupExperience,
                    planningInvolvement: $0.planningInvolvement,
                    groupResponsibilities: $0.groupResponsibilities
                )
            },
            medical: dto.medical.map {
                MedicalProfileData(
                    education: $0.education,
                    additionalQualifications: $0.additionalQualifications,
                    specialties: $0.specialties,
                    assignedTeams: $0.assignedTeams,
                    organizationalAvailability: $0.organizationalAvailability,
                    protectedInternalNotes: $0.protectedInternalNotes
                )
            },
            teamManager: dto.teamManager.map {
                TeamManagerProfileData(
                    clubFunction: $0.clubFunction,
                    responsibilities: $0.responsibilities,
                    operationalTasks: $0.operationalTasks,
                    communicationOwnership: $0.communicationOwnership,
                    internalAvailability: $0.internalAvailability
                )
            },
            board: dto.board.map {
                BoardProfileData(
                    boardFunction: $0.boardFunction,
                    termStart: $0.termStart,
                    termEnd: $0.termEnd,
                    responsibilityAreas: $0.responsibilityAreas,
                    contactOptions: $0.contactOptions
                )
            },
            facility: dto.facility.map {
                FacilityProfileData(
                    responsibilities: $0.responsibilities,
                    facilities: $0.facilities,
                    availability: $0.availability
                )
            },
            lockedFieldKeys: Set(dto.lockedFieldKeys),
            updatedAt: dto.updatedAt,
            updatedBy: dto.updatedBy
        )
    }

    func mapProfileAuditEntry(_ dto: ProfileAuditEntryDTO) -> ProfileAuditEntry {
        let localProfileID = personProfiles.first(where: { $0.backendID == dto.profileID })?.id ?? UUID()
        return ProfileAuditEntry(
            backendID: dto.id,
            profileID: localProfileID,
            actorName: dto.actorName,
            fieldPath: dto.fieldPath,
            area: ProfileAuditFieldArea(rawValue: dto.area) ?? .core,
            oldValue: dto.oldValue,
            newValue: dto.newValue,
            timestamp: dto.timestamp
        )
    }
}

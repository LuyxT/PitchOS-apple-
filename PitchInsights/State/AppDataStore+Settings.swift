import Foundation

@MainActor
extension AppDataStore {
    func bootstrapSettings() async {
        settingsConnectionState = .syncing
        do {
            let dto = try await backend.fetchSettingsBootstrap()
            settingsPresentation = mapPresentationSettings(dto.presentation)
            settingsNotifications = mapNotificationSettings(dto.notifications)
            settingsSecurity = mapSecuritySettings(dto.security)
            settingsAppInfo = mapAppInfoSettings(dto.appInfo)
            settingsAccount = mapAccountSettings(dto.account)
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
        }
    }

    func savePresentationSettings(_ settings: AppPresentationSettings) async throws {
        settingsPresentation = settings

        let request = SavePresentationSettingsRequest(
            language: settings.language.rawValue,
            region: settings.region.rawValue,
            timeZoneID: settings.timeZoneID,
            unitSystem: settings.unitSystem.rawValue,
            appearanceMode: settings.appearanceMode.rawValue,
            contrastMode: settings.contrastMode.rawValue,
            uiScale: settings.uiScale.rawValue,
            reduceAnimations: settings.reduceAnimations,
            interactivePreviews: settings.interactivePreviews
        )

        do {
            let response = try await backend.savePresentationSettings(request)
            settingsPresentation = mapPresentationSettings(response)
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func saveNotificationSettings(_ settings: NotificationSettingsState) async throws {
        settingsNotifications = settings

        let request = SaveNotificationSettingsRequest(
            globalEnabled: settings.globalEnabled,
            modules: settings.modules.map {
                ModuleNotificationSettingsDTO(
                    module: $0.id.rawValue,
                    push: $0.channels.push,
                    inApp: $0.channels.inApp,
                    email: $0.channels.email
                )
            }
        )

        do {
            let response = try await backend.saveNotificationSettings(request)
            settingsNotifications = mapNotificationSettings(response)
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func refreshSecuritySettings() async {
        do {
            let response = try await backend.fetchSecuritySettings()
            settingsSecurity = mapSecuritySettings(response)
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
        }
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        let request = ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword)
        do {
            _ = try await backend.changePassword(request)
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func updateTwoFactor(enabled: Bool) async throws {
        settingsSecurity.twoFactorEnabled = enabled

        do {
            let response = try await backend.updateTwoFactor(UpdateTwoFactorRequest(enabled: enabled))
            settingsSecurity = mapSecuritySettings(response)
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func revokeSecuritySession(_ session: SecuritySessionInfo) async throws {
        settingsSecurity.sessions.removeAll { $0.id == session.id }

        guard let backendID = session.backendID else {
            throw SettingsStoreError.missingBackendID
        }

        do {
            let response = try await backend.revokeSession(RevokeSessionRequest(sessionID: backendID))
            settingsSecurity = mapSecuritySettings(response)
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func revokeAllSecuritySessions() async throws {
        settingsSecurity.sessions = settingsSecurity.sessions.filter(\.isCurrentDevice)

        do {
            let response = try await backend.revokeAllSessions()
            settingsSecurity = mapSecuritySettings(response)
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func refreshAppInfoSettings() async {
        do {
            let response = try await backend.fetchAppInfoSettings()
            settingsAppInfo = mapAppInfoSettings(response)
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
        }
    }

    func submitSettingsFeedback(_ payload: SettingsFeedbackPayload) async throws {
        let request = SubmitSettingsFeedbackRequest(
            category: payload.category,
            message: payload.message,
            screenshotPath: payload.screenshotPath,
            appVersion: payload.appVersion,
            buildNumber: payload.buildNumber,
            deviceModel: payload.deviceModel,
            platform: payload.platform,
            activeModuleID: payload.activeModuleID
        )

        do {
            _ = try await backend.submitSettingsFeedback(request)
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func switchAccountContext(to contextID: UUID) async throws {
        guard let context = settingsAccount.contexts.first(where: { $0.id == contextID }) else {
            throw SettingsStoreError.contextNotFound
        }

        for index in settingsAccount.contexts.indices {
            settingsAccount.contexts[index].isCurrent = settingsAccount.contexts[index].id == contextID
        }
        settingsAccount.selectedContextID = contextID

        guard let backendID = context.backendID else {
            throw SettingsStoreError.missingBackendID
        }

        do {
            let response = try await backend.switchAccountContext(SwitchAccountContextRequest(contextID: backendID))
            settingsAccount = mapAccountSettings(response)
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func logoutCurrentAccount() {
        backend.logoutCurrentSession()
        messengerCurrentUser = nil
    }

    func deactivateCurrentAccount() async throws {
        guard settingsAccount.canDeactivateAccount else {
            throw SettingsStoreError.notAllowed
        }

        do {
            _ = try await backend.deactivateAccount()
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func leaveCurrentTeam() async throws {
        guard settingsAccount.canLeaveTeam else {
            throw SettingsStoreError.notAllowed
        }

        do {
            _ = try await backend.leaveCurrentTeam()
            settingsConnectionState = .live
            settingsLastErrorMessage = nil
        } catch {
            settingsConnectionState = .failed(error.localizedDescription)
            settingsLastErrorMessage = error.localizedDescription
            throw error
        }
    }
}

extension AppDataStore {
    func seedSettingsFromCurrentState() {
        seedAppInfoFromBundle()

        let contexts = buildAccountContextsFromCurrentState()
        settingsAccount.contexts = contexts
        settingsAccount.selectedContextID = contexts.first(where: \.isCurrent)?.id ?? contexts.first?.id
        settingsAccount.canDeactivateAccount = hasAdminPermission(.managePeople)
        settingsAccount.canLeaveTeam = !hasAdminPermission(.managePeople)

        if settingsSecurity.sessions.isEmpty {
            settingsSecurity = .default
        }
        if settingsNotifications.modules.isEmpty {
            settingsNotifications = .default
        }
    }

    func hasAdminPermission(_ permission: AdminPermission) -> Bool {
        guard let viewer = currentViewerProfile(),
              let personID = viewer.linkedAdminPersonID,
              let person = adminPersons.first(where: { $0.id == personID }) else {
            return false
        }
        return person.permissions.contains(permission)
    }

    func buildAccountContextsFromCurrentState() -> [AccountContext] {
        let viewer = currentViewerProfile()
        let roleTitles = viewer?.core.roles.map(\.title) ?? ["Nutzer"]
        let roleTitle = roleTitles.joined(separator: ", ")

        let adminTeams = adminPersons
            .map(\.teamName)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let playerTeams = players
            .map(\.teamName)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var teams = Array(Set(adminTeams + playerTeams)).sorted()
        if teams.isEmpty {
            teams = [profile.team]
        }

        let clubName = viewer?.core.clubName.isEmpty == false ? (viewer?.core.clubName ?? profile.team) : profile.team
        let preferredTeam = teams.contains(profile.team) ? profile.team : teams.first

        let contexts = teams.map { team in
            AccountContext(
                backendID: "local.context.\(team.lowercased().replacingOccurrences(of: " ", with: "-"))",
                clubName: clubName,
                teamName: team,
                roleTitle: roleTitle,
                isCurrent: team == preferredTeam
            )
        }

        return contexts.isEmpty ? [AccountSettingsState.default.contexts[0]] : contexts
    }

    func seedAppInfoFromBundle() {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? settingsAppInfo.version
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? settingsAppInfo.buildNumber

        settingsAppInfo.version = version
        settingsAppInfo.buildNumber = build
        if settingsAppInfo.changelog.isEmpty {
            settingsAppInfo.changelog = AppInfoState.default.changelog
        }
        if settingsAppInfo.lastUpdateAt.timeIntervalSince1970 <= 0 {
            settingsAppInfo.lastUpdateAt = Date()
        }
    }

    func mapPresentationSettings(_ dto: PresentationSettingsDTO) -> AppPresentationSettings {
        AppPresentationSettings(
            language: AppLanguage(rawValue: dto.language) ?? .de,
            region: AppRegionFormat(rawValue: dto.region) ?? .germany,
            timeZoneID: dto.timeZoneID,
            unitSystem: AppUnitSystem(rawValue: dto.unitSystem) ?? .metric,
            appearanceMode: AppAppearanceMode(rawValue: dto.appearanceMode) ?? .light,
            contrastMode: AppContrastMode(rawValue: dto.contrastMode) ?? .standard,
            uiScale: AppUIScale(rawValue: dto.uiScale) ?? .medium,
            reduceAnimations: dto.reduceAnimations,
            interactivePreviews: dto.interactivePreviews
        )
    }

    func mapNotificationSettings(_ dto: NotificationSettingsDTO) -> NotificationSettingsState {
        let mapped = dto.modules.compactMap { module -> ModuleNotificationSetting? in
            guard let key = NotificationModuleKey(rawValue: module.module) else { return nil }
            return ModuleNotificationSetting(
                module: key,
                channels: NotificationChannelState(
                    push: module.push,
                    inApp: module.inApp,
                    email: module.email
                )
            )
        }
        let finalModules = mapped.isEmpty ? NotificationSettingsState.default.modules : mapped
        return NotificationSettingsState(globalEnabled: dto.globalEnabled, modules: finalModules)
    }

    func mapSecuritySettings(_ dto: SecuritySettingsDTO) -> SecuritySettingsState {
        SecuritySettingsState(
            twoFactorEnabled: dto.twoFactorEnabled,
            sessions: dto.sessions.map {
                SecuritySessionInfo(
                    id: UUID(uuidString: $0.id) ?? UUID(),
                    backendID: $0.id,
                    deviceName: $0.deviceName,
                    platformName: $0.platformName,
                    lastUsedAt: $0.lastUsedAt,
                    ipAddress: $0.ipAddress,
                    location: $0.location,
                    isCurrentDevice: $0.isCurrentDevice
                )
            },
            apiTokens: dto.apiTokens.map {
                SecurityTokenInfo(
                    id: UUID(uuidString: $0.id) ?? UUID(),
                    backendID: $0.id,
                    name: $0.name,
                    scope: $0.scope,
                    lastUsedAt: $0.lastUsedAt,
                    createdAt: $0.createdAt
                )
            },
            privacyURL: dto.privacyURL
        )
    }

    func mapAppInfoSettings(_ dto: AppInfoSettingsDTO) -> AppInfoState {
        AppInfoState(
            version: dto.version,
            buildNumber: dto.buildNumber,
            lastUpdateAt: dto.lastUpdateAt,
            updateState: AppUpdateState(rawValue: dto.updateState) ?? .unknown,
            changelog: dto.changelog
        )
    }

    func mapAccountSettings(_ dto: AccountSettingsDTO) -> AccountSettingsState {
        let contexts = dto.contexts.map {
            AccountContext(
                id: UUID(uuidString: $0.id) ?? UUID(),
                backendID: $0.id,
                clubName: $0.clubName,
                teamName: $0.teamName,
                roleTitle: $0.roleTitle,
                isCurrent: $0.isCurrent
            )
        }
        let selected = dto.selectedContextID.flatMap { selectedID in
            contexts.first(where: { $0.backendID == selectedID })?.id
        } ?? contexts.first(where: \.isCurrent)?.id

        return AccountSettingsState(
            contexts: contexts,
            selectedContextID: selected,
            canDeactivateAccount: dto.canDeactivateAccount,
            canLeaveTeam: dto.canLeaveTeam
        )
    }
}

enum SettingsStoreError: LocalizedError {
    case missingBackendID
    case contextNotFound
    case notAllowed

    var errorDescription: String? {
        switch self {
        case .missingBackendID:
            return "Server-ID fehlt für diese Aktion."
        case .contextNotFound:
            return "Kontext nicht gefunden."
        case .notAllowed:
            return "Aktion ist für dieses Konto nicht erlaubt."
        }
    }
}

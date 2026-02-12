import SwiftUI

struct OnboardingFlowView: View {
    enum RetryAction {
        case login
        case register
        case clubSubmit
        case profileSave
    }
    enum Step: String {
        case welcome
        case authChoice
        case login
        case register
        case role
        case club
        case profile
        case complete

        var sortOrder: Int {
            switch self {
            case .welcome: return 0
            case .authChoice: return 1
            case .login: return 2
            case .register: return 3
            case .role: return 4
            case .club: return 5
            case .profile: return 6
            case .complete: return 7
            }
        }
    }

    @EnvironmentObject private var session: AppSessionStore
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var motion: MotionEngine

    @State private var step: Step
    @State private var transitionStyle: MotionTransitionStyle = .cameraPush

    @State private var authChoice: AuthChoice? = nil
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""

    @State private var selectedRole: String = "trainer"
    @State private var region = ""
    @State private var clubName = ""
    @State private var postalCode = ""
    @State private var city = ""
    @State private var teamName = ""
    @State private var league = ""
    @State private var inviteCode = ""

    @State private var candidates: [OnboardingCandidateDTO] = []
    @State private var statusMessage = ""
    @State private var isBusy = false
    @State private var isSearching = false
    @State private var showPlayerWarning = false

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var license = ""
    @State private var preferredSystem = ""
    @State private var goals = ""
    @State private var experience = ""
    @State private var boardPosition = ""
    @State private var boardResponsibilities = ""
    @State private var physioQualification = ""

    @State private var lookupTask: Task<Void, Never>?
    @State private var hasLoadedDraft = false
    @State private var connectionError: String? = nil
    @State private var retryAction: RetryAction? = nil

    private let draftKey = "pitchinsights.onboarding.draft"

    init(startAt: Step = .welcome) {
        _step = State(initialValue: startAt)
    }

    var body: some View {
        ZStack {
            OnboardingSceneBackground(pulseID: motion.pulseID)

            VStack(spacing: 18) {
                header
                content
                footer
            }
            .padding(32)
            .frame(maxWidth: 720)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.surface.opacity(0.96))
                    .shadow(color: AppTheme.shadow.opacity(0.2), radius: 24, x: 0, y: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.9), lineWidth: 1)
            )
            .motionGlow(!statusMessage.isEmpty, color: .red, animation: AppMotion.errorShake)
            .errorShake(motion.errorID)
            .transition(motion.transition(transitionStyle))
            .animation(AppMotion.settleSoft, value: step)
            .environment(\.colorScheme, .light)

            if let connectionError, let retryAction {
                OnboardingConnectionPanel(
                    message: connectionError,
                    onRetry: { handleRetry(retryAction) },
                    onDismiss: {
                        self.connectionError = nil
                        self.retryAction = nil
                    }
                )
                .transition(motion.transition(.transitionZoom))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if !hasLoadedDraft {
                loadDraft()
            }
        }
        .onChange(of: step) { _, _ in saveDraft() }
        .onChange(of: email) { _, _ in saveDraft() }
        .onChange(of: selectedRole) { _, _ in saveDraft() }
        .onChange(of: region) { _, _ in saveDraft() }
        .onChange(of: clubName) { _, _ in saveDraft() }
        .onChange(of: teamName) { _, _ in saveDraft() }
        .onChange(of: firstName) { _, _ in saveDraft() }
        .onChange(of: lastName) { _, _ in saveDraft() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                if canGoBack {
                    Button("Zuruck") {
                        goBack()
                    }
                    .buttonStyle(OnboardingSecondaryButtonStyle())
                }
                Spacer()
                OnboardingProgressRing(progress: progressValue)
            }

            Text("PitchInsights")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(titleForStep)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            OnboardingWelcomeView {
                goTo(.authChoice, style: .cameraPush)
            }
        case .authChoice:
            AuthChoiceView(selected: authChoice) { choice in
                authChoice = choice
                goTo(choice == .login ? .login : .register, style: .transitionZoom)
            }
        case .login:
            LoginView(email: $email, password: $password, isBusy: isBusy) {
                Task { await submitAuth(isLogin: true) }
            }
        case .register:
            RegisterView(
                email: $email,
                password: $password,
                passwordConfirmation: $passwordConfirmation,
                inviteCode: $inviteCode,
                isBusy: isBusy
            ) {
                Task { await submitAuth(isLogin: false) }
            }
        case .role:
            RoleSelectionView(
                selectedRole: selectedRole,
                onSelect: { role in
                    selectedRole = role
                    showPlayerWarning = role == "player"
                },
                onContinue: {
                    if selectedRole == "player" {
                        motion.triggerError()
                        showPlayerWarning = true
                        return
                    }
                    goTo(.club, style: .cameraPush)
                },
                showPlayerWarning: showPlayerWarning
            )
        case .club:
            ClubTeamSetupView(
                region: $region,
                clubName: $clubName,
                postalCode: $postalCode,
                city: $city,
                teamName: $teamName,
                league: $league,
                inviteCode: $inviteCode,
                requiresTeam: selectedRole != "vorstand",
                isSearching: isSearching,
                candidates: candidates,
                statusMessage: statusMessage,
                onSearch: { Task { await submitClubSelection(selectedClubId: nil) } },
                onSelectCandidate: { candidate in
                    Task { await submitClubSelection(selectedClubId: candidate.clubId) }
                }
            )
            .onChange(of: clubName) { _, _ in scheduleClubLookup() }
            .onChange(of: region) { _, _ in scheduleClubLookup() }
        case .profile:
            ProfileSetupView(
                role: selectedRole,
                firstName: $firstName,
                lastName: $lastName,
                license: $license,
                preferredSystem: $preferredSystem,
                goals: $goals,
                experience: $experience,
                boardPosition: $boardPosition,
                boardResponsibilities: $boardResponsibilities,
                physioQualification: $physioQualification,
                isBusy: isBusy,
                onSubmit: { Task { await submitProfile() } }
            )
        case .complete:
            OnboardingCompleteView {
                session.phase = .ready
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
                    .motionGlow(true, color: .red, animation: AppMotion.errorShake)
            }

            Capsule()
                .fill(AppTheme.surfaceAlt)
                .frame(width: 320, height: 6)
                .overlay(
                    Capsule()
                        .fill(AppTheme.primary)
                        .frame(width: max(12, 320 * progressValue))
                        .animation(AppMotion.sceneReveal, value: progressValue)
                    , alignment: .leading
                )
        }
    }

    private var progressValue: Double {
        switch step {
        case .welcome: return 0.12
        case .authChoice: return 0.22
        case .login, .register: return 0.3
        case .role: return 0.45
        case .club: return 0.65
        case .profile: return 0.85
        case .complete: return 1
        }
    }

    private var titleForStep: String {
        switch step {
        case .welcome: return "Start"
        case .authChoice: return "Login oder Registrierung"
        case .login: return "Login"
        case .register: return "Registrieren"
        case .role: return "Rolle"
        case .club: return "Club & Kontext"
        case .profile: return "Profil"
        case .complete: return "Fertig"
        }
    }

    private var canGoBack: Bool {
        switch step {
        case .welcome, .complete:
            return false
        default:
            return true
        }
    }

    private func goBack() {
        transitionStyle = .cameraPull
        withAnimation(AppMotion.cameraPush) {
            switch step {
            case .authChoice:
                step = .welcome
            case .login, .register:
                step = .authChoice
            case .role:
                step = .authChoice
            case .club:
                step = .role
            case .profile:
                step = .club
            case .complete:
                step = .profile
            case .welcome:
                step = .welcome
            }
        }
    }

    private func goTo(_ target: Step, style: MotionTransitionStyle) {
        transitionStyle = style
        withAnimation(AppMotion.cameraPush) {
            step = target
        }
        statusMessage = ""
        motion.advanceScene()
        motion.triggerSuccess()
    }

    private func submitAuth(isLogin: Bool) async {
        statusMessage = ""
        connectionError = nil
        retryAction = nil
        isBusy = true
        defer { isBusy = false }

        do {
            if !isLogin, password != passwordConfirmation {
                throw NSError(
                    domain: "Onboarding",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Passwortbestatigung stimmt nicht uberein."]
                )
            }

            let authenticatedUser: AuthUserDTO?
            if isLogin {
                authenticatedUser = try await dataStore.backend.auth.login(email: email, password: password)
            } else {
                authenticatedUser = try await dataStore.backend.auth.register(
                    email: email,
                    password: password,
                    passwordConfirmation: passwordConfirmation,
                    role: selectedRole,
                    inviteCode: inviteCode.isEmpty ? nil : inviteCode
                )
            }

            if let authenticatedUser {
                session.applyAuthenticatedUser(authenticatedUser)
            }

            let me = try await dataStore.backend.fetchAuthMe()
            session.applyAuthMe(me)
            if me.onboardingRequired {
                session.phase = .onboarding
                goTo(.club, style: .cameraPush)
            } else {
                session.phase = .ready
                clearDraft()
            }
        } catch {
            let message = NetworkError.userMessage(from: error)
            statusMessage = message
            connectionError = message
            retryAction = isLogin ? .login : .register
            motion.triggerError()
        }
    }

    private func scheduleClubLookup() {
        lookupTask?.cancel()
        candidates = []
    }

    private func searchClubsPreview() async {
        candidates = []
    }

    private func submitClubSelection(selectedClubId: String?) async {
        statusMessage = ""
        connectionError = nil
        retryAction = nil
        isSearching = true
        defer { isSearching = false }

        do {
            var me = try await dataStore.backend.fetchAuthMe()
            var resolvedClubId = me.clubId

            if resolvedClubId == nil {
                let normalizedName = (selectedClubId ?? clubName).trimmingCharacters(in: .whitespacesAndNewlines)
                if normalizedName.isEmpty {
                    throw NSError(
                        domain: "Onboarding",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Vereinsname fehlt"]
                    )
                }
                if region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw NSError(
                        domain: "Onboarding",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Region fehlt"]
                    )
                }
                if city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw NSError(
                        domain: "Onboarding",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Stadt fehlt"]
                    )
                }
                _ = try await dataStore.backend.createOnboardingClub(
                    ClubCreateRequest(
                        name: normalizedName,
                        region: region,
                        city: city
                    )
                )
                me = try await dataStore.backend.fetchAuthMe()
                resolvedClubId = me.clubId
            }

            if selectedRole != "vorstand" {
                let resolvedTeamName = teamName.trimmingCharacters(in: .whitespacesAndNewlines)
                if resolvedTeamName.isEmpty {
                    throw NSError(
                        domain: "Onboarding",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Teamname fehlt"]
                    )
                }

                _ = try await dataStore.backend.createOnboardingTeam(
                    TeamCreateRequest(
                        clubId: resolvedClubId,
                        name: resolvedTeamName,
                        ageGroup: "Senior",
                        league: league.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Offen" : league
                    )
                )
                me = try await dataStore.backend.fetchAuthMe()
            }

            session.applyAuthMe(me)
            if me.onboardingRequired {
                session.phase = .onboarding
                statusMessage = "Onboarding unvollstandig. Bitte Teamdaten prufen."
                goTo(.club, style: .sceneReveal)
            } else {
                statusMessage = "Onboarding abgeschlossen."
                clearDraft()
                session.phase = .ready
            }
        } catch {
            let message = NetworkError.userMessage(from: error)
            statusMessage = message
            connectionError = message
            retryAction = .clubSubmit
            motion.triggerError()
        }
    }

    private func submitProfile() async {
        statusMessage = ""
        isBusy = true
        defer { isBusy = false }

        do {
            let request = UpdateProfileRequest(
                firstName: firstName,
                lastName: lastName,
                phone: nil,
                trainerLicenses: license.isEmpty ? nil : [license],
                trainerEducation: nil,
                trainerPhilosophy: preferredSystem.isEmpty ? nil : preferredSystem,
                trainerGoals: goals.isEmpty ? nil : goals.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                trainerCareerHistory: experience.isEmpty ? nil : experience,
                physioQualifications: physioQualification.isEmpty ? nil : [physioQualification],
                boardFunction: boardPosition.isEmpty ? nil : boardPosition,
                boardResponsibilities: boardResponsibilities.isEmpty ? nil : boardResponsibilities.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            )
            _ = try await dataStore.backend.submitProfile(request)
            _ = try await dataStore.backend.completeOnboarding()
            session.onboardingState = OnboardingStateDTO(completed: true, completedAt: Date(), lastStep: "complete")
            motion.triggerSuccess()
            clearDraft()
            goTo(.complete, style: .transitionZoom)
        } catch {
            statusMessage = "Profil konnte nicht gespeichert werden."
            connectionError = "Profil konnte nicht gespeichert werden."
            retryAction = .profileSave
            motion.triggerError()
        }
    }

    private func handleRetry(_ action: RetryAction) {
        connectionError = nil
        retryAction = nil

        switch action {
        case .login:
            Task { await submitAuth(isLogin: true) }
        case .register:
            Task { await submitAuth(isLogin: false) }
        case .clubSubmit:
            Task { await submitClubSelection(selectedClubId: nil) }
        case .profileSave:
            Task { await submitProfile() }
        }
    }

    private func saveDraft() {
        let draft = OnboardingDraft(
            step: step.rawValue,
            email: email,
            selectedRole: selectedRole,
            region: region,
            clubName: clubName,
            postalCode: postalCode,
            city: city,
            teamName: teamName,
            league: league,
            inviteCode: inviteCode,
            firstName: firstName,
            lastName: lastName,
            license: license,
            preferredSystem: preferredSystem,
            goals: goals,
            experience: experience,
            boardPosition: boardPosition,
            boardResponsibilities: boardResponsibilities,
            physioQualification: physioQualification
        )

        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: draftKey)
    }

    private func loadDraft() {
        hasLoadedDraft = true
        guard let data = UserDefaults.standard.data(forKey: draftKey),
              let draft = try? JSONDecoder().decode(OnboardingDraft.self, from: data) else {
            return
        }

        let loadedStep = Step(rawValue: draft.step) ?? step
        if loadedStep.sortOrder >= step.sortOrder {
            step = loadedStep
        }
        email = draft.email
        selectedRole = draft.selectedRole
        region = draft.region
        clubName = draft.clubName
        postalCode = draft.postalCode
        city = draft.city
        teamName = draft.teamName
        league = draft.league
        inviteCode = draft.inviteCode
        firstName = draft.firstName
        lastName = draft.lastName
        license = draft.license
        preferredSystem = draft.preferredSystem
        goals = draft.goals
        experience = draft.experience
        boardPosition = draft.boardPosition
        boardResponsibilities = draft.boardResponsibilities
        physioQualification = draft.physioQualification
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }
}

struct OnboardingSceneBackground: View {
    let pulseID: Int

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let driftX = CGFloat(sin(time * 0.08)) * 16
            let driftY = CGFloat(cos(time * 0.07)) * 12
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.09, blue: 0.1), Color(red: 0.08, green: 0.2, blue: 0.18), Color(red: 0.9, green: 0.95, blue: 0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 520, height: 520)
                    .blur(radius: 40)
                    .offset(x: -220 + driftX, y: -240 + driftY)

                Circle()
                    .fill(AppTheme.primary.opacity(0.15))
                    .frame(width: 360, height: 360)
                    .blur(radius: 60)
                    .offset(x: 220 - driftX, y: 180 - driftY)

                ParticleDustView(intensity: 0.7)
                    .blendMode(.screen)
            }
            .ignoresSafeArea()
            .overlay(
                ParticleBurstView(trigger: pulseID, color: AppTheme.primary.opacity(0.6))
                    .frame(width: 200, height: 200)
                    .offset(y: -120)
            )
        }
    }
}

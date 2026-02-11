import SwiftUI

struct OnboardingFlowView: View {
    enum Step: String {
        case welcome
        case auth
        case role
        case club
        case candidates
        case profile
        case confirm
    }

    @EnvironmentObject private var session: AppSessionStore
    @EnvironmentObject private var dataStore: AppDataStore

    @State private var step: Step
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""

    @State private var selectedRole: String = "trainer"
    @State private var region = ""
    @State private var clubName = ""
    @State private var postalCode = ""
    @State private var city = ""
    @State private var teamName = ""
    @State private var league = ""
    @State private var inviteCode = ""

    @State private var candidates: [OnboardingCandidateDTO] = []
    @State private var selectedClubId: String?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var license = ""
    @State private var preferredSystem = ""
    @State private var goals = ""
    @State private var experience = ""
    @State private var boardPosition = ""
    @State private var boardResponsibilities = ""
    @State private var physioQualification = ""

    @State private var statusMessage = ""
    @State private var isBusy = false

    init(startAt: Step = .welcome) {
        _step = State(initialValue: startAt)
    }

    var body: some View {
        ZStack {
            FootballBackdrop()
            VStack(spacing: 18) {
                header
                content
                footer
            }
            .padding(32)
            .frame(maxWidth: 720)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.surface.opacity(0.95))
                    .shadow(color: AppTheme.shadow.opacity(0.2), radius: 24, x: 0, y: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.9), lineWidth: 1)
            )
            .animation(AppMotion.settle, value: step)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(spacing: 8) {
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
            welcomeStep
        case .auth:
            authStep
        case .role:
            roleStep
        case .club:
            clubStep
        case .candidates:
            candidateStep
        case .profile:
            profileStep
        case .confirm:
            confirmStep
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
            }
            progressBar
        }
    }

    private var progressBar: some View {
        let progress = progressValue
        return ZStack(alignment: .leading) {
            Capsule().fill(AppTheme.surfaceAlt)
            Capsule().fill(AppTheme.primary)
                .frame(width: max(12, 320 * progress))
        }
        .frame(width: 320, height: 6)
        .animation(AppMotion.settle, value: progress)
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Text("Willkommen")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Starte deine Umgebung und richte deinen Verein in wenigen Schritten ein.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Los geht's") {
                withAnimation(AppMotion.settle) {
                    step = .auth
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .interactiveSurface(hoverScale: 1.02, pressScale: 0.98, hoverShadowOpacity: 0.2, feedback: .soft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var authStep: some View {
        VStack(spacing: 14) {
            Picker("", selection: $isLogin) {
                Text("Login").tag(true)
                Text("Registrieren").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 260)

            TextField("E-Mail", text: $email)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)

            SecureField("Passwort", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)

            Button(isLogin ? "Einloggen" : "Account erstellen") {
                Task { await submitAuth() }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isBusy || email.isEmpty || password.count < 8)
        }
    }

    private var roleStep: some View {
        VStack(spacing: 12) {
            Text("Welche Rolle hast du?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 10) {
                roleCard("Trainer", value: "trainer")
                roleCard("Co-Trainer", value: "co_trainer")
                roleCard("Physio", value: "physio")
                roleCard("Vorstand", value: "vorstand")
            }

            Button("Weiter") {
                withAnimation(AppMotion.settle) {
                    step = .club
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
    }

    private var clubStep: some View {
        VStack(spacing: 12) {
            TextField("Region", text: $region)
                .textFieldStyle(.roundedBorder)
            TextField("Vereinsname", text: $clubName)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                TextField("PLZ", text: $postalCode)
                    .textFieldStyle(.roundedBorder)
                TextField("Stadt", text: $city)
                    .textFieldStyle(.roundedBorder)
            }
            TextField("Invite-Code (optional)", text: $inviteCode)
                .textFieldStyle(.roundedBorder)

            if selectedRole != "vorstand" {
                TextField("Team", text: $teamName)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Liga (optional)", text: $league)
                .textFieldStyle(.roundedBorder)

            Button("Club finden") {
                Task { await resolveClub() }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isBusy || region.isEmpty || clubName.isEmpty || (selectedRole != "vorstand" && teamName.isEmpty))
        }
    }

    private var candidateStep: some View {
        VStack(spacing: 12) {
            Text("Bestehender Verein gefunden")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Bitte wähle den richtigen Eintrag.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(candidates, id: \.clubId) { candidate in
                    Button {
                        selectedClubId = candidate.clubId
                        Task { await resolveClub(selectedClubId: candidate.clubId) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.clubName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text([candidate.city, candidate.postalCode, candidate.region].compactMap { $0 }.joined(separator: " · "))
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.surfaceAlt.opacity(0.6))
                        )
                    }
                    .buttonStyle(.plain)
                    .interactiveSurface(hoverScale: 1.02, pressScale: 0.98, hoverShadowOpacity: 0.18, feedback: .light)
                }
            }
        }
    }

    private var profileStep: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Vorname", text: $firstName)
                    .textFieldStyle(.roundedBorder)
                TextField("Nachname", text: $lastName)
                    .textFieldStyle(.roundedBorder)
            }

            if selectedRole == "trainer" || selectedRole == "co_trainer" {
                TextField("Lizenz", text: $license)
                    .textFieldStyle(.roundedBorder)
                TextField("Bevorzugtes System", text: $preferredSystem)
                    .textFieldStyle(.roundedBorder)
                TextField("Ziele", text: $goals)
                    .textFieldStyle(.roundedBorder)
                TextField("Erfahrung", text: $experience)
                    .textFieldStyle(.roundedBorder)
            } else if selectedRole == "physio" {
                TextField("Qualifikation", text: $physioQualification)
                    .textFieldStyle(.roundedBorder)
            } else if selectedRole == "vorstand" {
                TextField("Position", text: $boardPosition)
                    .textFieldStyle(.roundedBorder)
                TextField("Verantwortlichkeiten", text: $boardResponsibilities)
                    .textFieldStyle(.roundedBorder)
            }

            Button("Profil speichern") {
                Task { await submitProfile() }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isBusy || firstName.isEmpty || lastName.isEmpty)
        }
    }

    private var confirmStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.primary)
            Text("Alles bereit")
                .font(.system(size: 16, weight: .semibold))
            Text("Dein Workspace wird geöffnet.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
            Button("Zum Dashboard") {
                session.phase = .ready
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
    }

    private func roleCard(_ title: String, value: String) -> some View {
        Button {
            withAnimation(AppMotion.settle) {
                selectedRole = value
            }
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if selectedRole == value {
                    Capsule()
                        .fill(AppTheme.primary)
                        .frame(width: 28, height: 4)
                }
            }
            .frame(width: 120, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selectedRole == value ? AppTheme.primary.opacity(0.12) : AppTheme.surfaceAlt.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selectedRole == value ? AppTheme.primary : AppTheme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .interactiveSurface(hoverScale: 1.03, pressScale: 0.97, hoverShadowOpacity: 0.22, feedback: .light)
    }

    private var titleForStep: String {
        switch step {
        case .welcome: return "Start"
        case .auth: return "Login oder Registrierung"
        case .role: return "Rolle"
        case .club: return "Club & Kontext"
        case .candidates: return "Club auswählen"
        case .profile: return "Profil"
        case .confirm: return "Fertig"
        }
    }

    private var progressValue: CGFloat {
        switch step {
        case .welcome: return 0.15
        case .auth: return 0.25
        case .role: return 0.4
        case .club: return 0.6
        case .candidates: return 0.7
        case .profile: return 0.85
        case .confirm: return 1
        }
    }

    private func submitAuth() async {
        statusMessage = ""
        isBusy = true
        defer { isBusy = false }

        do {
            if isLogin {
                try await dataStore.backend.auth.login(email: email, password: password)
            } else {
                try await dataStore.backend.auth.register(email: email, password: password)
            }
            let me = try await dataStore.backend.fetchAuthMe()
            session.applyAuthMe(me)
            session.phase = .onboarding
            withAnimation(AppMotion.settle) {
                step = .role
            }
        } catch {
            statusMessage = "Authentifizierung fehlgeschlagen."
        }
    }

    private func resolveClub(selectedClubId: String? = nil) async {
        statusMessage = ""
        isBusy = true
        defer { isBusy = false }

        do {
            let request = OnboardingResolveRequest(
                role: selectedRole,
                region: region,
                clubName: clubName,
                postalCode: postalCode.isEmpty ? nil : postalCode,
                city: city.isEmpty ? nil : city,
                teamName: teamName.isEmpty ? nil : teamName,
                league: league.isEmpty ? nil : league,
                inviteCode: inviteCode.isEmpty ? nil : inviteCode,
                clubId: selectedClubId
            )
            let response = try await dataStore.backend.resolveOnboarding(request)
            if response.mode == "candidates", let responseCandidates = response.candidates {
                candidates = responseCandidates
                withAnimation(AppMotion.settle) {
                    step = .candidates
                }
                return
            }
            let me = try await dataStore.backend.fetchAuthMe()
            session.applyAuthMe(me)
            session.phase = .onboarding
            withAnimation(AppMotion.settle) {
                step = .profile
            }
        } catch {
            statusMessage = "Club konnte nicht aufgelöst werden."
        }
    }

    private func submitProfile() async {
        guard let userId = session.authUser?.id else { return }
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
            _ = try await dataStore.backend.updateProfile(userId: userId, request: request)
            _ = try await dataStore.backend.completeOnboarding()
            session.onboardingState = OnboardingStateDTO(completed: true, completedAt: Date(), lastStep: "complete")
            withAnimation(AppMotion.settle) {
                step = .confirm
            }
        } catch {
            statusMessage = "Profil konnte nicht gespeichert werden."
        }
    }
}

private struct FootballBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.96, blue: 0.95), Color(red: 0.86, green: 0.92, blue: 0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 420, height: 420)
                .blur(radius: 40)
                .offset(x: -180, y: -220)
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                .frame(width: 560, height: 320)
                .rotationEffect(.degrees(-6))
                .opacity(0.4)
        }
        .ignoresSafeArea()
    }
}

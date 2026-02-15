import Foundation
import Combine

@MainActor
final class AppSessionStore: ObservableObject {
    enum Phase {
        case checking
        case unauthenticated
        case onboarding
        case ready
        case backendUnavailable
    }

    @Published var phase: Phase = .checking
    @Published var authUser: AuthUserDTO?
    @Published var onboardingState: OnboardingStateDTO?
    @Published var memberships: [MembershipDTO] = []
    @Published var activeContext: MembershipDTO?

    private let activeContextKey = "pitchinsights.activeMembershipId"
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .authUserUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self, let user = notification.object as? AuthUserDTO else { return }
                self.applyAuthenticatedUser(user)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .authSessionInvalidated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.clearSession()
            }
            .store(in: &cancellables)
    }

    func bootstrap(using backend: BackendRepository) async {
        phase = .checking
        do {
            guard backend.auth.accessToken != nil || backend.auth.refreshToken != nil else {
                phase = .unauthenticated
                return
            }

            if backend.auth.refreshToken != nil {
                _ = try? await backend.auth.refresh()
            }

            let me = try await backend.fetchAuthMe()
            applyAuthMe(me)
            if me.onboardingRequired {
                phase = .onboarding
            } else {
                phase = .ready
            }
        } catch {
            backend.auth.clearTokens(notify: true)
            phase = .unauthenticated
        }
    }

    func applyAuthenticatedUser(_ user: AuthUserDTO) {
        print("[Session] applyAuthenticatedUser: clubId=\(user.clubId ?? "nil") teamId=\(user.teamId ?? "nil")")
        authUser = user
        let completed = user.clubId != nil && user.teamId != nil
        onboardingState = OnboardingStateDTO(
            completed: completed,
            completedAt: nil,
            lastStep: completed ? "DONE" : "TEAM_SETUP"
        )
        memberships = []
        activeContext = nil
        let newPhase: Phase = completed ? .ready : .onboarding
        print("[Session] applyAuthenticatedUser: phase \(phase) → \(newPhase)")
        phase = newPhase
    }

    func applyAuthMe(_ me: AuthMeDTO) {
        print("[Session] applyAuthMe: onboardingRequired=\(me.onboardingRequired) clubId=\(me.clubId ?? "nil") teamId=\(me.teamId ?? "nil")")
        authUser = AuthUserDTO(
            id: me.id,
            email: me.email,
            firstName: me.firstName,
            lastName: me.lastName,
            role: me.role,
            clubId: me.clubId,
            teamId: me.teamId,
            organizationId: me.organizationId,
            createdAt: me.createdAt
        )
        onboardingState = me.onboardingState ?? OnboardingStateDTO(
            completed: !me.onboardingRequired,
            completedAt: nil,
            lastStep: me.nextStep
        )
        memberships = me.clubMemberships
        resolveActiveContext(from: me.clubMemberships)
        let newPhase: Phase = me.onboardingRequired ? .onboarding : .ready
        print("[Session] applyAuthMe: phase \(phase) → \(newPhase)")
        phase = newPhase
    }

    func setActiveContext(_ membership: MembershipDTO) {
        activeContext = membership
        UserDefaults.standard.set(membership.id, forKey: activeContextKey)
    }

    func clearSession() {
        authUser = nil
        onboardingState = nil
        memberships = []
        activeContext = nil
        UserDefaults.standard.removeObject(forKey: activeContextKey)
        UserDefaults.standard.removeObject(forKey: "pitchinsights.onboarding.draft")
        phase = .unauthenticated
    }

    private func resolveActiveContext(from memberships: [MembershipDTO]) {
        let stored = UserDefaults.standard.string(forKey: activeContextKey)
        if let stored, let match = memberships.first(where: { $0.id == stored }) {
            activeContext = match
            return
        }
        if let firstActive = memberships.first(where: { $0.status.lowercased() == "active" }) {
            activeContext = firstActive
            return
        }
        activeContext = memberships.first
    }
}

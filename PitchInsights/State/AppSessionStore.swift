import Foundation
import Combine

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

    func bootstrap(using backend: BackendRepository) async {
        do {
            guard backend.auth.accessToken != nil || backend.auth.refreshToken != nil else {
                phase = .unauthenticated
                return
            }

            if backend.auth.refreshToken != nil {
                try? await backend.auth.refresh()
            }

            let me = try await backend.fetchAuthMe()
            applyAuthMe(me)
            if me.clubId == nil {
                phase = .onboarding
            } else {
                phase = .ready
            }
        } catch {
            phase = .unauthenticated
        }
    }

    func applyAuthMe(_ me: AuthMeDTO) {
        authUser = AuthUserDTO(
            id: me.id,
            email: me.email,
            role: me.role,
            clubId: me.clubId,
            organizationId: me.organizationId,
            createdAt: me.createdAt
        )
        onboardingState = me.onboardingState
        memberships = me.clubMemberships
        resolveActiveContext(from: me.clubMemberships)
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

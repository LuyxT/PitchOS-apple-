import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: AppSessionStore

    var body: some View {
        Group {
            switch session.phase {
            case .checking:
                sessionChecking
            case .unauthenticated, .onboarding:
                OnboardingFlowView(startAt: session.phase == .onboarding ? onboardingStartStep : .welcome)
            case .ready:
                AdaptiveWorkspaceRootView()
            case .backendUnavailable:
                sessionChecking
            }
        }
    }

    private var sessionChecking: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Session wird geladen...")
                .font(.headline)
            Text(AppConfiguration.API_BASE_URL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var onboardingStartStep: OnboardingFlowView.Step {
        if let onboardingState = session.onboardingState, onboardingState.completed == false {
            if session.authUser?.clubId == nil {
                return .role
            }
            if session.authUser?.teamId == nil {
                return .club
            }
            return .profile
        }
        if session.authUser?.clubId == nil || session.authUser?.teamId == nil {
            return .role
        }
        return .complete
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .environmentObject(AppSessionStore())
        .environmentObject(MotionEngine())
}

import SwiftUI

struct ClubTeamSetupView: View {
    @EnvironmentObject private var motion: MotionEngine

    @Binding var region: String
    @Binding var clubName: String
    @Binding var postalCode: String
    @Binding var city: String
    @Binding var teamName: String
    @Binding var league: String
    @Binding var inviteCode: String

    let requiresTeam: Bool
    let isSearching: Bool
    let candidates: [OnboardingCandidateDTO]
    let statusMessage: String

    let onSearch: () -> Void
    let onSelectCandidate: (OnboardingCandidateDTO) -> Void

    var body: some View {
        VStack(spacing: 12) {
            OnboardingRegionPicker(region: $region)
            OnboardingInputField(title: "Vereinsname", text: $clubName)

            HStack(spacing: 8) {
                OnboardingInputField(title: "PLZ", text: $postalCode)
                OnboardingInputField(title: "Stadt", text: $city)
            }

            OnboardingInputField(title: "Invite-Code (optional)", text: $inviteCode)

            if requiresTeam {
                OnboardingInputField(title: "Team", text: $teamName)
            }

            OnboardingInputField(title: "Liga (optional)", text: $league)

            if isSearching {
                ScanningBar()
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if !candidates.isEmpty {
                VStack(spacing: 8) {
                    if candidates.count == 1, let candidate = candidates.first {
                        Button {
                            motion.triggerSuccess()
                            onSelectCandidate(candidate)
                        } label: {
                            ZStack {
                                ParticleBurstView(trigger: motion.successID, color: AppTheme.primary.opacity(0.6))
                                    .frame(width: 140, height: 140)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.clubName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text([candidate.city, candidate.postalCode, candidate.region]
                                            .compactMap { $0 }
                                            .joined(separator: " · ")
                                        )
                                        .font(.system(size: 11))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer()
                                    Text("Gefunden")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                                .padding(10)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppTheme.surfaceAlt.opacity(0.8))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.primary.opacity(0.8), lineWidth: 1)
                            )
                        }
                        .buttonStyle(OnboardingCardButtonStyle())
                        .hoverLift()
                    }

                    if candidates.count > 1 {
                        ForEach(candidates, id: \.clubId) { candidate in
                            Button {
                                motion.triggerPulse()
                                onSelectCandidate(candidate)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.clubName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text([candidate.city, candidate.postalCode, candidate.region]
                                            .compactMap { $0 }
                                            .joined(separator: " · ")
                                        )
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
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AppTheme.surfaceAlt.opacity(0.7))
                                )
                            }
                            .buttonStyle(OnboardingCardButtonStyle())
                            .hoverLift(.hoverLift)
                        }
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(AppMotion.sceneReveal, value: candidates.count)
            }

            Button("Club finden") {
                motion.triggerPulse()
                onSearch()
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(region.isEmpty || clubName.isEmpty || (requiresTeam && teamName.isEmpty))
        }
        .frame(maxWidth: 460)
    }
}

struct ScanningBar: View {
    @State private var offset: CGFloat = -80

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(AppTheme.surfaceAlt)
            .frame(height: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, AppTheme.primary.opacity(0.7), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 120)
                    .offset(x: offset)
            )
            .onAppear {
                offset = -80
                withAnimation(AppMotion.scanSweep.repeatForever(autoreverses: false)) {
                    offset = 160
                }
            }
    }
}

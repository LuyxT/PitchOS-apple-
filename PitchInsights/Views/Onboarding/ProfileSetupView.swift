import SwiftUI

struct ProfileSetupView: View {
    let role: String
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var license: String
    @Binding var preferredSystem: String
    @Binding var goals: String
    @Binding var experience: String
    @Binding var boardPosition: String
    @Binding var boardResponsibilities: String
    @Binding var physioQualification: String
    let isBusy: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                OnboardingCard {
                    OnboardingInputField(title: "Vorname", text: $firstName)
                }
                OnboardingCard {
                    OnboardingInputField(title: "Nachname", text: $lastName)
                }
            }

            if role == "trainer" || role == "co_trainer" {
                OnboardingCard {
                    OnboardingInputField(title: "Lizenz", text: $license)
                }
                OnboardingCard {
                    OnboardingInputField(title: "Bevorzugtes System", text: $preferredSystem)
                }
                OnboardingCard {
                    OnboardingInputField(title: "Ziele (kommagetrennt)", text: $goals)
                }
                OnboardingCard {
                    OnboardingInputField(title: "Erfahrung", text: $experience)
                }
            } else if role == "physio" {
                OnboardingCard {
                    OnboardingInputField(title: "Qualifikation", text: $physioQualification)
                }
            } else if role == "vorstand" {
                OnboardingCard {
                    OnboardingInputField(title: "Position", text: $boardPosition)
                }
                OnboardingCard {
                    OnboardingInputField(title: "Verantwortlichkeiten", text: $boardResponsibilities)
                }
            }

            Button(isBusy ? "Speichern..." : "Profil speichern") {
                onSubmit()
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(isBusy || firstName.isEmpty || lastName.isEmpty)
        }
        .frame(maxWidth: 460)
    }
}

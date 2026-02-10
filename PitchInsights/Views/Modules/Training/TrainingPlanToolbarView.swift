import SwiftUI

struct TrainingPlanToolbarView: View {
    let plans: [TrainingPlan]
    @Binding var selectedPlanID: UUID?
    @Binding var selectedSection: TrainingPlanningWorkspaceViewModel.Section
    @Binding var title: String
    @Binding var date: Date
    @Binding var location: String
    @Binding var mainGoal: String
    @Binding var secondaryGoalsText: String
    @Binding var includeGoalInCalendar: Bool
    let isBusy: Bool

    let onCreate: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void
    let onDuplicateTemplate: () -> Void
    let onLinkToCalendar: () -> Void
    let onStartLive: () -> Void
    let onReload: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Picker("Training", selection: $selectedPlanID) {
                        if plans.isEmpty {
                            Text("Kein Training")
                                .foregroundStyle(Color.black)
                                .tag(Optional<UUID>.none)
                        }
                        ForEach(plans) { plan in
                            Text(plan.title)
                                .foregroundStyle(Color.black)
                                .tag(Optional(plan.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220)
                    .foregroundStyle(Color.black)

                    DatePicker("", selection: $date)
                        .labelsHidden()
                        .frame(width: 170)
                        .foregroundStyle(Color.black)

                    TextField("", text: $title, prompt: Text("Titel").foregroundStyle(Color.black.opacity(0.7)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                        .foregroundStyle(Color.black)

                    TextField("", text: $location, prompt: Text("Ort").foregroundStyle(Color.black.opacity(0.7)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .foregroundStyle(Color.black)

                    TextField("", text: $mainGoal, prompt: Text("Hauptziel").foregroundStyle(Color.black.opacity(0.7)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .foregroundStyle(Color.black)

                    TextField("", text: $secondaryGoalsText, prompt: Text("Nebenziele (Komma)").foregroundStyle(Color.black.opacity(0.7)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .foregroundStyle(Color.black)

                    Button {
                        guard !isBusy else { return }
                        onCreate()
                    } label: {
                        Text("Neu").foregroundStyle(Color.black)
                    }
                        .buttonStyle(PrimaryActionButtonStyle())

                    Button {
                        guard !isBusy, selectedPlanID != nil else { return }
                        onSave()
                    } label: {
                        Text("Speichern").foregroundStyle(Color.black)
                    }
                        .buttonStyle(PrimaryActionButtonStyle())

                    Button {
                        guard !isBusy, selectedPlanID != nil else { return }
                        onDelete()
                    } label: {
                        Text("Löschen").foregroundStyle(Color.black)
                    }
                        .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        guard !isBusy, selectedPlanID != nil else { return }
                        onDuplicateTemplate()
                    } label: {
                        Text("Vorlage").foregroundStyle(Color.black)
                    }
                        .buttonStyle(SecondaryActionButtonStyle())

                    Toggle("Ziel für Spieler", isOn: $includeGoalInCalendar)
                        .toggleStyle(.switch)
                        .foregroundStyle(Color.black)

                    Button {
                        guard !isBusy, selectedPlanID != nil else { return }
                        onLinkToCalendar()
                    } label: {
                        Text("In Kalender").foregroundStyle(Color.black)
                    }
                        .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        guard !isBusy, selectedPlanID != nil else { return }
                        onStartLive()
                    } label: {
                        Text("Live-Modus").foregroundStyle(Color.black)
                    }
                        .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        guard !isBusy else { return }
                        onReload()
                    } label: {
                        Text("Reload").foregroundStyle(Color.black)
                    }
                        .buttonStyle(SecondaryActionButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 2)
            }

            SegmentedControl(
                items: TrainingPlanningWorkspaceViewModel.Section.allCases,
                selection: $selectedSection,
                title: { $0.rawValue }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(AppTheme.surface)
        .foregroundStyle(Color.black)
        .tint(Color.black)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }
}

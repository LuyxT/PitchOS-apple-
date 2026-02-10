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

    private var hasSelection: Bool {
        selectedPlanID != nil
    }

    var body: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                expandedHeader
                compactHeader
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

    private var expandedHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                trainingPicker
                    .frame(minWidth: 170, maxWidth: 240)

                DatePicker("", selection: $date)
                    .labelsHidden()
                    .frame(minWidth: 150, maxWidth: 185)

                TextField("", text: $title, prompt: Text("Titel").foregroundStyle(Color.black.opacity(0.7)))
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180, maxWidth: .infinity)

                TextField("", text: $location, prompt: Text("Ort").foregroundStyle(Color.black.opacity(0.7)))
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 120, maxWidth: 180)

                TextField("", text: $mainGoal, prompt: Text("Hauptziel").foregroundStyle(Color.black.opacity(0.7)))
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 140, maxWidth: 220)

                TextField("", text: $secondaryGoalsText, prompt: Text("Nebenziele (Komma)").foregroundStyle(Color.black.opacity(0.7)))
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180, maxWidth: 260)
            }

            HStack(spacing: 8) {
                primaryActions
                Toggle("Ziel für Spieler", isOn: $includeGoalInCalendar)
                    .toggleStyle(.switch)
                    .foregroundStyle(Color.black)
                    .lineLimit(1)

                Spacer(minLength: 8)

                secondaryActions
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                trainingPicker
                    .frame(maxWidth: .infinity)

                DatePicker("", selection: $date)
                    .labelsHidden()
                    .frame(minWidth: 145, maxWidth: 180)

                Button {
                    guard !isBusy else { return }
                    onCreate()
                } label: {
                    Label("Neu", systemImage: "plus")
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button {
                    guard !isBusy, hasSelection else { return }
                    onSave()
                } label: {
                    Text("Speichern")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!hasSelection || isBusy)

                Menu("Mehr") {
                    Button("Löschen", role: .destructive) {
                        guard !isBusy, hasSelection else { return }
                        onDelete()
                    }
                    .disabled(!hasSelection || isBusy)

                    Button("Vorlage") {
                        guard !isBusy, hasSelection else { return }
                        onDuplicateTemplate()
                    }
                    .disabled(!hasSelection || isBusy)

                    Button("In Kalender") {
                        guard !isBusy, hasSelection else { return }
                        onLinkToCalendar()
                    }
                    .disabled(!hasSelection || isBusy)

                    Button("Live-Modus") {
                        guard !isBusy, hasSelection else { return }
                        onStartLive()
                    }
                    .disabled(!hasSelection || isBusy)

                    Button("Reload") {
                        guard !isBusy else { return }
                        onReload()
                    }
                    .disabled(isBusy)
                }
                .menuStyle(.borderlessButton)
                .fixedSize(horizontal: true, vertical: false)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    TextField("", text: $title, prompt: Text("Titel").foregroundStyle(Color.black.opacity(0.7)))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)

                    TextField("", text: $location, prompt: Text("Ort").foregroundStyle(Color.black.opacity(0.7)))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)

                    TextField("", text: $mainGoal, prompt: Text("Hauptziel").foregroundStyle(Color.black.opacity(0.7)))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                }

                VStack(spacing: 8) {
                    TextField("", text: $title, prompt: Text("Titel").foregroundStyle(Color.black.opacity(0.7)))
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 8) {
                        TextField("", text: $location, prompt: Text("Ort").foregroundStyle(Color.black.opacity(0.7)))
                            .textFieldStyle(.roundedBorder)
                        TextField("", text: $mainGoal, prompt: Text("Hauptziel").foregroundStyle(Color.black.opacity(0.7)))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            TextField("", text: $secondaryGoalsText, prompt: Text("Nebenziele (Komma)").foregroundStyle(Color.black.opacity(0.7)))
                .textFieldStyle(.roundedBorder)

            Toggle("Ziel für Spieler", isOn: $includeGoalInCalendar)
                .toggleStyle(.switch)
                .foregroundStyle(Color.black)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    private var trainingPicker: some View {
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
        .foregroundStyle(Color.black)
    }

    private var primaryActions: some View {
        HStack(spacing: 8) {
            Button {
                guard !isBusy else { return }
                onCreate()
            } label: {
                Text("Neu")
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Button {
                guard !isBusy, hasSelection else { return }
                onSave()
            } label: {
                Text("Speichern")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!hasSelection || isBusy)
        }
    }

    private var secondaryActions: some View {
        HStack(spacing: 8) {
            Button {
                guard !isBusy, hasSelection else { return }
                onDelete()
            } label: {
                Text("Löschen")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(!hasSelection || isBusy)

            Button {
                guard !isBusy, hasSelection else { return }
                onDuplicateTemplate()
            } label: {
                Text("Vorlage")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(!hasSelection || isBusy)

            Button {
                guard !isBusy, hasSelection else { return }
                onLinkToCalendar()
            } label: {
                Text("In Kalender")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(!hasSelection || isBusy)

            Button {
                guard !isBusy, hasSelection else { return }
                onStartLive()
            } label: {
                Text("Live-Modus")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(!hasSelection || isBusy)

            Button {
                guard !isBusy else { return }
                onReload()
            } label: {
                Text("Reload")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(isBusy)
        }
    }
}

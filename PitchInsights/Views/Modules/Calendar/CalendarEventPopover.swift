import SwiftUI

struct CalendarEventPopover: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var categories: [CalendarCategory]
    let players: [Player]
    let onSave: (CalendarEventDraft, Bool, String?) -> Void
    let onDelete: (String) -> Void

    @State private var newCategoryName: String = ""
    @State private var newCategoryColor: Color = AppTheme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.isEditing ? "Termin bearbeiten" : "Neuer Termin")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                labeledField("Titel") {
                    TextField("Terminname", text: $viewModel.draft.title)
                        .textFieldStyle(.roundedBorder)
                }

                labeledField("Datum") {
                    DatePicker("", selection: $viewModel.draft.startDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                labeledField("Ende") {
                    DatePicker("", selection: $viewModel.draft.endDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                labeledField("Kategorie") {
                    Picker("", selection: $viewModel.draft.categoryID) {
                        ForEach(categories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Neue Kategorie")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack {
                        TextField("Name", text: $newCategoryName)
                            .textFieldStyle(.roundedBorder)
                        ColorPicker("", selection: $newCategoryColor)
                            .labelsHidden()
                        Button("Hinzufügen") {
                            let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            guard !categories.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }
                            let category = CalendarCategory(
                                id: UUID().uuidString.lowercased(),
                                name: name,
                                colorHex: newCategoryColor.hexString,
                                isSystem: false
                            )
                            categories.append(category)
                            viewModel.draft.categoryID = category.id
                            newCategoryName = ""
                            newCategoryColor = AppTheme.primary
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                labeledField("Sichtbarkeit") {
                    SegmentedControl(
                        items: CalendarVisibility.allCases,
                        selection: $viewModel.draft.visibility,
                        title: { $0.rawValue }
                    )
                }

                labeledField("Zielgruppe") {
                    SegmentedControl(
                        items: CalendarAudience.allCases,
                        selection: $viewModel.draft.audience,
                        title: { $0.rawValue }
                    )
                }

                labeledField("Wiederholung") {
                    SegmentedControl(
                        items: CalendarRecurrence.allCases,
                        selection: $viewModel.draft.recurrence,
                        title: { $0.displayName }
                    )
                }

                if viewModel.draft.audience != .team {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Spieler")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(players) { player in
                                    Toggle(isOn: Binding(
                                        get: { viewModel.draft.audiencePlayerIDs.contains(player.id) },
                                        set: { isOn in
                                            if isOn {
                                                viewModel.draft.audiencePlayerIDs.append(player.id)
                                            } else {
                                                viewModel.draft.audiencePlayerIDs.removeAll { $0 == player.id }
                                            }
                                        }
                                    )) {
                                        Text(player.name)
                                            .foregroundStyle(AppTheme.textPrimary)
                                    }
                                    #if os(macOS)
                                    .toggleStyle(.checkbox)
                                    #else
                                    .toggleStyle(.switch)
                                    #endif
                                }
                            }
                        }
                        .frame(maxHeight: 140)
                    }
                }

                labeledField("Ort") {
                    TextField("Ort", text: $viewModel.draft.location)
                        .textFieldStyle(.roundedBorder)
                }

                labeledField("Notizen") {
                    TextField("Notizen", text: $viewModel.draft.notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }
            }

            HStack {
                if viewModel.isEditing, let selectedID = viewModel.selectedEventID {
                    Button("Löschen") {
                        onDelete(selectedID)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                Spacer()

                Button("Abbrechen") {
                    viewModel.closePopover()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button(viewModel.isEditing ? "Speichern" : "Erstellen") {
                    onSave(viewModel.draft, viewModel.isEditing, viewModel.selectedEventID)
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(4)
        .onAppear {
            if viewModel.draft.categoryID.isEmpty, let first = categories.first {
                viewModel.draft.categoryID = first.id
            }
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            content()
        }
    }
}

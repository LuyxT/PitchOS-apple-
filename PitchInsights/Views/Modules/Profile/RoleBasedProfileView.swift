import SwiftUI

struct RoleBasedProfileView: View {
    @Binding var profile: PersonProfile
    let permissions: ProfilePermissionSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                coreSection
                rolesSection

                if profile.core.roles.contains(.player) {
                    playerSection
                }
                if profile.core.roles.contains(.headCoach) {
                    headCoachSection
                }
                if profile.core.roles.contains(.assistantCoach) || profile.core.roles.contains(.coachingStaff) || profile.core.roles.contains(.analyst) {
                    assistantCoachSection
                }
                if profile.core.roles.contains(.athleticCoach) {
                    athleticCoachSection
                }
                if profile.core.roles.contains(.physiotherapist) {
                    medicalSection
                }
                if profile.core.roles.contains(.teamManager) {
                    teamManagerSection
                }
                if profile.core.roles.contains(.boardMember) {
                    boardSection
                }
                if profile.core.roles.contains(.facilityManager) {
                    facilitySection
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .environment(\.colorScheme, .light)
    }

    private var coreSection: some View {
        ProfileSectionView(
            title: "Basisdaten",
            subtitle: "Gemeinsame Identität und Kontaktdaten"
        ) {
            HStack(alignment: .top, spacing: 14) {
                avatarBlock
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        labeledField("Vorname") {
                            TextField("Vorname", text: $profile.core.firstName)
                                .textFieldStyle(.roundedBorder)
                                .foregroundStyle(Color.black)
                                .disabled(!permissions.canEditCore || isLocked("core.firstName"))
                        }
                        labeledField("Nachname") {
                            TextField("Nachname", text: $profile.core.lastName)
                                .textFieldStyle(.roundedBorder)
                                .foregroundStyle(Color.black)
                                .disabled(!permissions.canEditCore || isLocked("core.lastName"))
                        }
                    }

                    HStack(spacing: 10) {
                        labeledField("Geburtsdatum") {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { profile.core.dateOfBirth ?? Date() },
                                    set: { profile.core.dateOfBirth = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .disabled(!permissions.canEditCore || isLocked("core.dateOfBirth"))
                        }
                        labeledField("Alter") {
                            Text(profile.core.age.map { "\($0)" } ?? "-")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    HStack(spacing: 10) {
                        labeledField("E-Mail") {
                            TextField("E-Mail", text: $profile.core.email)
                                .textFieldStyle(.roundedBorder)
                                .foregroundStyle(Color.black)
                                .disabled(!permissions.canEditCore || isLocked("core.email"))
                        }
                        labeledField("Telefon") {
                            TextField("Telefon", text: Binding(
                                get: { profile.core.phone ?? "" },
                                set: { profile.core.phone = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .foregroundStyle(Color.black)
                            .disabled(!permissions.canEditCore || isLocked("core.phone"))
                        }
                    }

                    HStack(spacing: 10) {
                        labeledField("Vereinszugehörigkeit") {
                            TextField("Verein / Team", text: $profile.core.clubName)
                                .textFieldStyle(.roundedBorder)
                                .foregroundStyle(Color.black)
                                .disabled(!permissions.canEditCore || isLocked("core.clubName"))
                        }
                        Toggle("Aktiv", isOn: $profile.core.isActive)
                            .toggleStyle(.switch)
                            .foregroundStyle(Color.black)
                            .disabled(!permissions.canEditCore || isLocked("core.isActive"))
                    }
                }
            }

            if permissions.canViewInternalNotes {
                labeledField("Interne Notizen") {
                    TextEditor(text: $profile.core.internalNotes)
                        .frame(minHeight: 70)
                        .foregroundStyle(Color.black)
                        .scrollContentBackground(.hidden)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.surfaceAlt.opacity(0.35))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                        .disabled(!permissions.canEditCore || isLocked("core.internalNotes"))
                }
            }
        }
    }

    private var avatarBlock: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(AppTheme.primary.opacity(0.2))
                .frame(width: 70, height: 70)
                .overlay(
                    Text(initials(profile.displayName))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.primaryDark)
                )
            TextField("Profilbild-Pfad", text: Binding(
                get: { profile.core.avatarPath ?? "" },
                set: { profile.core.avatarPath = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 11))
            .foregroundStyle(Color.black)
            .disabled(!permissions.canEditCore || isLocked("core.avatarPath"))
            .frame(width: 180)
        }
        .frame(width: 190)
    }

    private var rolesSection: some View {
        ProfileSectionView(
            title: "Rollen und Sichtbarkeit",
            subtitle: "Rollen steuern die relevanten Profilfelder"
        ) {
            WrapFlow(spacing: 8, lineSpacing: 8) {
                ForEach(ProfileRoleType.allCases) { role in
                    let active = profile.core.roles.contains(role)
                    Button {
                        toggleRole(role, enabled: !active)
                    } label: {
                        Label(role.title, systemImage: role.iconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(active ? Color.black : Color.black.opacity(0.75))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(active ? AppTheme.primary.opacity(0.23) : AppTheme.surfaceAlt.opacity(0.55))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(active ? AppTheme.primary : AppTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!permissions.canEditRoles || isLocked("core.roles"))
                }
            }
        }
    }

    private var playerSection: some View {
        ProfileSectionView(
            title: "Spielerprofil",
            subtitle: "Entwicklung, Einsatz und Verfügbarkeit"
        ) {
            let roleBinding = Binding<PlayerRoleProfileData>(
                get: { profile.player ?? defaultPlayerRole() },
                set: { profile.player = $0 }
            )

            HStack(spacing: 10) {
                labeledField("Hauptposition") {
                    Picker("", selection: roleBinding.primaryPosition) {
                        ForEach(PlayerPosition.allCases) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .foregroundStyle(Color.black)
                    .disabled(!canEditPlayerSportCore || isLocked("player.primaryPosition"))
                }
                labeledField("Rückennummer") {
                    TextField("", text: intBinding(
                        get: { roleBinding.wrappedValue.jerseyNumber },
                        set: { roleBinding.wrappedValue.jerseyNumber = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!canEditPlayerSportCore || isLocked("player.jerseyNumber"))
                }
                labeledField("Verfügbarkeit") {
                    Picker("", selection: roleBinding.availability) {
                        ForEach(AvailabilityStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .foregroundStyle(Color.black)
                    .disabled(!canEditPlayerSportCore || isLocked("player.availability"))
                }
            }

            HStack(spacing: 10) {
                labeledField("Nebenpositionen") {
                    TextField(
                        "z. B. IV, DM",
                        text: commaSeparatedBinding(
                            get: { roleBinding.wrappedValue.secondaryPositions.map(\.rawValue) },
                            set: { values in
                                roleBinding.wrappedValue.secondaryPositions = values.map(PlayerPosition.from(code:))
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!canEditPlayerSportCore || isLocked("player.secondaryPositions"))
                }
                labeledField("Größe (cm)") {
                    TextField("", text: intBinding(
                        get: { roleBinding.wrappedValue.heightCm },
                        set: { roleBinding.wrappedValue.heightCm = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!canEditPlayerSportCore || isLocked("player.heightCm"))
                }
                labeledField("Gewicht (kg)") {
                    TextField("", text: intBinding(
                        get: { roleBinding.wrappedValue.weightKg },
                        set: { roleBinding.wrappedValue.weightKg = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!canEditPlayerSportCore || isLocked("player.weightKg"))
                }
            }

            HStack(spacing: 10) {
                labeledField("Starker Fuß") {
                    Picker("", selection: roleBinding.preferredFoot) {
                        Text("-").tag(Optional<PreferredFoot>.none)
                        ForEach(PreferredFoot.allCases) { foot in
                            Text(foot.rawValue).tag(Optional(foot))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .foregroundStyle(Color.black)
                    .disabled(!canEditPlayerSportCore || isLocked("player.preferredFoot"))
                }
                labeledField("Bevorzugte Rolle im System") {
                    TextField("z. B. Achter links", text: roleBinding.preferredSystemRole)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(Color.black)
                        .disabled(!canEditPlayerSportCore || isLocked("player.preferredSystemRole"))
                }
                labeledField("Belastbarkeit") {
                    Picker("", selection: roleBinding.loadCapacity) {
                        ForEach(ProfilePlayerLoadCapacity.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .foregroundStyle(Color.black)
                    .disabled(!canEditPlayerSportCore || isLocked("player.loadCapacity"))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                labeledField("Sportliche Ziele (Saison)") {
                    TextEditor(text: roleBinding.seasonGoals)
                        .frame(minHeight: 58)
                        .foregroundStyle(Color.black)
                        .disabled(!permissions.canEditSports || isLocked("player.seasonGoals"))
                        .overlay(roundedTextEditorBorder)
                }
                labeledField("Sportliche Ziele (langfristig)") {
                    TextEditor(text: roleBinding.longTermGoals)
                        .frame(minHeight: 58)
                        .foregroundStyle(Color.black)
                        .disabled(!permissions.canEditSports || isLocked("player.longTermGoals"))
                        .overlay(roundedTextEditorBorder)
                }
                labeledField("Werdegang") {
                    TextEditor(text: roleBinding.pathway)
                        .frame(minHeight: 58)
                        .foregroundStyle(Color.black)
                        .disabled(!canEditPlayerSportCore || isLocked("player.pathway"))
                        .overlay(roundedTextEditorBorder)
                }
                if permissions.canViewMedicalInternals {
                    labeledField("Verletzungshistorie (grob)") {
                        TextEditor(text: roleBinding.injuryHistory)
                            .frame(minHeight: 58)
                            .foregroundStyle(Color.black)
                            .disabled(!permissions.canEditMedical || isLocked("player.injuryHistory"))
                            .overlay(roundedTextEditorBorder)
                    }
                }
            }
        }
    }

    private var headCoachSection: some View {
        ProfileSectionView(
            title: "Trainerprofil",
            subtitle: "Kompetenz, Philosophie und Verantwortlichkeit"
        ) {
            let value = Binding<HeadCoachProfileData>(
                get: { profile.headCoach ?? defaultHeadCoach() },
                set: { profile.headCoach = $0 }
            )

            HStack(spacing: 10) {
                labeledField("Trainerlizenzen") {
                    TextField("UEFA A, ...", text: commaSeparatedBinding(
                        get: { value.wrappedValue.licenses },
                        set: { value.wrappedValue.licenses = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("headCoach.licenses"))
                }
                labeledField("Aus- und Fortbildungen") {
                    TextField("Athletik, Scouting, ...", text: commaSeparatedBinding(
                        get: { value.wrappedValue.education },
                        set: { value.wrappedValue.education = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("headCoach.education"))
                }
            }

            HStack(spacing: 10) {
                labeledField("Bevorzugte Spielsysteme") {
                    TextField("4-3-3, 3-4-2-1", text: commaSeparatedBinding(
                        get: { value.wrappedValue.preferredSystems },
                        set: { value.wrappedValue.preferredSystems = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("headCoach.preferredSystems"))
                }
                Toggle("Hauptansprechpartner", isOn: value.isPrimaryContact)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("headCoach.isPrimaryContact"))
            }

            labeledField("Werdegang") {
                TextEditor(text: commaSeparatedBinding(
                    get: { value.wrappedValue.careerPath },
                    set: { value.wrappedValue.careerPath = $0 }
                ))
                .frame(minHeight: 50)
                .foregroundStyle(Color.black)
                .disabled(!permissions.canEditResponsibilities || isLocked("headCoach.careerPath"))
                .overlay(roundedTextEditorBorder)
            }

            labeledField("Spielphilosophie") {
                TextEditor(text: value.matchPhilosophy)
                    .frame(minHeight: 54)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("headCoach.matchPhilosophy"))
                    .overlay(roundedTextEditorBorder)
            }

            labeledField("Trainingsphilosophie") {
                TextEditor(text: value.trainingPhilosophy)
                    .frame(minHeight: 54)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("headCoach.trainingPhilosophy"))
                    .overlay(roundedTextEditorBorder)
            }

            labeledField("Persönliche Ziele") {
                TextEditor(text: value.personalGoals)
                    .frame(minHeight: 54)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("headCoach.personalGoals"))
                    .overlay(roundedTextEditorBorder)
            }

            labeledField("Aktuelle Verantwortlichkeiten") {
                TextField("Team 1, U19, Defensivgruppe", text: commaSeparatedBinding(
                    get: { value.wrappedValue.responsibilities },
                    set: { value.wrappedValue.responsibilities = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color.black)
                .disabled(!permissions.canEditResponsibilities || isLocked("headCoach.responsibilities"))
            }
        }
    }

    private var assistantCoachSection: some View {
        ProfileSectionView(
            title: "Co-Trainer / Trainerteam",
            subtitle: "Operativer Fokus und Gruppenverantwortungen"
        ) {
            let value = Binding<AssistantCoachProfileData>(
                get: { profile.assistantCoach ?? defaultAssistant() },
                set: { profile.assistantCoach = $0 }
            )

            HStack(spacing: 10) {
                labeledField("Lizenzen") {
                    TextField("z. B. DFB-Elite", text: commaSeparatedBinding(
                        get: { value.wrappedValue.licenses },
                        set: { value.wrappedValue.licenses = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("assistant.licenses"))
                }
                labeledField("Zuständigkeitsbereiche") {
                    TextField("Standards, Analyse, Athletik", text: commaSeparatedBinding(
                        get: { value.wrappedValue.focusAreas },
                        set: { value.wrappedValue.focusAreas = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("assistant.focusAreas"))
                }
            }

            labeledField("Operative Schwerpunkte") {
                TextEditor(text: value.operationalFocus)
                    .frame(minHeight: 54)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("assistant.operationalFocus"))
                    .overlay(roundedTextEditorBorder)
            }

            labeledField("Gruppenverantwortungen") {
                TextField("Defensive, Offensive, Reha", text: commaSeparatedBinding(
                    get: { value.wrappedValue.groupResponsibilities },
                    set: { value.wrappedValue.groupResponsibilities = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color.black)
                .disabled(!permissions.canEditResponsibilities || isLocked("assistant.groupResponsibilities"))
            }

            labeledField("Trainingsbeteiligung") {
                TextEditor(text: value.trainingInvolvement)
                    .frame(minHeight: 54)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("assistant.trainingInvolvement"))
                    .overlay(roundedTextEditorBorder)
            }
        }
    }

    private var athleticCoachSection: some View {
        ProfileSectionView(
            title: "Athletiktrainer",
            subtitle: "Leistungsaufbau und Belastungssteuerung"
        ) {
            let value = Binding<AthleticCoachProfileData>(
                get: { profile.athleticCoach ?? defaultAthletic() },
                set: { profile.athleticCoach = $0 }
            )

            HStack(spacing: 10) {
                labeledField("Zertifikate") {
                    TextField("S&C, Reha, ...", text: commaSeparatedBinding(
                        get: { value.wrappedValue.certifications },
                        set: { value.wrappedValue.certifications = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("athletic.certifications"))
                }
                labeledField("Trainingsschwerpunkte") {
                    TextField("Kraft, Schnelligkeit, Ausdauer", text: commaSeparatedBinding(
                        get: { value.wrappedValue.focusAreas },
                        set: { value.wrappedValue.focusAreas = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("athletic.focusAreas"))
                }
            }

            HStack(spacing: 10) {
                labeledField("Erfahrung Altersklassen") {
                    TextField("U17, U19, Senioren", text: commaSeparatedBinding(
                        get: { value.wrappedValue.ageGroupExperience },
                        set: { value.wrappedValue.ageGroupExperience = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("athletic.ageGroups"))
                }
                labeledField("Gruppenverantwortungen") {
                    TextField("Reha-Gruppe, Sprintgruppe", text: commaSeparatedBinding(
                        get: { value.wrappedValue.groupResponsibilities },
                        set: { value.wrappedValue.groupResponsibilities = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("athletic.groupResponsibilities"))
                }
            }

            labeledField("Beteiligung Trainingsplanung") {
                TextEditor(text: value.planningInvolvement)
                    .frame(minHeight: 54)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("athletic.planningInvolvement"))
                    .overlay(roundedTextEditorBorder)
            }
        }
    }

    private var medicalSection: some View {
        ProfileSectionView(
            title: "Physiotherapeut / medizinisches Personal",
            subtitle: "Qualifikation und organisatorische Betreuung"
        ) {
            let value = Binding<MedicalProfileData>(
                get: { profile.medical ?? defaultMedical() },
                set: { profile.medical = $0 }
            )

            HStack(spacing: 10) {
                labeledField("Ausbildung") {
                    TextField("Physiotherapie, Sporttherapie", text: commaSeparatedBinding(
                        get: { value.wrappedValue.education },
                        set: { value.wrappedValue.education = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditMedical || isLocked("medical.education"))
                }
                labeledField("Zusatzqualifikationen") {
                    TextField("Manuelle Therapie, Taping", text: commaSeparatedBinding(
                        get: { value.wrappedValue.additionalQualifications },
                        set: { value.wrappedValue.additionalQualifications = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditMedical || isLocked("medical.additionalQualifications"))
                }
            }

            HStack(spacing: 10) {
                labeledField("Fachschwerpunkte") {
                    TextField("Sprunggelenk, Hamstring", text: commaSeparatedBinding(
                        get: { value.wrappedValue.specialties },
                        set: { value.wrappedValue.specialties = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditMedical || isLocked("medical.specialties"))
                }
                labeledField("Betreute Mannschaften") {
                    TextField("1. Mannschaft, U19", text: commaSeparatedBinding(
                        get: { value.wrappedValue.assignedTeams },
                        set: { value.wrappedValue.assignedTeams = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditMedical || isLocked("medical.assignedTeams"))
                }
            }

            labeledField("Organisatorische Verfügbarkeit") {
                TextEditor(text: value.organizationalAvailability)
                    .frame(minHeight: 48)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditMedical || isLocked("medical.organizationalAvailability"))
                    .overlay(roundedTextEditorBorder)
            }

            if permissions.canViewMedicalInternals {
                labeledField("Interne medizinische Notizen") {
                    TextEditor(text: value.protectedInternalNotes)
                        .frame(minHeight: 64)
                        .foregroundStyle(Color.black)
                        .disabled(!permissions.canEditMedical || isLocked("medical.protectedInternalNotes"))
                        .overlay(roundedTextEditorBorder)
                }
            }
        }
    }

    private var teamManagerSection: some View {
        ProfileSectionView(
            title: "Teammanager / Betreuer",
            subtitle: "Organisation, Kommunikation, Verantwortung"
        ) {
            let value = Binding<TeamManagerProfileData>(
                get: { profile.teamManager ?? defaultTeamManager() },
                set: { profile.teamManager = $0 }
            )

            HStack(spacing: 10) {
                labeledField("Rolle im Verein") {
                    TextField("Organisation / Teamleitung", text: value.clubFunction)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(Color.black)
                        .disabled(!permissions.canEditResponsibilities || isLocked("manager.clubFunction"))
                }
                labeledField("Kommunikationsverantwortung") {
                    TextField("Hauptkontakt Eltern / Spieler", text: value.communicationOwnership)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(Color.black)
                        .disabled(!permissions.canEditResponsibilities || isLocked("manager.communicationOwnership"))
                }
            }

            HStack(spacing: 10) {
                labeledField("Zuständigkeiten") {
                    TextField("Spieltage, Material, Reisen", text: commaSeparatedBinding(
                        get: { value.wrappedValue.responsibilities },
                        set: { value.wrappedValue.responsibilities = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("manager.responsibilities"))
                }
                labeledField("Organisatorische Aufgaben") {
                    TextField("Passwesen, Fahrtplanung", text: commaSeparatedBinding(
                        get: { value.wrappedValue.operationalTasks },
                        set: { value.wrappedValue.operationalTasks = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("manager.operationalTasks"))
                }
            }

            labeledField("Erreichbarkeit intern") {
                TextEditor(text: value.internalAvailability)
                    .frame(minHeight: 48)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("manager.internalAvailability"))
                    .overlay(roundedTextEditorBorder)
            }
        }
    }

    private var boardSection: some View {
        ProfileSectionView(
            title: "Vorstand / Vereinsverantwortliche",
            subtitle: "Funktion und Verantwortungsbereiche"
        ) {
            let value = Binding<BoardProfileData>(
                get: { profile.board ?? defaultBoard() },
                set: { profile.board = $0 }
            )

            HStack(spacing: 10) {
                labeledField("Funktion im Vorstand") {
                    TextField("z. B. Sportlicher Leiter", text: value.boardFunction)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(Color.black)
                        .disabled(!permissions.canEditResponsibilities || isLocked("board.boardFunction"))
                }
                labeledField("Verantwortungsbereiche") {
                    TextField("Nachwuchs, Infrastruktur", text: commaSeparatedBinding(
                        get: { value.wrappedValue.responsibilityAreas },
                        set: { value.wrappedValue.responsibilityAreas = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("board.responsibilityAreas"))
                }
            }

            HStack(spacing: 10) {
                DatePicker("Amtszeit Start", selection: Binding(
                    get: { value.wrappedValue.termStart ?? Date() },
                    set: { value.wrappedValue.termStart = $0 }
                ), displayedComponents: .date)
                .foregroundStyle(Color.black)
                .disabled(!permissions.canEditResponsibilities || isLocked("board.termStart"))

                DatePicker("Amtszeit Ende", selection: Binding(
                    get: { value.wrappedValue.termEnd ?? Date() },
                    set: { value.wrappedValue.termEnd = $0 }
                ), displayedComponents: .date)
                .foregroundStyle(Color.black)
                .disabled(!permissions.canEditResponsibilities || isLocked("board.termEnd"))
            }

            labeledField("Kontaktoptionen") {
                TextField("E-Mail intern, Telefon intern", text: commaSeparatedBinding(
                    get: { value.wrappedValue.contactOptions },
                    set: { value.wrappedValue.contactOptions = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color.black)
                .disabled(!permissions.canEditResponsibilities || isLocked("board.contactOptions"))
            }
        }
    }

    private var facilitySection: some View {
        ProfileSectionView(
            title: "Platzwart / Infrastruktur",
            subtitle: "Anlagenbezogene Zuständigkeiten"
        ) {
            let value = Binding<FacilityProfileData>(
                get: { profile.facility ?? defaultFacility() },
                set: { profile.facility = $0 }
            )

            HStack(spacing: 10) {
                labeledField("Zuständigkeiten") {
                    TextField("Plätze, Kabinen, Material", text: commaSeparatedBinding(
                        get: { value.wrappedValue.responsibilities },
                        set: { value.wrappedValue.responsibilities = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("facility.responsibilities"))
                }
                labeledField("Anlagenverantwortung") {
                    TextField("Rasenplatz, Kunstrasen, Halle", text: commaSeparatedBinding(
                        get: { value.wrappedValue.facilities },
                        set: { value.wrappedValue.facilities = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("facility.facilities"))
                }
            }

            labeledField("Erreichbarkeit") {
                TextEditor(text: value.availability)
                    .frame(minHeight: 48)
                    .foregroundStyle(Color.black)
                    .disabled(!permissions.canEditResponsibilities || isLocked("facility.availability"))
                    .overlay(roundedTextEditorBorder)
            }
        }
    }

    private var canEditPlayerSportCore: Bool {
        permissions.canEditSports && !permissions.canEditOwnGoalsOnly
    }

    private var roundedTextEditorBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(AppTheme.border, lineWidth: 1)
    }

    private func toggleRole(_ role: ProfileRoleType, enabled: Bool) {
        guard permissions.canEditRoles else { return }

        if enabled {
            if !profile.core.roles.contains(role) {
                profile.core.roles.append(role)
            }
        } else {
            profile.core.roles.removeAll { $0 == role }
        }
        if profile.core.roles.isEmpty {
            profile.core.roles = [.player]
        }
        hydrateRoleModels()
    }

    private func hydrateRoleModels() {
        if profile.core.roles.contains(.player), profile.player == nil {
            profile.player = defaultPlayerRole()
        }
        if profile.core.roles.contains(.headCoach), profile.headCoach == nil {
            profile.headCoach = defaultHeadCoach()
        }
        if (profile.core.roles.contains(.assistantCoach) || profile.core.roles.contains(.coachingStaff) || profile.core.roles.contains(.analyst)),
           profile.assistantCoach == nil {
            profile.assistantCoach = defaultAssistant()
        }
        if profile.core.roles.contains(.athleticCoach), profile.athleticCoach == nil {
            profile.athleticCoach = defaultAthletic()
        }
        if profile.core.roles.contains(.physiotherapist), profile.medical == nil {
            profile.medical = defaultMedical()
        }
        if profile.core.roles.contains(.teamManager), profile.teamManager == nil {
            profile.teamManager = defaultTeamManager()
        }
        if profile.core.roles.contains(.boardMember), profile.board == nil {
            profile.board = defaultBoard()
        }
        if profile.core.roles.contains(.facilityManager), profile.facility == nil {
            profile.facility = defaultFacility()
        }
    }

    private func isLocked(_ key: String) -> Bool {
        profile.lockedFieldKeys.contains(key)
    }

    private func defaultPlayerRole() -> PlayerRoleProfileData {
        PlayerRoleProfileData(
            primaryPosition: .zm,
            secondaryPositions: [],
            jerseyNumber: nil,
            heightCm: nil,
            weightKg: nil,
            preferredFoot: nil,
            preferredSystemRole: "",
            seasonGoals: "",
            longTermGoals: "",
            pathway: "",
            loadCapacity: .free,
            injuryHistory: "",
            availability: .fit
        )
    }

    private func defaultHeadCoach() -> HeadCoachProfileData {
        HeadCoachProfileData(
            licenses: [],
            education: [],
            careerPath: [],
            preferredSystems: [],
            matchPhilosophy: "",
            trainingPhilosophy: "",
            personalGoals: "",
            responsibilities: [],
            isPrimaryContact: true
        )
    }

    private func defaultAssistant() -> AssistantCoachProfileData {
        AssistantCoachProfileData(
            licenses: [],
            focusAreas: [],
            operationalFocus: "",
            groupResponsibilities: [],
            trainingInvolvement: ""
        )
    }

    private func defaultAthletic() -> AthleticCoachProfileData {
        AthleticCoachProfileData(
            certifications: [],
            focusAreas: [],
            ageGroupExperience: [],
            planningInvolvement: "",
            groupResponsibilities: []
        )
    }

    private func defaultMedical() -> MedicalProfileData {
        MedicalProfileData(
            education: [],
            additionalQualifications: [],
            specialties: [],
            assignedTeams: [],
            organizationalAvailability: "",
            protectedInternalNotes: ""
        )
    }

    private func defaultTeamManager() -> TeamManagerProfileData {
        TeamManagerProfileData(
            clubFunction: "",
            responsibilities: [],
            operationalTasks: [],
            communicationOwnership: "",
            internalAvailability: ""
        )
    }

    private func defaultBoard() -> BoardProfileData {
        BoardProfileData(
            boardFunction: "",
            termStart: nil,
            termEnd: nil,
            responsibilityAreas: [],
            contactOptions: []
        )
    }

    private func defaultFacility() -> FacilityProfileData {
        FacilityProfileData(
            responsibilities: [],
            facilities: [],
            availability: ""
        )
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.65))
            content()
        }
    }

    private func initials(_ name: String) -> String {
        let components = name.split(separator: " ").map(String.init)
        let first = components.first?.prefix(1) ?? ""
        let second = components.dropFirst().first?.prefix(1) ?? ""
        return "\(first)\(second)".uppercased()
    }

    private func commaSeparatedBinding(
        get: @escaping () -> [String],
        set: @escaping ([String]) -> Void
    ) -> Binding<String> {
        Binding<String>(
            get: { get().joined(separator: ", ") },
            set: { newValue in
                let values = newValue
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                set(values)
            }
        )
    }

    private func intBinding(
        get: @escaping () -> Int?,
        set: @escaping (Int?) -> Void
    ) -> Binding<String> {
        Binding<String>(
            get: { get().map(String.init) ?? "" },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    set(nil)
                } else {
                    set(Int(trimmed))
                }
            }
        )
    }
}

private struct WrapFlow<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: Content

    init(
        spacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            FlowLayout(spacing: spacing) {
                content
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 600
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

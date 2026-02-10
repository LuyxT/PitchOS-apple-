import SwiftUI

struct TacticsInspectorView: View {
    let selectedPlayer: Player?
    let selectedPlacement: TacticalPlacement?
    let onUpdateRole: (String) -> Void
    let onUpdateZone: (TacticalZone?) -> Void
    let onSendToBench: () -> Void
    let onToggleExclude: () -> Void
    let onOpenProfile: () -> Void

    @State private var customRole = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspector")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if let selectedPlayer {
                playerSection(selectedPlayer)
                roleSection
                zoneSection
                actionsSection
            } else {
                Text("Spieler auf dem Feld auswählen")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
        .onAppear {
            customRole = selectedPlacement?.role.name ?? ""
        }
        .onChange(of: selectedPlacement?.id) { _, _ in
            customRole = selectedPlacement?.role.name ?? ""
        }
    }

    private func playerSection(_ player: Player) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(player.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("#\(player.number) • \(player.primaryPosition.rawValue)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text(player.availability.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(statusColor(player.availability))
        }
    }

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rolle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Menu(selectedPlacement?.role.name ?? "Rolle wählen") {
                ForEach(TacticalRole.presets, id: \.name) { role in
                    Button(role.name) {
                        customRole = role.name
                        onUpdateRole(role.name)
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .foregroundStyle(AppTheme.textPrimary)

            TextField("Benutzerdefinierte Rolle", text: $customRole)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(AppTheme.textPrimary)
                .onSubmit {
                    onUpdateRole(customRole)
                }
        }
    }

    private var zoneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zone")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Picker(
                "Zone",
                selection: Binding<TacticalZone?>(
                    get: { selectedPlacement?.zone },
                    set: { onUpdateZone($0) }
                )
            ) {
                Text("Keine Zone").tag(Optional<TacticalZone>.none)
                ForEach(TacticalZone.allCases) { zone in
                    Text(zone.rawValue).tag(Optional(zone))
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 8) {
            Button("Profil öffnen", action: onOpenProfile)
                .buttonStyle(SecondaryActionButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Auf Bank setzen", action: onSendToBench)
                .buttonStyle(SecondaryActionButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("In Spielkader ausblenden", action: onToggleExclude)
                .buttonStyle(SecondaryActionButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusColor(_ status: AvailabilityStatus) -> Color {
        switch status {
        case .fit:
            return AppTheme.primaryDark
        case .limited:
            return .orange
        case .unavailable:
            return .red
        }
    }
}

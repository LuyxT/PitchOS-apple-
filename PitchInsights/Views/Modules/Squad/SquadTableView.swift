import SwiftUI

struct SquadTableView: View {
    @ObservedObject var viewModel: SquadViewModel
    let players: [Player]
    let onOpenProfile: (Player) -> Void
    let onDuplicate: (Player) -> Void
    let onDelete: (Player) -> Void
    let onSetAvailability: (Set<UUID>, AvailabilityStatus) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        SquadRowView(
                            player: player,
                            isSelected: viewModel.selectedPlayerIDs.contains(player.id),
                            onTap: {
                                viewModel.select(playerID: player.id, orderedPlayers: players)
                            },
                            onDoubleTap: {
                                onOpenProfile(player)
                            },
                            onOpenProfile: {
                                onOpenProfile(player)
                            },
                            onDuplicate: {
                                onDuplicate(player)
                            },
                            onDelete: {
                                onDelete(player)
                            },
                            onSetAvailability: { status in
                                let targetIDs = viewModel.selectedPlayerIDs.contains(player.id)
                                    ? viewModel.selectedPlayerIDs
                                    : [player.id]
                                onSetAvailability(targetIDs, status)
                            }
                        )
                        .background(index.isMultiple(of: 2) ? AppTheme.surface : AppTheme.surfaceAlt.opacity(0.28))
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            headerButton(title: "#", field: .number, width: 56, alignment: .leading)
            headerButton(title: "Name", field: .name, width: 180, alignment: .leading)
            headerButton(title: "Position", field: .primaryPosition, width: 90, alignment: .leading)
            headerButton(title: "Verfügbarkeit", field: .availability, width: 120, alignment: .leading)
            headerButton(title: "Teamstatus", field: .squadStatus, width: 110, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceAlt.opacity(0.5))
    }

    private func headerButton(title: String, field: SquadSortField, width: CGFloat, alignment: Alignment) -> some View {
        Button {
            Haptics.trigger(.light)
            withAnimation(AppMotion.settle) {
                viewModel.toggleSort(field)
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                if viewModel.sortField == field {
                    Image(systemName: viewModel.sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 8))
                }
            }
            .foregroundStyle(AppTheme.textSecondary)
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
        .interactiveSurface(hoverScale: 1.01, pressScale: 0.99, hoverShadowOpacity: 0.1, feedback: .light)
    }
}

private struct SquadRowView: View {
    let player: Player
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onOpenProfile: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onSetAvailability: (AvailabilityStatus) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(player.number)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 56, alignment: .leading)

            Text(player.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 180, alignment: .leading)

            Text(player.primaryPosition.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 90, alignment: .leading)

            statusBadge(player.availability.rawValue, color: availabilityColor(player.availability))
                .frame(width: 120, alignment: .leading)

            Text(player.squadStatus.rawValue)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 110, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? AppTheme.primary.opacity(0.16) : (isHovering ? AppTheme.hover : Color.clear))
        )
        .scaleEffect(isHovering ? 1.01 : 1)
        .shadow(color: AppTheme.shadow.opacity(isHovering ? 0.12 : 0), radius: isHovering ? 6 : 0, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.trigger(.light)
            withAnimation(AppMotion.settle) {
                onTap()
            }
        }
        .onTapGesture(count: 2) {
            Haptics.trigger(.light)
            onDoubleTap()
        }
        .onHover { isHovering = $0 }
        .animation(AppMotion.hover, value: isHovering)
        .contextMenu {
            Button("Profil öffnen", action: onOpenProfile)
            Button("Bearbeiten", action: onOpenProfile)
            Button("Duplizieren", action: onDuplicate)
            Menu("Status setzen") {
                ForEach(AvailabilityStatus.allCases) { state in
                    Button(state.rawValue) {
                        Haptics.trigger(.soft)
                        onSetAvailability(state)
                    }
                }
            }
            Divider()
            Button("Löschen", role: .destructive) {
                Haptics.trigger(.soft)
                onDelete()
            }
        }
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
            )
    }

    private func availabilityColor(_ status: AvailabilityStatus) -> Color {
        switch status {
        case .fit: return AppTheme.primaryDark
        case .limited: return .orange
        case .unavailable: return .red
        }
    }
}

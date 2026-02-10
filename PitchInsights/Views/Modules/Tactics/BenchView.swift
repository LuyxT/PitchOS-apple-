import SwiftUI
import UniformTypeIdentifiers

struct BenchView: View {
    let players: [Player]
    let selectedIDs: Set<UUID>
    let playerTokenScale: Double
    let onSelectPlayer: (UUID, Bool) -> Void
    let onDropPlayerToBench: (UUID) -> Void
    let onOpenProfile: (UUID) -> Void
    let onToggleExclude: (UUID) -> Void

    @State private var dropHighlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bank")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(players.count) Spieler")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: tokenWidth), spacing: 8)], spacing: 8) {
                    ForEach(players) { player in
                        PlayerTokenView(
                            player: player,
                            role: nil,
                            isSelected: selectedIDs.contains(player.id),
                            compact: true,
                            fixedWidth: tokenWidth
                        )
                        .frame(width: tokenWidth)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectPlayer(player.id, false)
                        }
                        .onDrag {
                            NSItemProvider(object: player.id.uuidString as NSString)
                        }
                        .contextMenu {
                            Button("Profil öffnen") {
                                onOpenProfile(player.id)
                            }
                            Button("Aus Spielkader ausblenden") {
                                onToggleExclude(player.id)
                            }
                        }
                    }
                }
                .padding(4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(dropHighlighted ? AppTheme.hover : AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(dropHighlighted ? AppTheme.primary : AppTheme.border, lineWidth: 1)
                )
        )
        .onDrop(
            of: [UTType.text.identifier],
            delegate: BenchDropDelegate(
                isTargeted: $dropHighlighted,
                onDropPlayerToBench: onDropPlayerToBench
            )
        )
    }

    private var tokenWidth: CGFloat {
        CGFloat(max(112, min(180, 144 * playerTokenScale)))
    }
}

private struct BenchDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDropPlayerToBench: (UUID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text.identifier])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { isTargeted = false }
        guard let provider = info.itemProviders(for: [UTType.text.identifier]).first else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            guard let idString = decodeItem(item), let id = UUID(uuidString: idString) else { return }
            DispatchQueue.main.async {
                onDropPlayerToBench(id)
            }
        }
        return true
    }

    private func decodeItem(_ item: NSSecureCoding?) -> String? {
        if let data = item as? Data {
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let string = item as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let nsString = item as? NSString {
            return (nsString as String).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}

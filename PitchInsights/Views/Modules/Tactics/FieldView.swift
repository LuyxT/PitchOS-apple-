import SwiftUI
import UniformTypeIdentifiers

struct FieldView: View {
    let placements: [TacticalPlacement]
    let playersByID: [UUID: Player]
    let selectedPlayerIDs: Set<UUID>
    let showZones: Bool
    let showLines: Bool
    let showOpponent: Bool
    let opponentMode: OpponentMode
    let opponentMarkers: [OpponentMarker]
    let neutralMarkers: [TacticalNeutralMarker]
    let drawingsVisible: Bool
    let drawings: [TacticalDrawing]
    let draftDrawing: TacticalDrawing?
    let isDrawingMode: Bool
    let playerTokenScale: Double
    let selectedDrawingIDs: Set<UUID>
    let onSelectPlayer: (UUID, Bool) -> Void
    let onDropPlayer: (UUID, TacticalPoint) -> Void
    let onOpenProfile: (UUID) -> Void
    let onSendToBench: (UUID) -> Void
    let onRemoveFromLineup: (UUID) -> Void
    let onToggleExclude: (UUID) -> Void
    let onUpdateRole: (UUID, String) -> Void
    let onUpdateZone: (UUID, TacticalZone?) -> Void
    let onSelectDrawing: (UUID, Bool) -> Void
    let onDeleteDrawing: (UUID) -> Void
    let onToggleTemporary: (UUID) -> Void
    let onPersistDrawing: (UUID) -> Void
    let onMoveOpponentMarker: (Int, TacticalPoint) -> Void
    let onRenameOpponentMarker: (Int) -> Void
    let onMoveNeutralMarker: (Int, TacticalPoint) -> Void
    let onRenameNeutralMarker: (UUID) -> Void
    let onDeleteNeutralMarker: (UUID) -> Void
    let onBeginDrawing: (TacticalPoint) -> Void
    let onUpdateDrawing: (TacticalPoint) -> Void
    let onFinishDrawing: () -> Void
    let onClearSelection: () -> Void

    @State private var dropHighlighted = false
    @State private var isDrawingGestureActive = false
    @State private var dragStartPoints: [UUID: TacticalPoint] = [:]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                fieldBase

                if showZones {
                    zonesOverlay
                }

                if showLines {
                    linesOverlay
                }

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onClearSelection()
                    }

                DrawingCanvasLayer(
                    drawings: drawings,
                    draftDrawing: draftDrawing,
                    drawingsVisible: drawingsVisible,
                    isDrawingMode: isDrawingMode,
                    selectedDrawingIDs: selectedDrawingIDs,
                    onSelectDrawing: onSelectDrawing,
                    onDeleteDrawing: onDeleteDrawing,
                    onToggleTemporary: onToggleTemporary,
                    onPersistDrawing: onPersistDrawing
                )

                if showOpponent {
                    OpponentOverlayView(
                        mode: opponentMode,
                        markers: opponentMarkers,
                        size: proxy.size,
                        isInteractive: !isDrawingMode,
                        onMoveMarker: onMoveOpponentMarker,
                        onRenameMarker: onRenameOpponentMarker
                    )
                }

                NeutralMarkerOverlayView(
                    markers: neutralMarkers,
                    size: proxy.size,
                    isInteractive: !isDrawingMode,
                    onMoveMarker: onMoveNeutralMarker,
                    onRenameMarker: onRenameNeutralMarker,
                    onDeleteMarker: onDeleteNeutralMarker
                )

                ForEach(placements) { placement in
                    if let player = playersByID[placement.playerID] {
                        let isSelected = selectedPlayerIDs.contains(player.id)
                        PlayerTokenView(
                            player: player,
                            role: placement.role.name,
                            isSelected: isSelected,
                            compact: true,
                            fixedWidth: playerTokenWidth
                        )
                        .frame(width: playerTokenWidth, height: playerTokenHeight, alignment: .leading)
                        .clipped()
                        .contentShape(Rectangle())
                        .offset(tokenOffset(for: placement.point, in: proxy.size))
                        .onTapGesture {
                            onSelectPlayer(player.id, false)
                        }
                        .gesture(placementDragGesture(placement: placement, playerID: player.id, size: proxy.size))
                        .contextMenu {
                            Button("Profil öffnen") {
                                onOpenProfile(player.id)
                            }

                            Menu("Rolle ändern") {
                                ForEach(TacticalRole.presets, id: \.name) { preset in
                                    Button(preset.name) {
                                        onUpdateRole(player.id, preset.name)
                                    }
                                }
                            }

                            Menu("Zone") {
                                Button("Keine Zone") {
                                    onUpdateZone(player.id, nil)
                                }
                                ForEach(TacticalZone.allCases) { zone in
                                    Button(zone.rawValue) {
                                        onUpdateZone(player.id, zone)
                                    }
                                }
                            }

                            Button("Auf Bank setzen") {
                                onSendToBench(player.id)
                            }
                            Button("Aus Aufstellung entfernen") {
                                onRemoveFromLineup(player.id)
                            }
                            Button("In Spielkader ausblenden") {
                                onToggleExclude(player.id)
                            }
                        }
                        .allowsHitTesting(!isDrawingMode)
                        .zIndex(isSelected ? 12 : 8)
                    }
                }

                if isDrawingMode {
                    drawingInputLayer(size: proxy.size)
                        .zIndex(20)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(dropHighlighted ? AppTheme.hover : AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(dropHighlighted ? AppTheme.primary : AppTheme.border, lineWidth: 1)
                    )
            )
            .onDrop(
                of: [UTType.text.identifier],
                delegate: FieldDropDelegate(
                    size: proxy.size,
                    isTargeted: $dropHighlighted,
                    onDropPlayer: onDropPlayer
                )
            )
        }
    }

    private var playerTokenWidth: CGFloat {
        CGFloat(max(120, min(220, 170 * playerTokenScale)))
    }

    private var playerTokenHeight: CGFloat {
        58
    }

    private func tokenOffset(for point: TacticalPoint, in size: CGSize) -> CGSize {
        let center = point.cgPoint(in: size)
        return CGSize(
            width: center.x - (playerTokenWidth / 2),
            height: center.y - (playerTokenHeight / 2)
        )
    }

    private func drawingInputLayer(size: CGSize) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = TacticalPoint.from(value.location, in: size)
                        if !isDrawingGestureActive {
                            isDrawingGestureActive = true
                            onBeginDrawing(point)
                        } else {
                            onUpdateDrawing(point)
                        }
                    }
                    .onEnded { _ in
                        if isDrawingGestureActive {
                            onFinishDrawing()
                        }
                        isDrawingGestureActive = false
                    }
            )
            .onDisappear {
                isDrawingGestureActive = false
            }
    }

    private func placementDragGesture(placement: TacticalPlacement, playerID: UUID, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragStartPoints[playerID] == nil {
                    dragStartPoints[playerID] = placement.point
                    onSelectPlayer(playerID, false)
                }

                guard let start = dragStartPoints[playerID] else { return }
                let dx = Double(value.translation.width / max(size.width, 1))
                let dy = Double(value.translation.height / max(size.height, 1))
                let moved = TacticalPoint(x: start.x + dx, y: start.y + dy)
                onDropPlayer(playerID, moved)
            }
            .onEnded { _ in
                dragStartPoints.removeValue(forKey: playerID)
            }
    }

    private var fieldBase: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.87, green: 0.93, blue: 0.86), Color(red: 0.8, green: 0.89, blue: 0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.65), lineWidth: 1.2)
                    Rectangle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                        .padding(22)
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                        .frame(width: 130, height: 130)
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 1.2)
                }
            )
    }

    private var linesOverlay: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            Path { path in
                path.move(to: CGPoint(x: 0, y: height * 0.25))
                path.addLine(to: CGPoint(x: width, y: height * 0.25))
                path.move(to: CGPoint(x: 0, y: height * 0.5))
                path.addLine(to: CGPoint(x: width, y: height * 0.5))
                path.move(to: CGPoint(x: 0, y: height * 0.75))
                path.addLine(to: CGPoint(x: width, y: height * 0.75))
                path.move(to: CGPoint(x: width * 0.25, y: 0))
                path.addLine(to: CGPoint(x: width * 0.25, y: height))
                path.move(to: CGPoint(x: width * 0.5, y: 0))
                path.addLine(to: CGPoint(x: width * 0.5, y: height))
                path.move(to: CGPoint(x: width * 0.75, y: 0))
                path.addLine(to: CGPoint(x: width * 0.75, y: height))
            }
            .stroke(AppTheme.primary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        }
    }

    private var zonesOverlay: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                zoneRect(x: width * 0.08, y: height * 0.24, width: width * 0.24, height: height * 0.52)
                zoneRect(x: width * 0.34, y: height * 0.24, width: width * 0.32, height: height * 0.52)
                zoneRect(x: width * 0.68, y: height * 0.24, width: width * 0.24, height: height * 0.52)
            }
        }
    }

    private func zoneRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(AppTheme.primary.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.primary.opacity(0.16), lineWidth: 1)
            )
            .frame(width: width, height: height)
            .position(x: x + width / 2, y: y + height / 2)
    }
}

private struct FieldDropDelegate: DropDelegate {
    let size: CGSize
    @Binding var isTargeted: Bool
    let onDropPlayer: (UUID, TacticalPoint) -> Void

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
        let dropPoint = TacticalPoint.from(info.location, in: size)
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            guard let idString = decodeItem(item),
                  let id = UUID(uuidString: idString) else { return }
            DispatchQueue.main.async {
                onDropPlayer(id, dropPoint)
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

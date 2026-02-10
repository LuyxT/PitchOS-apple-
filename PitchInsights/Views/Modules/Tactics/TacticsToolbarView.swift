import SwiftUI

struct TacticsToolbarView: View {
    let scenarioName: String
    let showOpponent: Bool
    let opponentMode: OpponentMode
    let isDrawingMode: Bool
    let drawingTool: TacticalDrawingKind
    let drawingIsTemporary: Bool
    let showLines: Bool
    let showZones: Bool
    let drawingsVisible: Bool
    let playerTokenScale: Double
    let onNewScenario: () -> Void
    let onDuplicateScenario: () -> Void
    let onRenameScenario: () -> Void
    let onToggleOpponent: () -> Void
    let onSetOpponentMode: (OpponentMode) -> Void
    let onToggleDrawingMode: () -> Void
    let onSetDrawingTool: (TacticalDrawingKind) -> Void
    let onSetDrawingTemporary: (Bool) -> Void
    let onToggleLines: () -> Void
    let onToggleZones: () -> Void
    let onToggleDrawingsVisible: () -> Void
    let onAddNeutralMarker: () -> Void
    let onDecreasePlayerTokenSize: () -> Void
    let onIncreasePlayerTokenSize: () -> Void
    let onResetScenario: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    titleLabel

                    Spacer(minLength: 8)

                    actionButtons
                }

                VStack(alignment: .leading, spacing: 8) {
                    titleLabel
                    ScrollView(.horizontal, showsIndicators: false) {
                        actionButtons
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(showOpponent ? "Gegner ausblenden" : "Gegner anzeigen") {
                        onToggleOpponent()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Menu("Gegner: \(opponentMode.title)") {
                        Button("Aus") { onSetOpponentMode(.hidden) }
                        Button("Marker") { onSetOpponentMode(.markers) }
                        Button("Formation") { onSetOpponentMode(.formation) }
                    }
                    .menuStyle(.borderlessButton)
                    .foregroundStyle(AppTheme.textPrimary)

                    Button(isDrawingMode ? "Platzieren" : "Zeichnen") {
                        onToggleDrawingMode()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button("Neutraler Kreis") {
                        onAddNeutralMarker()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Menu("Werkzeug: \(drawingTool.title)") {
                        ForEach(TacticalDrawingKind.allCases) { tool in
                            Button(tool.title) {
                                onSetDrawingTool(tool)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .foregroundStyle(AppTheme.textPrimary)

                    toolbarToggle("Temporär", isOn: Binding(
                        get: { drawingIsTemporary },
                        set: { onSetDrawingTemporary($0) }
                    ))

                    toolbarToggle("Linien", isOn: Binding(
                        get: { showLines },
                        set: { _ in onToggleLines() }
                    ))

                    toolbarToggle("Zonen", isOn: Binding(
                        get: { showZones },
                        set: { _ in onToggleZones() }
                    ))

                    toolbarToggle("Zeichnungen zeigen", isOn: Binding(
                        get: { drawingsVisible },
                        set: { _ in onToggleDrawingsVisible() }
                    ))

                    HStack(spacing: 6) {
                        Text("Spielergröße")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Button("−") {
                            onDecreasePlayerTokenSize()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        Text("\(Int((playerTokenScale * 100).rounded()))%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(minWidth: 40)
                        Button("+") {
                            onIncreasePlayerTokenSize()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .foregroundStyle(AppTheme.textPrimary)
        .tint(AppTheme.primaryDark)
        .background(AppTheme.surface)
    }

    private var titleLabel: some View {
        Text(scenarioName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button("Neu", action: onNewScenario)
                .buttonStyle(SecondaryActionButtonStyle())
            Button("Duplizieren", action: onDuplicateScenario)
                .buttonStyle(SecondaryActionButtonStyle())
            Button("Umbenennen", action: onRenameScenario)
                .buttonStyle(SecondaryActionButtonStyle())
            Button("Zurücksetzen", action: onResetScenario)
                .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private func toolbarToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .foregroundStyle(AppTheme.textPrimary)
        }
        #if os(macOS)
        .toggleStyle(.checkbox)
        #else
        .toggleStyle(.switch)
        #endif
        .font(.system(size: 12, weight: .medium))
    }
}

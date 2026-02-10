import SwiftUI

struct AnalysisToolbarView: View {
    let sessions: [AnalysisSession]
    @Binding var selectedSessionID: UUID?
    @Binding var isDrawingMode: Bool
    @Binding var drawingTool: AnalysisDrawingTool
    @Binding var isTemporaryDrawing: Bool
    @Binding var areDrawingsVisible: Bool
    @Binding var isCompareMode: Bool
    @Binding var isPresentationMode: Bool
    let onImportVideo: () -> Void
    let onAddMarker: () -> Void
    let onToggleClip: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                expandedToolbar
                compactToolbar
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
        .foregroundStyle(Color.black)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private var expandedToolbar: some View {
        HStack(spacing: 10) {
            analysisPicker
                .frame(width: 230)

            actionButtons

            Spacer(minLength: 8)

            drawingControls
            compareButtons
        }
    }

    private var compactToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                analysisPicker
                    .frame(maxWidth: .infinity)
                actionButtons
                Menu("Mehr") {
                    drawingControlsMenu
                    Divider()
                    compareButtonsMenu
                }
                .menuStyle(.borderlessButton)
                .fixedSize(horizontal: true, vertical: false)
            }

            if isDrawingMode {
                HStack(spacing: 8) {
                    Picker("Werkzeug", selection: $drawingTool) {
                        ForEach(AnalysisDrawingTool.allCases) { tool in
                            Text(tool.title).tag(tool)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)

                    Toggle("Temporär", isOn: $isTemporaryDrawing)
                        .toggleStyle(.switch)
                        .fixedSize(horizontal: true, vertical: false)

                    Toggle("Layer", isOn: $areDrawingsVisible)
                        .toggleStyle(.switch)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }

    private var analysisPicker: some View {
        Picker("Analyse", selection: $selectedSessionID) {
            ForEach(sessions) { session in
                Text(session.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .tag(Optional(session.id))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                Haptics.trigger(.soft)
                onImportVideo()
            } label: {
                Label("Video", systemImage: "plus")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .help("Video importieren")

            Button {
                Haptics.trigger(.light)
                onAddMarker()
            } label: {
                Label("Marker", systemImage: "bookmark")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .help("Marker setzen")

            Button {
                Haptics.trigger(.soft)
                onToggleClip()
            } label: {
                Label("Clip", systemImage: "scissors")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .help("Clip Start/Ende")
        }
    }

    private var drawingControls: some View {
        HStack(spacing: 8) {
            Toggle("Zeichnen", isOn: $isDrawingMode)
                .toggleStyle(.switch)
                .fixedSize(horizontal: true, vertical: false)

            if isDrawingMode {
                Picker("Werkzeug", selection: $drawingTool) {
                    ForEach(AnalysisDrawingTool.allCases) { tool in
                        Text(tool.title).tag(tool)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 110)

                Toggle("Temporär", isOn: $isTemporaryDrawing)
                    .toggleStyle(.switch)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Toggle("Layer", isOn: $areDrawingsVisible)
                .toggleStyle(.switch)
                .fixedSize(horizontal: true, vertical: false)
                .help("Zeichnungen ein-/ausblenden")
        }
    }

    private var compareButtons: some View {
        HStack(spacing: 8) {
            Button("Vergleich") {
                Haptics.trigger(.light)
                withAnimation(AppMotion.settle) {
                    isCompareMode.toggle()
                    if isCompareMode {
                        isPresentationMode = false
                    }
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button("Präsentation") {
                Haptics.trigger(.light)
                withAnimation(AppMotion.settle) {
                    isPresentationMode.toggle()
                    if isPresentationMode {
                        isCompareMode = false
                    }
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    @ViewBuilder
    private var drawingControlsMenu: some View {
        Toggle(isOn: $isDrawingMode) {
            Text("Zeichnen")
        }

        if isDrawingMode {
            Picker("Werkzeug", selection: $drawingTool) {
                ForEach(AnalysisDrawingTool.allCases) { tool in
                    Text(tool.title).tag(tool)
                }
            }
            Toggle(isOn: $isTemporaryDrawing) {
                Text("Temporär")
            }
        }

        Toggle(isOn: $areDrawingsVisible) {
            Text("Layer anzeigen")
        }
    }

    @ViewBuilder
    private var compareButtonsMenu: some View {
        Button(isCompareMode ? "Vergleich aus" : "Vergleich an") {
            Haptics.trigger(.light)
            withAnimation(AppMotion.settle) {
                isCompareMode.toggle()
                if isCompareMode {
                    isPresentationMode = false
                }
            }
        }
        Button(isPresentationMode ? "Präsentation aus" : "Präsentation an") {
            Haptics.trigger(.light)
            withAnimation(AppMotion.settle) {
                isPresentationMode.toggle()
                if isPresentationMode {
                    isCompareMode = false
                }
            }
        }
    }
}

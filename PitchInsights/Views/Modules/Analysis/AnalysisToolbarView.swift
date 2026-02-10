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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Picker("Analyse", selection: $selectedSessionID) {
                    ForEach(sessions) { session in
                        Text(session.title).tag(Optional(session.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 220)

                Button {
                    onImportVideo()
                } label: {
                    Label("Video", systemImage: "plus")
                        .lineLimit(1)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .help("Video importieren")

                Button {
                    onAddMarker()
                } label: {
                    Label("Marker", systemImage: "bookmark")
                        .lineLimit(1)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .help("Marker setzen")

                Button {
                    onToggleClip()
                } label: {
                    Label("Clip", systemImage: "scissors")
                        .lineLimit(1)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .help("Clip Start/Ende")

                Toggle("Zeichnen", isOn: $isDrawingMode)
                    .toggleStyle(.switch)
                    .fixedSize()

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
                        .fixedSize()
                }

                Toggle("Layer", isOn: $areDrawingsVisible)
                    .toggleStyle(.switch)
                    .fixedSize()
                    .help("Zeichnungen ein-/ausblenden")

                Button("Vergleich") {
                    isCompareMode.toggle()
                    if isCompareMode {
                        isPresentationMode = false
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button("Präsentation") {
                    isPresentationMode.toggle()
                    if isPresentationMode {
                        isCompareMode = false
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(AppTheme.surface)
        .foregroundStyle(Color.black)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
        .frame(height: 56)
    }
}

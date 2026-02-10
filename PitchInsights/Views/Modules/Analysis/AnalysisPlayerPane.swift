import SwiftUI
import AVKit

struct AnalysisPlayerPane: View {
    @ObservedObject var playerViewModel: AnalysisPlayerViewModel
    @ObservedObject var drawingViewModel: AnalysisDrawingViewModel
    let drawings: [AnalysisDrawing]
    let sessionID: UUID?
    let onDrawingsChange: ([AnalysisDrawing]) -> Void

    @State private var workingDrawings: [AnalysisDrawing] = []
    private let playbackRates: [Float] = [0.5, 1.0, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                VideoPlayer(player: playerViewModel.player)
                    .background(Color.black)

                AnalysisDrawingOverlay(
                    drawings: workingDrawings,
                    draftPoints: drawingViewModel.draftPoints,
                    draftTool: drawingViewModel.selectedTool,
                    isDrawingEnabled: drawingViewModel.isDrawingMode,
                    areDrawingsVisible: drawingViewModel.areDrawingsVisible,
                    onBegin: { point, size in
                        drawingViewModel.begin(at: point, in: size)
                    },
                    onChange: { point, size in
                        drawingViewModel.update(at: point, in: size)
                    },
                    onEnd: { point, size in
                        drawingViewModel.update(at: point, in: size)
                        guard let sessionID else { return }
                        guard let drawing = drawingViewModel.finish(
                            sessionID: sessionID,
                            timeSeconds: playerViewModel.currentTime
                        ) else {
                            return
                        }
                        workingDrawings.append(drawing)
                        onDrawingsChange(workingDrawings)
                    }
                )
            }

            controls
        }
        .onAppear {
            workingDrawings = drawings
        }
        .onChange(of: drawings) { _, newValue in
            workingDrawings = newValue
        }
        .background(AppTheme.surface)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(action: playerViewModel.togglePlayPause) {
                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button(action: playerViewModel.frameStepBackward) {
                Image(systemName: "backward.frame")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button(action: playerViewModel.frameStepForward) {
                Image(systemName: "forward.frame")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Menu {
                ForEach(playbackRates, id: \.self) { rate in
                    Button {
                        playerViewModel.setRate(rate)
                    } label: {
                        if rate == playerViewModel.playbackRate {
                            Label(rateText(rate), systemImage: "checkmark")
                        } else {
                            Text(rateText(rate))
                        }
                    }
                }
            } label: {
                Text("Tempo \(rateText(playerViewModel.playbackRate))")
                    .lineLimit(1)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Spacer()

            Text("\(format(playerViewModel.currentTime)) / \(format(playerViewModel.duration))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .foregroundStyle(Color.black)
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = Int(seconds.rounded(.down))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func rateText(_ rate: Float) -> String {
        if rate == floor(rate) {
            return String(format: "%.0fx", rate)
        }
        return String(format: "%.1fx", rate)
    }
}

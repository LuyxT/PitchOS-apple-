import SwiftUI
import AVKit

struct AnalysisPresentationView: View {
    @ObservedObject var playerViewModel: AnalysisPlayerViewModel
    let markers: [AnalysisMarker]
    let drawings: [AnalysisDrawing]

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                VideoPlayer(player: playerViewModel.player)
                    .background(Color.black)

                AnalysisDrawingOverlay(
                    drawings: drawings,
                    draftPoints: [],
                    draftTool: .line,
                    isDrawingEnabled: false,
                    areDrawingsVisible: true,
                    onBegin: { _, _ in },
                    onChange: { _, _ in },
                    onEnd: { _, _ in }
                )
                .allowsHitTesting(false)
            }

            AnalysisTimelineView(
                playerViewModel: playerViewModel,
                markers: markers,
                onMarkerTap: { marker in
                    playerViewModel.seek(to: marker.timeSeconds)
                }
            )

            HStack(spacing: 10) {
                Button(action: playerViewModel.togglePlayPause) {
                    Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Text("\(format(playerViewModel.currentTime))")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .padding(10)
        .background(AppTheme.background)
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

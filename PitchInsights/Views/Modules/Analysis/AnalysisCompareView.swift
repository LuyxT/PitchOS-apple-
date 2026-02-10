import SwiftUI

struct AnalysisCompareView: View {
    let playbackURL: URL
    let leftClip: AnalysisClip
    let rightClip: AnalysisClip

    @StateObject private var leftPlayer = AnalysisPlayerViewModel()
    @StateObject private var rightPlayer = AnalysisPlayerViewModel()
    @State private var sharedRate: Float = 1.0
    private let playbackRates: [Float] = [0.5, 1.0, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                comparePane(title: leftClip.name, player: leftPlayer)
                comparePane(title: rightClip.name, player: rightPlayer)
            }

            HStack(spacing: 10) {
                Button("Play/Pause") {
                    if leftPlayer.isPlaying || rightPlayer.isPlaying {
                        leftPlayer.pause()
                        rightPlayer.pause()
                    } else {
                        leftPlayer.play()
                        rightPlayer.play()
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button("Sync Start") {
                    leftPlayer.seek(to: leftClip.startSeconds)
                    rightPlayer.seek(to: rightClip.startSeconds)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Menu {
                    ForEach(playbackRates, id: \.self) { rate in
                        Button {
                            sharedRate = rate
                            leftPlayer.setRate(rate)
                            rightPlayer.setRate(rate)
                        } label: {
                            if rate == sharedRate {
                                Label(rateText(rate), systemImage: "checkmark")
                            } else {
                                Text(rateText(rate))
                            }
                        }
                    }
                } label: {
                    Text("Tempo \(rateText(sharedRate))")
                        .lineLimit(1)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Spacer()
            }
            .foregroundStyle(Color.black)
        }
        .padding(12)
        .background(AppTheme.background)
        .onAppear {
            loadClips()
        }
        .onChange(of: leftClip.id) { _, _ in
            loadClips()
        }
        .onChange(of: rightClip.id) { _, _ in
            loadClips()
        }
    }

    private func comparePane(title: String, player: AnalysisPlayerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            AnalysisPlayerPane(
                playerViewModel: player,
                drawingViewModel: AnalysisDrawingViewModel(),
                drawings: [],
                sessionID: nil,
                onDrawingsChange: { _ in }
            )
            .frame(minHeight: 260)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadClips() {
        leftPlayer.load(
            url: playbackURL,
            initialTime: leftClip.startSeconds,
            clipRange: leftClip.startSeconds...leftClip.endSeconds
        )
        rightPlayer.load(
            url: playbackURL,
            initialTime: rightClip.startSeconds,
            clipRange: rightClip.startSeconds...rightClip.endSeconds
        )
        leftPlayer.setRate(sharedRate)
        rightPlayer.setRate(sharedRate)
    }

    private func rateText(_ rate: Float) -> String {
        if rate == floor(rate) {
            return String(format: "%.0fx", rate)
        }
        return String(format: "%.1fx", rate)
    }
}

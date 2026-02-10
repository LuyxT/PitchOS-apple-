import SwiftUI

struct AnalysisTimelineView: View {
    @ObservedObject var playerViewModel: AnalysisPlayerViewModel
    let markers: [AnalysisMarker]
    let onMarkerTap: (AnalysisMarker) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: playerViewModel.zoomOutTimeline) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button(action: playerViewModel.zoomInTimeline) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Slider(
                    value: Binding(
                        get: { playerViewModel.currentTime },
                        set: { playerViewModel.seek(to: $0) }
                    ),
                    in: 0...max(0.1, playerViewModel.duration)
                )

                Text("Zoom \(Int(playerViewModel.timelineZoom * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            GeometryReader { proxy in
                let baseWidth = max(1, proxy.size.width)
                let width = timelineWidth(for: baseWidth)
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AppTheme.surfaceAlt)
                            .frame(width: width, height: 16)

                        tickLayer(width: width, baseWidth: baseWidth)

                        ForEach(markers) { marker in
                            let x = markerOffsetX(marker.timeSeconds, width: width, baseWidth: baseWidth)
                            Circle()
                                .fill(markerColor(for: marker))
                                .frame(width: 10, height: 10)
                                .offset(x: x - 5, y: 3)
                                .onTapGesture {
                                    Haptics.trigger(.light)
                                    onMarkerTap(marker)
                                }
                                .help("\(format(marker.timeSeconds))")
                        }

                        Capsule()
                            .fill(AppTheme.primary)
                            .frame(width: 2, height: 18)
                            .offset(x: markerOffsetX(playerViewModel.currentTime, width: width, baseWidth: baseWidth))
                    }
                    .frame(width: width, height: 20)
                }
            }
            .frame(height: 20)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
    }

    private func timelineWidth(for base: CGFloat) -> CGFloat {
        let scaled = base * playerViewModel.timelineZoom
        return max(base, scaled)
    }

    private func markerOffsetX(_ seconds: Double, width: CGFloat, baseWidth: CGFloat) -> CGFloat {
        let duration = max(playerViewModel.duration, 1)
        let pixelsPerSecond = (baseWidth / CGFloat(duration)) * playerViewModel.timelineZoom
        let maxOffset = max(0, width - 2)
        let raw = CGFloat(max(0, min(seconds, duration))) * pixelsPerSecond
        return min(maxOffset, raw)
    }

    private func markerColor(for marker: AnalysisMarker) -> Color {
        if marker.syncState == .syncFailed {
            return .red
        }
        return AppTheme.primary
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    @ViewBuilder
    private func tickLayer(width: CGFloat, baseWidth: CGFloat) -> some View {
        let duration = Int(max(0, playerViewModel.duration).rounded(.up))
        if duration > 0 {
            let step = tickStep(for: playerViewModel.timelineZoom)

            ForEach(Array(stride(from: 0, through: duration, by: step)), id: \.self) { second in
                let x = markerOffsetX(Double(second), width: width, baseWidth: baseWidth)
                Rectangle()
                    .fill(AppTheme.border.opacity(0.9))
                    .frame(width: 1, height: second % (step * 2) == 0 ? 14 : 9)
                    .offset(x: x, y: 1)
            }
        }
    }

    private func tickStep(for zoom: CGFloat) -> Int {
        switch zoom {
        case 0..<2:
            return 20
        case 2..<4:
            return 10
        case 4..<8:
            return 5
        default:
            return 2
        }
    }
}

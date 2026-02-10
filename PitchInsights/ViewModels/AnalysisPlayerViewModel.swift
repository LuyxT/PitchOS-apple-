import Foundation
import AVFoundation
import Combine

final class AnalysisPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer = AVPlayer()
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackRate: Float = 1.0
    @Published var timelineZoom: CGFloat = 1.0

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var clipRange: ClosedRange<Double>?

    deinit {
        cleanupObservers()
    }

    func load(url: URL, initialTime: Double = 0, clipRange: ClosedRange<Double>? = nil) {
        cleanupObservers()

        self.clipRange = clipRange
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        currentTime = initialTime
        duration = 0

        addObservers(to: item)

        let target = CMTime(seconds: initialTime, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        if let range = clipRange, currentTime < range.lowerBound || currentTime > range.upperBound {
            seek(to: range.lowerBound)
        }
        player.playImmediately(atRate: playbackRate)
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player.playImmediately(atRate: rate)
        }
    }

    func seek(to seconds: Double) {
        let constrained: Double
        if let range = clipRange {
            constrained = min(range.upperBound, max(range.lowerBound, seconds))
        } else {
            constrained = min(max(0, seconds), duration > 0 ? duration : seconds)
        }

        let time = CMTime(seconds: constrained, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = constrained
    }

    func frameStepForward() {
        seek(to: currentTime + frameDuration)
    }

    func frameStepBackward() {
        seek(to: currentTime - frameDuration)
    }

    func zoomInTimeline() {
        timelineZoom = min(12.0, timelineZoom + 0.5)
    }

    func zoomOutTimeline() {
        timelineZoom = max(1.0, timelineZoom - 0.5)
    }

    private var frameDuration: Double {
        if let track = player.currentItem?.asset.tracks(withMediaType: .video).first {
            let fps = track.nominalFrameRate
            if fps > 1 {
                return 1.0 / Double(fps)
            }
        }
        return 1.0 / 30.0
    }

    private func addObservers(to item: AVPlayerItem) {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }

            self.currentTime = seconds
            if let range = self.clipRange, seconds >= range.upperBound {
                self.pause()
                self.seek(to: range.upperBound)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.pause()
            if let range = self.clipRange {
                self.seek(to: range.lowerBound)
            } else {
                self.seek(to: 0)
            }
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let totalDuration = try await item.asset.load(.duration)
                let seconds = CMTimeGetSeconds(totalDuration)
                if seconds.isFinite {
                    self.duration = max(0, seconds)
                }
            } catch {
                self.duration = 0
            }
        }
    }

    private func cleanupObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}

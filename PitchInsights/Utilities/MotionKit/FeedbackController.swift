import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import AudioToolbox
#endif

@MainActor
final class FeedbackController {
    func perform(for payload: MotionPayload, settings: MotionSettings, reduceMotionEnabled: Bool) {
        if settings.soundsEnabled {
            playSound(payload.sound, severity: payload.severity)
        }

        guard settings.hapticsEnabled else { return }
        if settings.reduceMotionRespect && reduceMotionEnabled {
            // Keep haptics lightweight in reduced-motion mode.
            Haptics.trigger(.light)
            return
        }

        if let style = payload.haptic {
            Haptics.trigger(style)
            return
        }

        switch payload.severity {
        case .success:
            Haptics.trigger(.success)
        case .warning:
            Haptics.trigger(.soft)
        case .error:
            Haptics.trigger(.soft)
        case .info:
            Haptics.trigger(.light)
        }
    }

    private func playSound(_ sound: MotionSound?, severity: MotionSeverity) {
        #if os(macOS)
        switch sound ?? defaultSound(for: severity) {
        case .tick:
            NSSound(named: NSSound.Name("Morse"))?.play()
        case .success:
            NSSound(named: NSSound.Name("Glass"))?.play()
        case .warning:
            NSSound(named: NSSound.Name("Pop"))?.play()
        case .error:
            NSSound(named: NSSound.Name("Basso"))?.play()
        case .pop:
            NSSound(named: NSSound.Name("Pop"))?.play()
        }
        #elseif os(iOS)
        switch sound ?? defaultSound(for: severity) {
        case .tick:
            AudioServicesPlaySystemSound(1104)
        case .success:
            AudioServicesPlaySystemSound(1113)
        case .warning:
            AudioServicesPlaySystemSound(1107)
        case .error:
            AudioServicesPlaySystemSound(1053)
        case .pop:
            AudioServicesPlaySystemSound(1157)
        }
        #endif
    }

    private func defaultSound(for severity: MotionSeverity) -> MotionSound {
        switch severity {
        case .success:
            return .success
        case .warning:
            return .warning
        case .error:
            return .error
        case .info:
            return .tick
        }
    }
}

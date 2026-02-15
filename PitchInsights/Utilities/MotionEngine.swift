import SwiftUI
import Combine

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct MotionToastItem: Identifiable {
    let id = UUID()
    let event: MotionEvent
    let payload: MotionPayload
    let createdAt: Date = Date()
}

struct MotionBannerItem: Identifiable {
    let id = UUID()
    let payload: MotionPayload
    let isPersistent: Bool
}

struct MotionProgressState: Identifiable {
    let id = UUID()
    let payload: MotionPayload
    let startedAt: Date = Date()

    var isIndeterminate: Bool {
        payload.progress == nil
    }
}

@MainActor
final class MotionEngine: ObservableObject {
    static let shared = MotionEngine()

    @Published var sceneID: Int = 0
    @Published var pulseID: Int = 0
    @Published var successID: Int = 0
    @Published var errorID: Int = 0
    @Published var rippleID: Int = 0

    @Published private(set) var topBanner: MotionBannerItem?
    @Published private(set) var toasts: [MotionToastItem] = []
    @Published private(set) var progressState: MotionProgressState?
    @Published private(set) var highlightedContext: MotionContext?
    @Published private(set) var settings: MotionSettings

    private let feedbackController = FeedbackController()
    private var toastDismissTasks: [UUID: Task<Void, Never>] = [:]
    private var bannerDismissTask: Task<Void, Never>?
    private var progressTimeoutTask: Task<Void, Never>?
    private var highlightResetTask: Task<Void, Never>?
    private var dedupeMap: [String: Date] = [:]

    private let toastVisibleLimit = 3
    private let dedupeWindow: TimeInterval = 0.12

    init(settings: MotionSettings? = nil) {
        self.settings = settings ?? MotionSettings.load()
    }

    func updateSettings(_ transform: (inout MotionSettings) -> Void) {
        var copy = settings
        transform(&copy)
        settings = copy
        settings.persist()
    }

    func emit(_ event: MotionEvent, payload: MotionPayload) {
        guard shouldEmit(event: event, payload: payload) else { return }

        feedbackController.perform(
            for: payload,
            settings: settings,
            reduceMotionEnabled: systemReduceMotionEnabled
        )

        switch event {
        case .create, .update, .delete, .success:
            enqueueToast(event: event, payload: payload)
            highlight(contextId: payload.contextId, scope: payload.scope)
            if event == .success {
                triggerSuccess()
            } else {
                triggerPulse()
            }

        case .error:
            enqueueToast(event: event, payload: payload)
            showTopBanner(payload: payload, persistent: payload.severity == .error)
            triggerError()

        case .progress:
            showProgress(payload: payload)
            if let progress = payload.progress, progress >= 1 {
                dismissProgress(after: 0.7)
            }

        case .navigation:
            advanceScene()
            triggerRipple()

        case .sync:
            showTopBanner(payload: payload, persistent: false)

        case .offline:
            showTopBanner(payload: payload, persistent: true)

        case .online:
            showTopBanner(payload: payload, persistent: false)
        }
    }

    func emitNetworkError(
        _ error: Error,
        scope: MotionScope,
        title: String = "Aktion fehlgeschlagen",
        contextId: String? = nil,
        retryAction: (() -> Void)? = nil
    ) {
        let message = NetworkError.userMessage(from: error)

        if NetworkError.isConnectivity(error) {
            emit(
                .offline,
                payload: MotionPayload(
                    title: "Offline",
                    subtitle: message,
                    iconName: "wifi.exclamationmark",
                    severity: .warning,
                    contextId: contextId,
                    sound: .warning,
                    haptic: .soft,
                    scope: scope,
                    ctaTitle: retryAction == nil ? nil : "Erneut versuchen",
                    ctaAction: retryAction
                )
            )
            return
        }

        if let network = error as? NetworkError, network.isUnauthorized {
            emit(
                .error,
                payload: MotionPayload(
                    title: "Bitte erneut anmelden",
                    subtitle: message,
                    iconName: "person.crop.circle.badge.exclamationmark",
                    severity: .error,
                    contextId: contextId,
                    sound: .error,
                    haptic: .soft,
                    scope: scope
                )
            )
            return
        }

        emit(
            .error,
            payload: MotionPayload(
                title: title,
                subtitle: message,
                iconName: "exclamationmark.triangle.fill",
                severity: .error,
                contextId: contextId,
                sound: .error,
                haptic: .soft,
                scope: scope
            )
        )
    }

    func setProgress(
        title: String,
        subtitle: String? = nil,
        progress: Double? = nil,
        scope: MotionScope = .global,
        contextId: String? = nil
    ) {
        emit(
            .progress,
            payload: MotionPayload(
                title: title,
                subtitle: subtitle,
                iconName: "arrow.triangle.2.circlepath",
                severity: .info,
                contextId: contextId,
                progress: progress,
                sound: progress == nil ? .tick : nil,
                haptic: .light,
                scope: scope
            )
        )
    }

    func clearProgress() {
        dismissProgress(after: 0)
    }

    func setOnline() {
        emit(
            .online,
            payload: MotionPayload(
                title: "Wieder online",
                subtitle: "Verbindung zum Backend wiederhergestellt.",
                iconName: "wifi",
                severity: .success,
                sound: .success,
                haptic: .success,
                scope: .global
            )
        )
    }

    func setOffline(retryAction: (() -> Void)? = nil) {
        emit(
            .offline,
            payload: MotionPayload(
                title: "Offline",
                subtitle: "Keine Verbindung zum Backend.",
                iconName: "wifi.slash",
                severity: .warning,
                sound: .warning,
                haptic: .soft,
                scope: .global,
                ctaTitle: retryAction == nil ? nil : "Erneut versuchen",
                ctaAction: retryAction
            )
        )
    }

    func highlight(contextId: String?, scope: MotionScope) {
        guard let contextId, !contextId.isEmpty else { return }
        highlightedContext = MotionContext(scope: scope, contextId: contextId)
        pulseID += 1
        highlightResetTask?.cancel()
        highlightResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.highlightedContext = nil
            }
        }
    }

    func advanceScene() {
        sceneID += 1
    }

    func triggerPulse() {
        pulseID += 1
    }

    func triggerSuccess() {
        successID += 1
    }

    func triggerError() {
        errorID += 1
    }

    func triggerRipple() {
        rippleID += 1
    }

    func feedback(_ style: HapticStyle) {
        guard settings.hapticsEnabled else { return }
        Haptics.trigger(style)
        #if os(macOS)
        if settings.soundsEnabled {
            NSSound(named: NSSound.Name("Glass"))?.play()
        }
        #endif
    }

    func transition(_ style: MotionTransitionStyle) -> AnyTransition {
        let useReduced = settings.reduceMotionRespect && systemReduceMotionEnabled
        if useReduced {
            return .opacity
        }

        switch style {
        case .cameraPush:
            return .asymmetric(
                insertion: .scale(scale: 1.02).combined(with: .opacity),
                removal: .scale(scale: 0.98).combined(with: .opacity)
            )
        case .cameraPull:
            return .asymmetric(
                insertion: .scale(scale: 0.98).combined(with: .opacity),
                removal: .scale(scale: 1.02).combined(with: .opacity)
            )
        case .sceneReveal:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .transitionZoom:
            return .asymmetric(
                insertion: .scale(scale: 1.04).combined(with: .opacity),
                removal: .scale(scale: 0.96).combined(with: .opacity)
            )
        }
    }

    var motionAnimation: Animation {
        if settings.reduceMotionRespect && systemReduceMotionEnabled {
            return .easeInOut(duration: 0.16)
        }
        return .spring(
            response: settings.intensity.springResponse,
            dampingFraction: settings.intensity.damping,
            blendDuration: 0.05
        )
    }

    private func enqueueToast(event: MotionEvent, payload: MotionPayload) {
        let item = MotionToastItem(event: event, payload: payload)
        toasts.append(item)

        if toasts.count > toastVisibleLimit {
            let overflow = toasts.count - toastVisibleLimit
            let removed = toasts.prefix(overflow)
            toasts.removeFirst(overflow)
            for item in removed {
                toastDismissTasks[item.id]?.cancel()
                toastDismissTasks[item.id] = nil
            }
        }

        toastDismissTasks[item.id]?.cancel()
        toastDismissTasks[item.id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.dismissToast(id: item.id)
            }
        }
    }

    func dismissToast(id: UUID) {
        toasts.removeAll { $0.id == id }
        toastDismissTasks[id]?.cancel()
        toastDismissTasks[id] = nil
    }

    private func showTopBanner(payload: MotionPayload, persistent: Bool) {
        topBanner = MotionBannerItem(payload: payload, isPersistent: persistent)
        bannerDismissTask?.cancel()
        guard !persistent else { return }

        bannerDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.topBanner = nil
            }
        }
    }

    func dismissTopBanner() {
        bannerDismissTask?.cancel()
        topBanner = nil
    }

    private func showProgress(payload: MotionPayload) {
        progressState = MotionProgressState(payload: payload)
        progressTimeoutTask?.cancel()

        progressTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if self.progressState != nil {
                    self.emit(
                        .error,
                        payload: MotionPayload(
                            title: "Aktion dauert ungewöhnlich lange",
                            subtitle: "Du kannst weiterarbeiten. Der Vorgang läuft im Hintergrund.",
                            iconName: "clock.badge.exclamationmark",
                            severity: .warning,
                            scope: payload.scope
                        )
                    )
                    self.progressState = nil
                }
            }
        }
    }

    private func dismissProgress(after delay: TimeInterval) {
        progressTimeoutTask?.cancel()
        progressTimeoutTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.progressState = nil
            }
        }
    }

    private func shouldEmit(event: MotionEvent, payload: MotionPayload) -> Bool {
        let key = "\(event.rawValue)|\(payload.scope.rawValue)|\(payload.title)|\(payload.contextId ?? "")"
        let now = Date()

        // Clean old dedupe entries.
        dedupeMap = dedupeMap.filter { now.timeIntervalSince($0.value) < 4 }

        if let last = dedupeMap[key], now.timeIntervalSince(last) < dedupeWindow {
            return false
        }

        dedupeMap[key] = now
        return true
    }

    private var systemReduceMotionEnabled: Bool {
        #if os(iOS)
        UIAccessibility.isReduceMotionEnabled
        #elseif os(macOS)
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        false
        #endif
    }
}

enum MotionTransitionStyle {
    case cameraPush
    case cameraPull
    case sceneReveal
    case transitionZoom
}

struct MotionGlowModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isActive ? 0.4 : 0), radius: isActive ? 14 : 0, x: 0, y: 0)
            .animation(animation, value: isActive)
    }
}

extension View {
    func motionGlow(_ isActive: Bool, color: Color, animation: Animation) -> some View {
        modifier(MotionGlowModifier(isActive: isActive, color: color, animation: animation))
    }

    func errorShake(_ trigger: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(trigger)))
            .animation(AppMotion.errorShake, value: trigger)
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

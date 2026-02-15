import Foundation

@MainActor
extension AppDataStore {
    func motionCreate(
        _ title: String,
        subtitle: String? = nil,
        scope: MotionScope,
        contextId: String? = nil,
        icon: String = "plus.circle.fill"
    ) {
        MotionEngine.shared.emit(
            .create,
            payload: MotionPayload(
                title: title,
                subtitle: subtitle,
                iconName: icon,
                severity: .success,
                contextId: contextId,
                sound: .pop,
                haptic: .success,
                scope: scope
            )
        )
    }

    func motionUpdate(
        _ title: String,
        subtitle: String? = nil,
        scope: MotionScope,
        contextId: String? = nil,
        icon: String = "checkmark.circle.fill"
    ) {
        MotionEngine.shared.emit(
            .update,
            payload: MotionPayload(
                title: title,
                subtitle: subtitle,
                iconName: icon,
                severity: .success,
                contextId: contextId,
                sound: .tick,
                haptic: .light,
                scope: scope
            )
        )
    }

    func motionDelete(
        _ title: String,
        subtitle: String? = nil,
        scope: MotionScope,
        contextId: String? = nil,
        icon: String = "trash.fill"
    ) {
        MotionEngine.shared.emit(
            .delete,
            payload: MotionPayload(
                title: title,
                subtitle: subtitle,
                iconName: icon,
                severity: .warning,
                contextId: contextId,
                sound: .warning,
                haptic: .soft,
                scope: scope
            )
        )
    }

    func motionProgress(
        _ title: String,
        subtitle: String? = nil,
        progress: Double? = nil,
        scope: MotionScope,
        contextId: String? = nil
    ) {
        MotionEngine.shared.setProgress(
            title: title,
            subtitle: subtitle,
            progress: progress,
            scope: scope,
            contextId: contextId
        )
    }

    func motionClearProgress() {
        MotionEngine.shared.clearProgress()
    }

    func motionError(
        _ error: Error,
        scope: MotionScope,
        title: String,
        contextId: String? = nil,
        retry: (() -> Void)? = nil
    ) {
        MotionEngine.shared.emitNetworkError(
            error,
            scope: scope,
            title: title,
            contextId: contextId,
            retryAction: retry
        )
    }

    func motionOnline() {
        MotionEngine.shared.setOnline()
    }

    func motionOffline(retry: (() -> Void)? = nil) {
        MotionEngine.shared.setOffline(retryAction: retry)
    }
}

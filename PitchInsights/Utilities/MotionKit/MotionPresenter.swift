import SwiftUI

struct MotionPresenter: View {
    @EnvironmentObject private var motion: MotionEngine

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: 0) {
                    if let banner = motion.topBanner {
                        TopBannerView(item: banner) {
                            motion.dismissTopBanner()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                }

                if let progress = motion.progressState {
                    ProgressHUDView(item: progress)
                        .frame(maxWidth: min(proxy.size.width - 32, 420))
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                toastContainer

                SuccessRippleOverlay(trigger: motion.successID)
                    .allowsHitTesting(false)
            }
            .animation(motion.motionAnimation, value: motion.topBanner?.id)
            .animation(motion.motionAnimation, value: motion.toasts.map(\.id))
            .animation(motion.motionAnimation, value: motion.progressState?.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var toastContainer: some View {
        #if os(macOS)
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    ForEach(motion.toasts) { item in
                        ToastView(item: item) {
                            motion.dismissToast(id: item.id)
                        }
                        .allowsHitTesting(true)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 20)
                .padding(.trailing, 20)
            }
        }
        #else
        VStack {
            Spacer()
            VStack(spacing: 10) {
                ForEach(motion.toasts) { item in
                    ToastView(item: item) {
                        motion.dismissToast(id: item.id)
                    }
                    .allowsHitTesting(true)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 28)
            .padding(.horizontal, 14)
        }
        #endif
    }
}

struct MotionOverlayLayer: View {
    var body: some View {
        MotionPresenter()
    }
}

private struct TopBannerView: View {
    let item: MotionBannerItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.payload.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(item.payload.severity.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.payload.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                if let subtitle = item.payload.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let ctaTitle = item.payload.ctaTitle, let ctaAction = item.payload.ctaAction {
                Button(ctaTitle) {
                    ctaAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(item.payload.severity.tint.opacity(0.36))
                .frame(height: 1)
        }
        .accessibilityLabel(item.payload.title)
        .accessibilityValue(item.payload.subtitle ?? "")
        .allowsHitTesting(true)
    }
}

private struct ToastView: View {
    let item: MotionToastItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.payload.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(item.payload.severity.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.payload.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                if let subtitle = item.payload.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let undoAction = item.payload.undoAction {
                Button("Rückgängig") {
                    undoAction()
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 380)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(item.payload.severity.tint.opacity(0.2), lineWidth: 1)
        )
        .accessibilityLabel(item.payload.title)
        .accessibilityValue(item.payload.subtitle ?? "")
    }
}

private struct ProgressHUDView: View {
    let item: MotionProgressState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let progress = item.payload.progress {
                    Text("\(Int(max(0, min(progress, 1)) * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(item.payload.severity.tint)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.payload.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    if let subtitle = item.payload.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }

            if let progress = item.payload.progress {
                ProgressView(value: max(0, min(progress, 1)), total: 1)
                    .tint(item.payload.severity.tint)
            } else {
                ProgressView()
                    .tint(item.payload.severity.tint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border.opacity(0.6), lineWidth: 1)
        )
    }
}

private struct SuccessRippleOverlay: View {
    let trigger: Int
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(AppTheme.primary.opacity(0.25), lineWidth: 2)
            .frame(width: animate ? 140 : 20, height: animate ? 140 : 20)
            .opacity(animate ? 0 : 0.7)
            .onChange(of: trigger) { _, _ in
                animate = false
                withAnimation(.easeOut(duration: 0.6)) {
                    animate = true
                }
            }
    }
}

struct MotionInlineHighlightModifier: ViewModifier {
    @EnvironmentObject private var motion: MotionEngine

    let scope: MotionScope
    let contextId: String

    @State private var isActive = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.primary.opacity(isActive ? 0.75 : 0), lineWidth: 2)
                    .shadow(color: AppTheme.primary.opacity(isActive ? 0.3 : 0), radius: isActive ? 10 : 0)
            )
            .animation(AppMotion.successPulse, value: isActive)
            .onChange(of: motion.highlightedContext) { _, newValue in
                guard let newValue else {
                    isActive = false
                    return
                }
                if newValue.scope == scope, newValue.contextId == contextId {
                    isActive = true
                    Task {
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        await MainActor.run {
                            isActive = false
                        }
                    }
                }
            }
    }
}

extension View {
    func motionInlineHighlight(scope: MotionScope, contextId: String) -> some View {
        modifier(MotionInlineHighlightModifier(scope: scope, contextId: contextId))
    }

    func motionScopePulse(scope: MotionScope) -> some View {
        modifier(MotionScopePulseModifier(scope: scope))
    }
}

private struct MotionScopePulseModifier: ViewModifier {
    @EnvironmentObject private var motion: MotionEngine
    let scope: MotionScope

    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.primary.opacity(pulsing ? 0.25 : 0), lineWidth: 1.5)
                    .shadow(color: AppTheme.primary.opacity(pulsing ? 0.16 : 0), radius: pulsing ? 12 : 0)
            )
            .animation(AppMotion.settleSoft, value: pulsing)
            .onChange(of: motion.highlightedContext) { _, context in
                guard let context, context.scope == scope else { return }
                pulsing = true
                Task {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    await MainActor.run {
                        pulsing = false
                    }
                }
            }
    }
}

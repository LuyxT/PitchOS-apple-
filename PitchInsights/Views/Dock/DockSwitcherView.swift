import SwiftUI

struct DockSwitcherView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            ForEach(appState.dockModules) { module in
                DockItemView(module: module)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.dockBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.dockBorder, lineWidth: 1)
        )
    }

    private struct DockItemView: View {
        @EnvironmentObject private var appState: AppState
        @State private var isHovering = false

        let module: Module

        var body: some View {
            VStack(spacing: 6) {
                Image(systemName: module.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primary.opacity(appState.activeModule == module ? 1.0 : 0.9))
                Circle()
                    .fill(appState.activeModule == module ? AppTheme.primary : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 46, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovering ? AppTheme.hover : Color.clear)
            )
            .contentShape(Rectangle())
            .gesture(tapGesture)
            .onHover { hovering in
                isHovering = hovering
            }
            .interactiveSurface(
                hoverScale: 1.015,
                pressScale: 0.985,
                hoverShadowOpacity: 0.12,
                feedback: .light
            )
            .animation(AppMotion.hover, value: isHovering)
            .contextMenu {
                Button(appState.desktopItems.contains(where: { $0.module == module }) ? "Vom Home entfernen" : "Auf Home anzeigen") {
                    appState.toggleDesktopPresence(for: module)
                }
            }
            .draggable(module.id)
            .help(module.title)
        }

        private var tapGesture: some Gesture {
            let doubleTap = TapGesture(count: 2)
                .onEnded {
                    Haptics.trigger(.light)
                    appState.openFloatingWindow(module)
                }
            let singleTap = TapGesture(count: 1)
                .onEnded {
                    Haptics.trigger(.light)
                    withAnimation(AppMotion.settle) {
                        appState.setActive(module)
                    }
                }
            return doubleTap.exclusively(before: singleTap)
        }
    }
}

#Preview {
    DockSwitcherView()
        .environmentObject(AppState())
        .frame(width: 600, height: 120)
        .padding()
}

import SwiftUI

struct TopBarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dataStore: AppDataStore

    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    private var moduleResults: [Module] {
        let token = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !token.isEmpty else { return [] }
        return Module.allCases.filter { module in
            module.title.lowercased().contains(token)
        }
    }

    private var unreadCount: Int {
        dataStore.messengerChats.reduce(0) { $0 + $1.unreadCount }
    }

    private var connectionLabel: String {
        switch dataStore.backendConnectionState {
        case .live:
            return "Online"
        case .syncing:
            return "Synchronisiert"
        case .placeholder:
            return "Lokal"
        case .failed:
            return "Offline"
        }
    }

    private var connectionColor: Color {
        switch dataStore.backendConnectionState {
        case .live:
            return AppTheme.primaryDark
        case .syncing:
            return .orange
        case .placeholder:
            return AppTheme.textSecondary
        case .failed:
            return .red
        }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            expandedRow
            compactRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(AppTheme.surface.opacity(0.96))
        .overlay(
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1),
            alignment: .bottom
        )
        .overlay(alignment: .topLeading) {
            if isSearchFocused && !moduleResults.isEmpty {
                searchResultsPopover
                    .padding(.top, 38)
                    .padding(.leading, 120)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .zIndex(20)
    }

    private var expandedRow: some View {
        HStack(spacing: 10) {
            appMenu

            searchBar
                .frame(maxWidth: 360)

            Spacer(minLength: 6)

            systemStatus
            controlCenterMenu
            widgetButton
        }
        .frame(height: 28)
    }

    private var compactRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                appMenu
                Spacer(minLength: 4)
                systemStatus
                widgetButton
            }
            HStack(spacing: 8) {
                searchBar
                    .frame(maxWidth: .infinity)
                controlCenterMenu
            }
        }
    }

    private var appMenu: some View {
        Menu {
            ForEach(Module.allCases) { module in
                Button(module.title) {
                    appState.openFloatingWindow(module)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "circle.grid.2x2")
                    .font(.system(size: 12, weight: .semibold))
                Text("PitchInsights")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.surfaceAlt)
            )
        }
        .menuStyle(.borderlessButton)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            TextField("Module suchen", text: $searchQuery)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .focused($isSearchFocused)
                .onSubmit {
                    guard let first = moduleResults.first else { return }
                    appState.openFloatingWindow(first)
                    searchQuery = ""
                    isSearchFocused = false
                }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private var systemStatus: some View {
        HStack(spacing: 10) {
            Label(connectionLabel, systemImage: "circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(connectionColor)

            if unreadCount > 0 {
                Text("\(unreadCount) ungelesen")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.surfaceAlt)
        )
    }

    private var controlCenterMenu: some View {
        Menu {
            Picker("Darstellung", selection: appearanceBinding) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Divider()

            Toggle("Reduzierte Animationen", isOn: reduceAnimationsBinding)
            Toggle("Interaktive Vorschauen", isOn: interactivePreviewsBinding)
        } label: {
            Label("Kontrollzentrum", systemImage: "slider.horizontal.3")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.surfaceAlt)
                )
        }
        .menuStyle(.borderlessButton)
    }

    private var widgetButton: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                appState.toggleWidgetBrowser()
            }
        } label: {
            Label("Widgets", systemImage: "square.grid.3x2")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(appState.isWidgetBrowserVisible ? AppTheme.hover : AppTheme.surfaceAlt)
                )
        }
        .buttonStyle(.plain)
    }

    private var searchResultsPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(moduleResults.prefix(8)) { module in
                Button {
                    appState.openFloatingWindow(module)
                    searchQuery = ""
                    isSearchFocused = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: module.iconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryDark)
                        Text(module.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow.opacity(0.2), radius: 12, x: 0, y: 8)
    }

    private var appearanceBinding: Binding<AppAppearanceMode> {
        Binding(
            get: { dataStore.settingsPresentation.appearanceMode },
            set: { mode in
                var updated = dataStore.settingsPresentation
                updated.appearanceMode = mode
                dataStore.settingsPresentation = updated
            }
        )
    }

    private var reduceAnimationsBinding: Binding<Bool> {
        Binding(
            get: { dataStore.settingsPresentation.reduceAnimations },
            set: { value in
                var updated = dataStore.settingsPresentation
                updated.reduceAnimations = value
                dataStore.settingsPresentation = updated
            }
        )
    }

    private var interactivePreviewsBinding: Binding<Bool> {
        Binding(
            get: { dataStore.settingsPresentation.interactivePreviews },
            set: { value in
                var updated = dataStore.settingsPresentation
                updated.interactivePreviews = value
                dataStore.settingsPresentation = updated
            }
        )
    }
}

#Preview {
    TopBarView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 980, height: 80)
}

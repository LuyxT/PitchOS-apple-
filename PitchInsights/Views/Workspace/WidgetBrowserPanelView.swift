import SwiftUI

struct WidgetBrowserPanelView: View {
    @EnvironmentObject private var appState: AppState

    @State private var query: String = ""

    private var filteredModules: [Module] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AppConfiguration.enabledModules
        }
        let token = query.lowercased()
        return AppConfiguration.enabledModules.filter { module in
            module.title.lowercased().contains(token)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(filteredModules) { module in
                        WidgetModuleSection(module: module)
                    }
                    if filteredModules.isEmpty {
                        Text("Keine Widgets gefunden.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.vertical, 24)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 980, height: 620)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow.opacity(0.26), radius: 22, x: 0, y: 12)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("Widget-Browser", systemImage: "square.grid.2x2")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            TextField("Widget suchen", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            Spacer(minLength: 8)

            Text("Small · Medium · Large")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                appState.hideWidgetBrowser()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(AppTheme.surfaceAlt)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct WidgetModuleSection: View {
    @EnvironmentObject private var appState: AppState

    let module: Module

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(module.title, systemImage: module.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .truncationMode(.tail)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DesktopWidgetSize.allCases) { size in
                        WidgetBrowserTile(module: module, size: size)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                    appState.addWidgetToDesktop(module, size: size)
                                }
                            }
                            .draggable(DesktopDragPayload.widget(module: module, size: size))
                    }
                }
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct WidgetBrowserTile: View {
    let module: Module
    let size: DesktopWidgetSize

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HomeWidgetCardView(module: module, size: size, isPreview: true)
                .scaleEffect(isHovering ? 1.012 : 1.0)
                .animation(.easeInOut(duration: 0.16), value: isHovering)

            HStack {
                Text(size.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Text("Hinzufügen")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.primaryDark)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 4)
            .frame(width: size.dimensions.width)
        }
        .frame(width: size.dimensions.width, height: size.dimensions.height + 30, alignment: .top)
        .clipped()
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

#Preview {
    WidgetBrowserPanelView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .padding()
}

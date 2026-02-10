import SwiftUI

struct ModuleDashboardView: View {
    let module: Module
    let subtitle: String
    let sections: [ModuleSection]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                quickActions
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(section.cards) { card in
                                ModuleCardView(card: card)
                            }
                        }
                    }
                }
                Spacer(minLength: 16)
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(module.title)
                    .font(.system(size: 22, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Button(action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Neu")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.primary)
                )
                .foregroundStyle(AppTheme.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            ForEach(QuickAction.samples) { action in
                HStack(spacing: 6) {
                    Image(systemName: action.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(action.title)
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                )
            }
            Spacer()
        }
    }
}

struct ModuleSection: Identifiable {
    let id = UUID()
    let title: String
    let cards: [ModuleCard]
}

struct ModuleCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
}

private struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String

    static let samples: [QuickAction] = [
        QuickAction(title: "Übersicht", icon: "square.grid.2x2"),
        QuickAction(title: "Filter", icon: "line.3.horizontal.decrease"),
        QuickAction(title: "Export", icon: "square.and.arrow.up")
    ]
}

private struct ModuleCardView: View {
    let card: ModuleCard

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: card.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.primary)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(card.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }
}

#Preview {
    ModuleDashboardView(
        module: .kalender,
        subtitle: "Termine und Spiele",
        sections: [
            ModuleSection(title: "Nächste Termine", cards: [
                ModuleCard(title: "Training", subtitle: "Heute 18:00", icon: "sportscourt"),
                ModuleCard(title: "Spieltag", subtitle: "Samstag 15:30", icon: "calendar")
            ])
        ]
    )
    .frame(width: 900, height: 600)
}

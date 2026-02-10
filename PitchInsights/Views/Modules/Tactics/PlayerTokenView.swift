import SwiftUI

struct PlayerTokenView: View {
    let player: Player
    let role: String?
    var isSelected: Bool = false
    var compact = false
    var fixedWidth: CGFloat? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            HStack(spacing: 6) {
                Text("#\(player.number)")
                    .font(.system(size: compact ? 10 : 11, weight: .bold))
                    .foregroundStyle(AppTheme.primaryDark)
                Text(player.name)
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Text(role ?? player.primaryPosition.rawValue)
                    .font(.system(size: compact ? 10 : 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(player.availability.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(statusColor.opacity(0.14)))
            }
        }
        .padding(compact ? 8 : 10)
        .frame(width: fixedWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? AppTheme.primary.opacity(0.16) : AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? AppTheme.primary : AppTheme.border, lineWidth: 1)
                )
        )
        .shadow(color: AppTheme.shadow.opacity(compact ? 0.08 : 0.14), radius: compact ? 6 : 10, x: 0, y: compact ? 2 : 4)
    }

    private var statusColor: Color {
        switch player.availability {
        case .fit:
            return AppTheme.primaryDark
        case .limited:
            return .orange
        case .unavailable:
            return .red
        }
    }
}

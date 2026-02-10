import SwiftUI

struct CalendarEventCard: View {
    let event: CalendarEvent
    let category: CalendarCategory?
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title.isEmpty ? "Neuer Termin" : event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("\(DateFormatters.dayTime.string(from: event.startDate)) – \(DateFormatters.dayTime.string(from: event.endDate))")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill((category?.color ?? AppTheme.primary).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? (category?.color ?? AppTheme.primary) : AppTheme.border, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .contextMenu {
            Button("Bearbeiten", action: onEdit)
            Button("Duplizieren", action: onDuplicate)
            Divider()
            Button("Löschen", role: .destructive, action: onDelete)
        }
    }
}

struct CalendarEventBlock: View {
    let event: CalendarEvent
    let category: CalendarCategory?
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title.isEmpty ? "Termin" : event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("\(DateFormatters.dayTime.string(from: event.startDate)) – \(DateFormatters.dayTime.string(from: event.endDate))")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill((category?.color ?? AppTheme.primary).opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? (category?.color ?? AppTheme.primary) : AppTheme.border, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .contextMenu {
            Button("Bearbeiten", action: onEdit)
            Button("Duplizieren", action: onDuplicate)
            Divider()
            Button("Löschen", role: .destructive, action: onDelete)
        }
    }
}

struct CalendarEventPill: View {
    let event: CalendarEvent
    let category: CalendarCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(category?.color ?? AppTheme.primary)
                    .frame(width: 6, height: 6)
                Text(event.title.isEmpty ? "Termin" : event.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }

            Text("\(DateFormatters.dayTime.string(from: event.startDate)) – \(DateFormatters.dayTime.string(from: event.endDate))")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.surfaceAlt)
        )
    }
}

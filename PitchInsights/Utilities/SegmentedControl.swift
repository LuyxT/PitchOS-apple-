import SwiftUI

struct SegmentedControl<Item: Identifiable & Equatable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    selection = item
                } label: {
                    Text(title(item))
                        .font(.system(size: 12, weight: item == selection ? .semibold : .regular))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 56, maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(
                    item == selection
                    ? AppTheme.surfaceAlt
                    : Color.clear
                )
                .overlay(
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: item.id == items.last?.id ? 0 : 1),
                    alignment: .trailing
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

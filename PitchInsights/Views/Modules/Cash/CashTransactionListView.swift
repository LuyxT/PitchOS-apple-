import SwiftUI

struct CashTransactionListView: View {
    @ObservedObject var viewModel: CashTransactionListViewModel
    let transactions: [CashTransaction]
    let categories: [CashCategory]
    let playersByID: [UUID: String]
    let trainerName: (String?) -> String
    let canEdit: Bool
    let canDelete: Bool
    let onEdit: (CashTransaction) -> Void
    let onDuplicate: (CashTransaction) -> Void
    let onDelete: (CashTransaction) -> Void
    let onLoadMore: () -> Void
    let canLoadMore: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(transactions) { transaction in
                        row(transaction)
                    }
                    if canLoadMore {
                        Button {
                            Haptics.trigger(.soft)
                            onLoadMore()
                        } label: {
                            Text("Mehr laden")
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            headerLabel("Datum", width: 112, alignment: .leading)
            headerLabel("Betrag", width: 120, alignment: .leading)
            headerLabel("Kategorie", width: 140, alignment: .leading)
            headerLabel("Spieler", width: 160, alignment: .leading)
            headerLabel("Verantwortlich", width: 170, alignment: .leading)
            headerLabel("Status", width: 120, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceAlt.opacity(0.5))
    }

    private func headerLabel(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .frame(width: width, alignment: alignment)
    }

    private func row(_ transaction: CashTransaction) -> some View {
        let amountColor = transaction.type == .income ? AppTheme.primaryDark : Color.red
        return HStack(spacing: 10) {
            Text(Self.dateFormatter.string(from: transaction.date))
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 112, alignment: .leading)

            Text("\(transaction.type == .income ? "+" : "-")\(Self.currencyFormatter.string(from: NSNumber(value: abs(transaction.amount))) ?? "0 €")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(amountColor)
                .frame(width: 120, alignment: .leading)

            Text(categoryName(for: transaction.categoryID))
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 140, alignment: .leading)

            Text(playersByID[transaction.playerID ?? UUID()] ?? "—")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 160, alignment: .leading)

            Text(trainerName(transaction.responsibleTrainerID))
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 170, alignment: .leading)

            Text(transaction.paymentStatus.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(statusColor(transaction.paymentStatus))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(statusColor(transaction.paymentStatus).opacity(0.14))
                )
                .frame(width: 120, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(viewModel.selectedTransactionID == transaction.id ? AppTheme.primary.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.trigger(.light)
            viewModel.select(transaction.id)
        }
        .onTapGesture(count: 2) {
            guard canEdit else { return }
            Haptics.trigger(.light)
            onEdit(transaction)
        }
        .interactiveSurface(hoverScale: 1.01, pressScale: 0.99, hoverShadowOpacity: 0.1, feedback: .light)
        .contextMenu {
            if canEdit {
                Button("Bearbeiten") {
                    Haptics.trigger(.light)
                    onEdit(transaction)
                }
                Button("Duplizieren") {
                    Haptics.trigger(.soft)
                    onDuplicate(transaction)
                }
            }
            if canDelete {
                Button("Löschen", role: .destructive) {
                    Haptics.trigger(.soft)
                    onDelete(transaction)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border.opacity(0.55))
                .frame(height: 1)
        }
    }

    private func categoryName(for id: UUID) -> String {
        categories.first(where: { $0.id == id })?.name ?? "Unbekannt"
    }

    private func statusColor(_ status: CashPaymentStatus) -> Color {
        switch status {
        case .paid:
            return AppTheme.primaryDark
        case .open:
            return .orange
        case .overdue:
            return .red
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}

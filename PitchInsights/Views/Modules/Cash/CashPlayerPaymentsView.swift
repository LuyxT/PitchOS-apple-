import SwiftUI

struct CashPlayerPaymentsView: View {
    @ObservedObject var viewModel: CashPlayerPaymentsViewModel
    let contributions: [MonthlyContribution]
    let playersByID: [UUID: String]
    let accessContext: CashAccessContext
    let onMarkStatus: (CashPaymentStatus) -> Void
    let onSendReminder: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            controls
            listCard
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            TextField("Spieler oder Monat", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color.black)
                .frame(width: 260)

            Picker("Status", selection: $viewModel.statusFilter) {
                Text("Alle").tag(Optional<CashPaymentStatus>.none)
                ForEach(CashPaymentStatus.allCases) { status in
                    Text(status.title).tag(Optional(status))
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(Color.black)

            Spacer()

            if accessContext.permissions.contains(.sendPaymentReminder) {
                Button {
                    onSendReminder()
                } label: {
                    Text("Erinnerung senden")
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(viewModel.selectedContributionIDs.isEmpty)
            }

            Menu {
                ForEach(CashPaymentStatus.allCases) { status in
                    Button(status.title) {
                        onMarkStatus(status)
                    }
                }
            } label: {
                Label("Status setzen", systemImage: "checkmark.circle")
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(viewModel.selectedContributionIDs.isEmpty)
        }
    }

    private var listCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                header("Spieler", width: 220)
                header("Monat", width: 110)
                header("Fällig", width: 130)
                header("Betrag", width: 120)
                header("Status", width: 130)
                header("Letzte Erinnerung", width: 160)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.surfaceAlt.opacity(0.5))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(contributions) { contribution in
                        paymentRow(contribution)
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

    private func header(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .frame(width: width, alignment: .leading)
    }

    private func paymentRow(_ contribution: MonthlyContribution) -> some View {
        let selected = viewModel.selectedContributionIDs.contains(contribution.id)
        return HStack(spacing: 8) {
            Text(playersByID[contribution.playerID] ?? "Unbekannt")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 220, alignment: .leading)

            Text(contribution.monthKey)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 110, alignment: .leading)

            Text(Self.dateFormatter.string(from: contribution.dueDate))
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 130, alignment: .leading)

            Text(Self.currencyFormatter.string(from: NSNumber(value: contribution.amount)) ?? "0 €")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 120, alignment: .leading)

            Text(contribution.status.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color(contribution.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(color(contribution.status).opacity(0.14))
                )
                .frame(width: 130, alignment: .leading)

            Text(contribution.lastReminderAt.map(Self.dateTimeFormatter.string(from:)) ?? "—")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 160, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? AppTheme.primary.opacity(0.12) : Color.clear)
        )
        .onTapGesture {
            viewModel.toggleSelection(contribution.id)
        }
        .contextMenu {
            ForEach(CashPaymentStatus.allCases) { status in
                Button(status.title) {
                    viewModel.selectedContributionIDs = [contribution.id]
                    onMarkStatus(status)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border.opacity(0.55))
                .frame(height: 1)
        }
    }

    private func color(_ status: CashPaymentStatus) -> Color {
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
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
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

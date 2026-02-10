import SwiftUI

struct CashTransactionDetailView: View {
    @ObservedObject var viewModel: CashTransactionDetailViewModel
    let categories: [CashCategory]
    let players: [Player]
    let trainers: [AdminPerson]
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Transaktion")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black)

            Picker("Typ", selection: $viewModel.localDraft.type) {
                ForEach(CashTransactionKind.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Betrag")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black)
                    TextField("", value: $viewModel.localDraft.amount, formatter: Self.currencyFormatter)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(Color.black)
                }
                DatePicker("Datum", selection: $viewModel.localDraft.date, displayedComponents: [.date])
                    .foregroundStyle(Color.black)
            }

            Picker("Kategorie", selection: $viewModel.localDraft.categoryID) {
                ForEach(categories) { category in
                    Text(category.name).tag(category.id)
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(Color.black)

            TextField("Beschreibung", text: $viewModel.localDraft.description)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color.black)

            HStack(spacing: 12) {
                Picker("Spieler", selection: Binding(
                    get: { viewModel.localDraft.playerID },
                    set: { viewModel.localDraft.playerID = $0 }
                )) {
                    Text("Kein Spieler").tag(Optional<UUID>.none)
                    ForEach(players) { player in
                        Text(player.name).tag(Optional(player.id))
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(Color.black)

                Picker("Verantwortlich", selection: Binding(
                    get: { viewModel.localDraft.responsibleTrainerID },
                    set: { viewModel.localDraft.responsibleTrainerID = $0 }
                )) {
                    Text("Nicht gesetzt").tag(Optional<String>.none)
                    ForEach(trainers) { trainer in
                        Text(trainer.fullName).tag(Optional(trainer.backendID ?? trainer.id.uuidString))
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(Color.black)
            }

            Picker("Zahlungsstatus", selection: $viewModel.localDraft.paymentStatus) {
                ForEach(CashPaymentStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            }
            .pickerStyle(.segmented)

            TextField("Kontext", text: Binding(
                get: { viewModel.localDraft.contextLabel ?? "" },
                set: { viewModel.localDraft.contextLabel = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .foregroundStyle(Color.black)

            TextField("Kommentar", text: $viewModel.localDraft.comment, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color.black)
                .lineLimit(3...6)

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Abbrechen", action: onCancel)
                    .buttonStyle(SecondaryActionButtonStyle())
                Button("Speichern") {
                    guard viewModel.validate() else { return }
                    onSave()
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(18)
        .background(AppTheme.background)
        .environment(\.colorScheme, .light)
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}

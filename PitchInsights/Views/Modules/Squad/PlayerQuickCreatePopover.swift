import SwiftUI

struct PlayerQuickCreatePopover: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var numberText = ""
    @State private var position: PlayerPosition = .zm

    let onCreate: (_ name: String, _ number: Int, _ position: PlayerPosition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Neuer Spieler")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Rückennummer", text: $numberText)
                .textFieldStyle(.roundedBorder)

            Picker("Hauptposition", selection: $position) {
                ForEach(PlayerPosition.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Spacer()
                Button("Abbrechen") {
                    dismiss()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button("Anlegen") {
                    guard let number = Int(numberText) else { return }
                    onCreate(name, number, position)
                    dismiss()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Int(numberText) == nil)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

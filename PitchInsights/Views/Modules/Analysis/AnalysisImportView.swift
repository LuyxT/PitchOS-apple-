import SwiftUI

struct AnalysisImportView: View {
    @Binding var title: String
    let isImporting: Bool
    let errorMessage: String?
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "film.stack")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(AppTheme.primary)

            VStack(spacing: 6) {
                Text("Neue Spielanalyse")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Video importieren und Analyse starten")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            TextField("Titel", text: $title)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 340)
                .foregroundStyle(AppTheme.textPrimary)

            Button {
                onImport()
            } label: {
                Label(isImporting ? "Import läuft..." : "Video auswählen", systemImage: "plus")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isImporting)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

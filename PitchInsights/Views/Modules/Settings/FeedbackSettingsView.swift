import SwiftUI
import UniformTypeIdentifiers

struct FeedbackSettingsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: FeedbackSettingsViewModel
    let activeModuleID: String

    @State private var isImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Feedback & Support")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black)

                Picker("Kategorie", selection: $viewModel.draft.category) {
                    ForEach(FeedbackCategory.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(Color.black)

                TextEditor(text: $viewModel.draft.message)
                    .frame(minHeight: 160)
                    .foregroundStyle(Color.black)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.surfaceAlt.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    TextField("Screenshot-Pfad (optional)", text: Binding(
                        get: { viewModel.draft.screenshotPath ?? "" },
                        set: { value in
                            viewModel.draft.screenshotPath = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(Color.black)

                    Button("Screenshot wählen") {
                        isImporterPresented = true
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.submit(store: dataStore, activeModuleID: activeModuleID) }
                    } label: {
                        Label("Feedback senden", systemImage: "paperplane")
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(viewModel.isSubmitting)
                }
            }
            .padding(12)
            .background(cardBackground)
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result {
                viewModel.draft.screenshotPath = urls.first?.path
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

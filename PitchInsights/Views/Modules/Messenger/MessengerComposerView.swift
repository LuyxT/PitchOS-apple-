import SwiftUI

struct MessengerComposerView: View {
    @ObservedObject var composerViewModel: MessageComposerViewModel
    let availableClips: [AnalysisClip]
    let onPickMedia: () -> Void
    let onDropCloudFile: (UUID) -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !composerViewModel.selectedCloudFileName.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                    Text("Datei: \(composerViewModel.selectedCloudFileName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Button("Entfernen") {
                        composerViewModel.selectedCloudFileID = nil
                        composerViewModel.selectedCloudFileName = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)
            }

            if !composerViewModel.pendingAttachmentName.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                    Text(composerViewModel.pendingAttachmentName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Button("Entfernen") {
                        composerViewModel.pendingAttachmentURL = nil
                        composerViewModel.pendingAttachmentName = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)
            }

            if let selectedClipID = composerViewModel.selectedClipID,
               let clip = availableClips.first(where: { $0.id == selectedClipID }) {
                HStack(spacing: 8) {
                    Image(systemName: "film")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                    Text("Clip: \(clip.name)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Button("Entfernen") {
                        composerViewModel.selectedClipID = nil
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 10)
            }

            TextEditor(text: $composerViewModel.text)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(minHeight: 56, maxHeight: 110)
                .padding(.horizontal, 6)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.surfaceAlt.opacity(0.5))
                )

            HStack(spacing: 8) {
                TextField("Kontext (optional)", text: $composerViewModel.contextLabel)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(AppTheme.textPrimary)

                Menu {
                    Button("Kein Clip") {
                        composerViewModel.selectedClipID = nil
                    }
                    ForEach(availableClips) { clip in
                        Button(clip.name) {
                            composerViewModel.selectedClipID = clip.id
                        }
                    }
                } label: {
                    Label("Clip", systemImage: "film")
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button {
                    onPickMedia()
                } label: {
                    Label("Datei", systemImage: "paperclip")
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button("Senden") {
                    onSend()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!composerViewModel.canSend || composerViewModel.isSending)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
        .foregroundStyle(Color.black)
        .dropDestination(for: String.self) { items, _ in
            for value in items {
                guard let id = UUID(uuidString: value) else { continue }
                onDropCloudFile(id)
                return true
            }
            return false
        }
    }
}

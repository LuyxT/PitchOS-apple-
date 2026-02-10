import SwiftUI

struct FolderWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    let folderId: UUID

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(folderTitle)
                .font(.system(size: 22, weight: .semibold))
            Text("Ordnerinhalt")
                .foregroundStyle(AppTheme.textSecondary)
                .font(.system(size: 12))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var folderTitle: String {
        appState.desktopItems.first(where: { $0.id == folderId })?.name ?? "Ordner"
    }
}

#Preview {
    FolderWorkspaceView(folderId: UUID())
        .environmentObject(AppState())
        .frame(width: 800, height: 500)
}

import SwiftUI
import UniformTypeIdentifiers

struct FilesWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dataStore: AppDataStore

    @StateObject private var viewModel = FilesWorkspaceViewModel()

    @State private var isShowingImporter = false
    @State private var pendingNewFolderName = ""
    @State private var pendingRename = ""
    @State private var pendingTags = ""
    @State private var searchDebounceTask: Task<Void, Never>?

    private var selectedFile: CloudFile? {
        guard let id = viewModel.selectedFileID else { return nil }
        return dataStore.cloudFiles.first(where: { $0.id == id })
    }

    var body: some View {
        VStack(spacing: 0) {
            topToolbar
            usageHeader
            Divider()
            content
            statusBar
        }
        .background(AppTheme.background)
        .environment(\.colorScheme, .light)
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            Task {
                await viewModel.upload(urls: urls, store: dataStore)
                await dataStore.refreshCloudCleanupSuggestions()
            }
        }
        .onAppear {
            Task {
                await viewModel.bootstrapIfNeeded(store: dataStore)
                await dataStore.refreshCloudCleanupSuggestions()
            }
        }
        .onChange(of: viewModel.filter.status) { _, _ in
            Task {
                await viewModel.refresh(store: dataStore)
            }
        }
        .onChange(of: viewModel.filter.type) { _, _ in
            Task {
                await viewModel.refresh(store: dataStore)
            }
        }
        .onChange(of: viewModel.filter.sortField) { _, _ in
            Task {
                await viewModel.refresh(store: dataStore)
            }
        }
        .onChange(of: viewModel.filter.sortDirection) { _, _ in
            Task {
                await viewModel.refresh(store: dataStore)
            }
        }
        .onChange(of: viewModel.filter.query) { _, _ in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 250_000_000)
                await viewModel.refresh(store: dataStore)
            }
        }
    }

    private var topToolbar: some View {
        ViewThatFits(in: .horizontal) {
            fullToolbarRow
            compactToolbarLayout
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
        .foregroundStyle(AppTheme.textPrimary)
    }

    private var fullToolbarRow: some View {
        HStack(spacing: 8) {
            actionButtonsRow

            Divider()
                .frame(height: 18)

            searchField
                .frame(maxWidth: 320)

            typeFilterPicker
            sortFieldPicker
            sortDirectionPicker

            Spacer(minLength: 8)

            trashToggle
                .frame(width: 150)
        }
    }

    private var compactToolbarLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                actionButtonsRow
                Spacer(minLength: 8)
                trashToggle
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    searchField
                        .frame(width: 260)
                    typeFilterPicker
                    sortFieldPicker
                    sortDirectionPicker
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var actionButtonsRow: some View {
        HStack(spacing: 8) {
            Button {
                if pendingNewFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    pendingNewFolderName = "Neuer Ordner"
                }
                Task {
                    await viewModel.createFolder(name: pendingNewFolderName, store: dataStore)
                    pendingNewFolderName = ""
                }
            } label: {
                Label("Neuer Ordner", systemImage: "folder.badge.plus")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Button {
                isShowingImporter = true
            } label: {
                Label("Upload", systemImage: "arrow.up.doc")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button {
                Task {
                    await viewModel.refresh(store: dataStore)
                    await dataStore.refreshCloudCleanupSuggestions()
                }
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private var searchField: some View {
        TextField("Suchen nach Name, Tag oder Typ", text: $viewModel.filter.query)
            .textFieldStyle(.roundedBorder)
    }

    private var typeFilterPicker: some View {
        Picker("Typ", selection: $viewModel.filter.type) {
            Text("Alle").tag(Optional<CloudFileType>.none)
            ForEach(CloudFileType.allCases) { type in
                Text(type.title).tag(Optional(type))
            }
        }
        .pickerStyle(.menu)
        .frame(width: 130)
    }

    private var sortFieldPicker: some View {
        Picker("Sortierung", selection: $viewModel.filter.sortField) {
            Text("Name").tag(CloudFileSortField.name)
            Text("Erstellt").tag(CloudFileSortField.createdAt)
            Text("Geändert").tag(CloudFileSortField.updatedAt)
            Text("Größe").tag(CloudFileSortField.sizeBytes)
        }
        .pickerStyle(.menu)
        .frame(width: 130)
    }

    private var sortDirectionPicker: some View {
        Picker("Richtung", selection: $viewModel.filter.sortDirection) {
            Text("Aufsteigend").tag(CloudSortDirection.ascending)
            Text("Absteigend").tag(CloudSortDirection.descending)
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }

    private var trashToggle: some View {
        Toggle(isOn: Binding(
            get: { viewModel.filter.status == .trash },
            set: { viewModel.toggleTrash($0) }
        )) {
            Text("Papierkorb")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .toggleStyle(.switch)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var usageHeader: some View {
        StorageUsageView(
            usage: dataStore.cloudUsage,
            uploads: dataStore.cloudUploads
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
    }

    private var content: some View {
        HStack(spacing: 10) {
            folderColumn
            filesTable
            detailsColumn
        }
        .padding(12)
    }

    private var folderColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ordner")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            List(selection: $viewModel.selectedFolderID) {
                ForEach(viewModel.visibleFolders(in: dataStore)) { folder in
                    Label(folder.name, systemImage: folder.name == CloudSystemFolder.trash.rawValue ? "trash" : "folder")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .tag(Optional(folder.id))
                        .contextMenu {
                            if !folder.isSystemFolder {
                                Button("Ordner umbenennen") {
                                    pendingNewFolderName = folder.name
                                }
                                Button("Als aktiver Ordner setzen") {
                                    viewModel.selectFolder(folder.id, store: dataStore)
                                }
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(width: 220)
        .onChange(of: viewModel.selectedFolderID) { _, folderID in
            viewModel.selectFolder(folderID, store: dataStore)
            Task { await viewModel.refresh(store: dataStore) }
        }
    }

    @ViewBuilder
    private var filesTable: some View {
        #if os(macOS)
        Table(viewModel.files(in: dataStore), selection: $viewModel.selectedFileID) {
            TableColumn("Name") { file in
                HStack(spacing: 8) {
                    Image(systemName: file.type.iconName)
                        .foregroundStyle(AppTheme.primary)
                    Text(file.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                .draggable(file.id.uuidString)
                .contextMenu {
                    contextMenu(for: file)
                }
            }
            .width(min: 220)

            TableColumn("Typ") { file in
                Text(file.type.title)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .width(min: 90, max: 120)

            TableColumn("Größe") { file in
                Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .width(min: 110, max: 140)

            TableColumn("Geändert") { file in
                Text(DateFormatters.dayTime.string(from: file.updatedAt))
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .width(min: 130, max: 160)

            TableColumn("Status") { file in
                Text(file.deletedAt == nil ? "Aktiv" : "Papierkorb")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(file.deletedAt == nil ? AppTheme.textSecondary : .orange)
            }
            .width(min: 100, max: 120)
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        #else
        List(viewModel.files(in: dataStore), selection: $viewModel.selectedFileID) { file in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: file.type.iconName)
                        .foregroundStyle(AppTheme.primary)
                    Text(file.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Text(file.type.title)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .contextMenu {
                contextMenu(for: file)
            }
        }
        .listStyle(.plain)
        #endif
    }

    private var detailsColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let file = selectedFile {
                Text("Details")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name", text: Binding(
                        get: { pendingRename.isEmpty ? file.name : pendingRename },
                        set: { pendingRename = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    TextField("Tags (Komma getrennt)", text: Binding(
                        get: { pendingTags.isEmpty ? file.tags.joined(separator: ", ") : pendingTags },
                        set: { pendingTags = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        Button("Speichern") {
                            let tags = pendingTags
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            Task {
                                await viewModel.renameSelected(to: pendingRename.isEmpty ? file.name : pendingRename, store: dataStore)
                                if !tags.isEmpty {
                                    try? await dataStore.updateCloudFile(fileID: file.id, name: nil, tags: tags, visibility: nil)
                                }
                                pendingRename = ""
                                pendingTags = ""
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Button("Öffnen") {
                            Task {
                                await viewModel.openSelected(store: dataStore, appState: appState)
                            }
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    Divider()

                    detailRow(title: "Typ", value: file.type.title)
                    detailRow(title: "Größe", value: ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                    detailRow(title: "Sichtbarkeit", value: visibilityTitle(file.visibility))
                    detailRow(title: "Aktualisiert", value: DateFormatters.shortDateTime.string(from: file.updatedAt))
                    detailRow(title: "Owner", value: file.ownerUserID)
                }
                .padding(10)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Größte Dateien")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(dataStore.cloudLargestFiles.prefix(5)) { file in
                    HStack {
                        Text(file.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Alte Dateien")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(dataStore.cloudOldFiles.prefix(5)) { file in
                    HStack {
                        Text(file.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(DateFormatters.shortDate.string(from: file.updatedAt))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
        .frame(width: 300)
    }

    private var statusBar: some View {
        HStack {
            Text(viewModel.statusMessage ?? dataStore.cloudLastErrorMessage ?? "Bereit")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            if dataStore.cloudFileNextCursor != nil {
                Button("Mehr laden") {
                    Task {
                        await viewModel.loadMore(store: dataStore)
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func contextMenu(for file: CloudFile) -> some View {
        Button("Öffnen") {
            Task {
                viewModel.selectedFileID = file.id
                await viewModel.openSelected(store: dataStore, appState: appState)
            }
        }
        if file.deletedAt == nil {
            Button("In Papierkorb") {
                Task {
                    viewModel.selectedFileID = file.id
                    await viewModel.moveToTrashSelected(store: dataStore)
                }
            }
        } else {
            Button("Wiederherstellen") {
                Task {
                    viewModel.selectedFileID = file.id
                    await viewModel.restoreSelected(store: dataStore)
                }
            }
            Button("Endgültig löschen", role: .destructive) {
                Task {
                    viewModel.selectedFileID = file.id
                    await viewModel.deleteSelectedPermanently(store: dataStore)
                }
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func visibilityTitle(_ visibility: CloudFileVisibility) -> String {
        switch visibility {
        case .teamWide:
            return "Teamweit"
        case .restricted:
            return "Eingeschränkt"
        case .explicitShareList:
            return "Explizite Freigabe"
        }
    }
}

private struct StorageUsageView: View {
    let usage: TeamStorageUsage
    let uploads: [CloudUploadProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Speicher")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(ByteCountFormatter.string(fromByteCount: usage.usedBytes, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: usage.quotaBytes, countStyle: .file))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            ProgressView(value: usage.utilization)
                .tint(progressColor)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)

            HStack {
                Text(warningText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(progressColor)
                Spacer()
                if let activeUpload = uploads.first(where: { $0.state == .uploading || $0.state == .queued }) {
                    Text("Upload: \(activeUpload.filename) \(Int(activeUpload.progressValue * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private var progressColor: Color {
        switch usage.warningLevel {
        case .normal:
            return AppTheme.primary
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }

    private var warningText: String {
        switch usage.warningLevel {
        case .normal:
            return "Speicher im normalen Bereich."
        case .warning:
            return "Warnung: Speicher bei mindestens 80%."
        case .critical:
            return "Kritisch: Speicher bei mindestens 95%."
        }
    }
}

#Preview {
    FilesWorkspaceView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 1300, height: 760)
}

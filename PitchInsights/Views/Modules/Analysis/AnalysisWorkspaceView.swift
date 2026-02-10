import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct AnalysisWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dataStore: AppDataStore

    @StateObject private var workspaceViewModel = AnalysisWorkspaceViewModel()
    @StateObject private var playerViewModel = AnalysisPlayerViewModel()
    @StateObject private var drawingViewModel = AnalysisDrawingViewModel()

    @State private var importTitle = "Neue Analyse"
    @State private var isShowingFileImporter = false

    @State private var isShowingMarkerComposer = false
    @State private var markerComment = ""
    @State private var markerCategoryID: UUID?
    @State private var markerPlayerID: UUID?

    @State private var isShowingClipComposer = false
    @State private var clipName = ""
    @State private var clipNote = ""
    @State private var clipPlayerIDs: Set<UUID> = []

    @State private var sharingClipID: UUID?
    @State private var sharePlayerIDs: Set<UUID> = []
    @State private var shareMessage = ""
    @State private var selectedDrawingID: UUID?
    @State private var highlightMarkerID: UUID?

    @State private var liveDrawings: [AnalysisDrawing] = []
    @State private var activePlaybackURL: URL?

    private var sessions: [AnalysisSession] {
        dataStore.analysisSessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var activeSession: AnalysisSession? {
        workspaceViewModel.activeSession(in: dataStore)
    }

    private var activeMarkers: [AnalysisMarker] {
        workspaceViewModel.filteredMarkers(in: dataStore)
    }

    private var activeClips: [AnalysisClip] {
        workspaceViewModel.clips(in: dataStore)
    }

    private var persistentDrawings: [AnalysisDrawing] {
        liveDrawings
            .filter { !$0.isTemporary }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                AnalysisImportView(
                    title: $importTitle,
                    isImporting: workspaceViewModel.isImportRunning,
                    errorMessage: workspaceViewModel.importErrorMessage,
                    onImport: importVideo
                )
            } else {
                workspaceContent
            }
        }
        .background(AppTheme.background)
        .environment(\.colorScheme, .light)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let first = urls.first else { return }
            Task {
                await workspaceViewModel.createAnalysis(from: first, title: importTitle, store: dataStore)
                await loadActiveSession()
            }
        }
        .popover(isPresented: $isShowingMarkerComposer, arrowEdge: .bottom) {
            markerComposer
                .frame(width: 300)
                .padding(12)
        }
        .popover(isPresented: $isShowingClipComposer, arrowEdge: .bottom) {
            clipComposer
                .frame(width: 320)
                .padding(12)
        }
        .popover(isPresented: Binding(
            get: { sharingClipID != nil },
            set: { if !$0 { sharingClipID = nil } }
        ), arrowEdge: .bottom) {
            shareComposer
                .frame(width: 320)
                .padding(12)
        }
        .onAppear {
            workspaceViewModel.bootstrap(with: dataStore)
            syncDrawingsFromStore()
            Task {
                await loadActiveSession()
                await applyPendingClipReferenceIfNeeded()
            }
        }
        .onChange(of: workspaceViewModel.selectedSessionID) { _, _ in
            Task {
                await loadActiveSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .analysisCommandAddMarker)) { _ in
            Haptics.trigger(.soft)
            isShowingMarkerComposer = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .analysisCommandToggleClip)) { _ in
            Haptics.trigger(.soft)
            toggleClipBoundary()
        }
        .onReceive(NotificationCenter.default.publisher(for: .analysisCommandPresentation)) { _ in
            Haptics.trigger(.light)
            workspaceViewModel.isPresentationMode.toggle()
            if workspaceViewModel.isPresentationMode {
                workspaceViewModel.isCompareMode = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .analysisCommandCompare)) { _ in
            Haptics.trigger(.light)
            workspaceViewModel.isCompareMode.toggle()
            if workspaceViewModel.isCompareMode {
                workspaceViewModel.isPresentationMode = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .analysisCommandPlayPause)) { _ in
            playerViewModel.togglePlayPause()
        }
        .onReceive(NotificationCenter.default.publisher(for: .analysisCommandStepBackward)) { _ in
            playerViewModel.frameStepBackward()
        }
        .onReceive(NotificationCenter.default.publisher(for: .analysisCommandStepForward)) { _ in
            playerViewModel.frameStepForward()
        }
        .onReceive(NotificationCenter.default.publisher(for: .analysisCommandZoomIn)) { _ in
            playerViewModel.zoomInTimeline()
        }
        .onReceive(NotificationCenter.default.publisher(for: .analysisCommandZoomOut)) { _ in
            playerViewModel.zoomOutTimeline()
        }
        .overlay(shortcutLayer)
    }

    private var workspaceContent: some View {
        VStack(spacing: 0) {
            AnalysisToolbarView(
                sessions: sessions,
                selectedSessionID: $workspaceViewModel.selectedSessionID,
                isDrawingMode: $drawingViewModel.isDrawingMode,
                drawingTool: $drawingViewModel.selectedTool,
                isTemporaryDrawing: $drawingViewModel.isTemporary,
                areDrawingsVisible: $drawingViewModel.areDrawingsVisible,
                isCompareMode: $workspaceViewModel.isCompareMode,
                isPresentationMode: $workspaceViewModel.isPresentationMode,
                onImportVideo: importVideo,
                onAddMarker: { isShowingMarkerComposer = true },
                onToggleClip: toggleClipBoundary
            )

            if workspaceViewModel.isPresentationMode {
                AnalysisPresentationView(
                    playerViewModel: playerViewModel,
                    markers: activeMarkers,
                    drawings: liveDrawings
                )
            } else if workspaceViewModel.isCompareMode,
                      let compare = comparePair() {
                AnalysisCompareView(
                    playbackURL: compare.playbackURL,
                    leftClip: compare.left,
                    rightClip: compare.right
                )
            } else {
                standardLayout
            }

            if let message = workspaceViewModel.statusMessage, !message.isEmpty {
                HStack {
                    Text(message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private var standardLayout: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 1100 || proxy.size.height < 700
            let playerHeight = max(230, proxy.size.height * 0.52)

            Group {
                if compact {
                    VStack(spacing: 12) {
                        playerSection
                            .frame(height: playerHeight)
                        ScrollView {
                            sidePanels
                                .frame(maxWidth: .infinity, alignment: .top)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(12)
                } else {
                    HStack(spacing: 12) {
                        playerSection
                            .frame(maxWidth: .infinity)
                        ScrollView {
                            sidePanels
                                .frame(maxWidth: .infinity, alignment: .top)
                        }
                        .frame(width: min(340, proxy.size.width * 0.33))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(12)
                }
            }
        }
    }

    private var playerSection: some View {
        VStack(spacing: 0) {
            AnalysisPlayerPane(
                playerViewModel: playerViewModel,
                drawingViewModel: drawingViewModel,
                drawings: liveDrawings,
                sessionID: activeSession?.id,
                onDrawingsChange: { drawings in
                    liveDrawings = drawings
                    if let latest = drawings.last, latest.isTemporary {
                        drawingViewModel.scheduleTemporaryCleanup(for: latest.id) {
                            liveDrawings.removeAll { $0.id == latest.id }
                            Task {
                                await persistPersistentDrawings()
                            }
                        }
                    }
                    Task {
                        await persistPersistentDrawings()
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AnalysisTimelineView(
                playerViewModel: playerViewModel,
                markers: activeMarkers
            ) { marker in
                playerViewModel.seek(to: marker.timeSeconds)
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

    private var sidePanels: some View {
        GeometryReader { proxy in
            let drawingsHeight = max(120, min(180, proxy.size.height * 0.24))
            let remaining = max(240, proxy.size.height - drawingsHeight - 24)
            let panelHeight = max(120, remaining / 2)

            VStack(spacing: 12) {
                markersPanel
                    .frame(height: panelHeight)
                clipsPanel
                    .frame(height: panelHeight)
                drawingsPanel
                    .frame(height: drawingsHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var markersPanel: some View {
        AnalysisMarkersPanel(
            markers: activeMarkers,
            categories: dataStore.analysisCategories,
            players: dataStore.players,
            selectedMarkerID: $workspaceViewModel.selectedMarkerID,
            selectedCategoryFilters: $workspaceViewModel.filterState.categoryIDs,
            selectedPlayerFilters: $workspaceViewModel.filterState.playerIDs,
            highlightMarkerID: highlightMarkerID,
            onSeek: { marker in
                playerViewModel.seek(to: marker.timeSeconds)
            },
            onDelete: { marker in
                Task {
                    await workspaceViewModel.deleteMarker(marker.id, store: dataStore)
                }
            }
        )
    }

    private var clipsPanel: some View {
        AnalysisClipsPanel(
            clips: activeClips,
            players: dataStore.players,
            selectedClipID: $workspaceViewModel.selectedClipID,
            onSelect: { clip in
                workspaceViewModel.selectedClipID = clip.id
                playerViewModel.seek(to: clip.startSeconds)
            },
            onDelete: { clip in
                Task {
                    await workspaceViewModel.deleteClip(clip.id, store: dataStore)
                }
            },
            onShare: { clip in
                sharingClipID = clip.id
                sharePlayerIDs = Set(clip.playerIDs)
                shareMessage = ""
            }
        )
    }

    private var drawingsPanel: some View {
        AnalysisDrawingsPanel(
            drawings: persistentDrawings,
            selectedDrawingID: $selectedDrawingID,
            onDelete: { drawing in
                removeDrawing(drawing.id)
            },
            onDeleteAll: {
                removeAllDrawings()
            }
        )
    }

    private var markerComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Marker setzen")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Zeit: \(format(playerViewModel.currentTime))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            Picker("Kategorie", selection: $markerCategoryID) {
                Text("Keine").tag(Optional<UUID>.none)
                ForEach(dataStore.analysisCategories) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            .pickerStyle(.menu)

            Picker("Spieler", selection: $markerPlayerID) {
                Text("Kein Spieler").tag(Optional<UUID>.none)
                ForEach(dataStore.players) { player in
                    Text(player.name).tag(Optional(player.id))
                }
            }
            .pickerStyle(.menu)

            TextField("Kommentar", text: $markerComment)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Abbrechen") {
                    Haptics.trigger(.soft)
                    isShowingMarkerComposer = false
                }
                .buttonStyle(SecondaryActionButtonStyle())
                Button("Speichern") {
                    Task {
                        await workspaceViewModel.createMarker(
                            store: dataStore,
                            at: playerViewModel.currentTime,
                            categoryID: markerCategoryID,
                            comment: markerComment,
                            playerID: markerPlayerID
                        )
                        if let sessionID = activeSession?.id {
                            let newMarker = dataStore.analysisMarkers
                                .filter { $0.sessionID == sessionID }
                                .max { $0.createdAt < $1.createdAt }
                            if let newMarker {
                                Haptics.trigger(.success)
                                withAnimation(AppMotion.settle) {
                                    workspaceViewModel.selectedMarkerID = newMarker.id
                                    highlightMarkerID = newMarker.id
                                }
                                Task {
                                    try? await Task.sleep(nanoseconds: 800_000_000)
                                    if highlightMarkerID == newMarker.id {
                                        withAnimation(AppMotion.settle) {
                                            highlightMarkerID = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                    markerComment = ""
                    markerCategoryID = nil
                    markerPlayerID = nil
                    isShowingMarkerComposer = false
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }

    private var clipComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Clip speichern")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            let start = workspaceViewModel.clipStartTime ?? playerViewModel.currentTime
            let end = playerViewModel.currentTime
            Text("Start: \(format(start))  Ende: \(format(end))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            TextField("Clip-Name", text: $clipName)
                .textFieldStyle(.roundedBorder)
            TextField("Notiz", text: $clipNote)
                .textFieldStyle(.roundedBorder)

            Menu("Spieler zuordnen") {
                ForEach(dataStore.players) { player in
                    Button {
                        if clipPlayerIDs.contains(player.id) {
                            clipPlayerIDs.remove(player.id)
                        } else {
                            clipPlayerIDs.insert(player.id)
                        }
                    } label: {
                        if clipPlayerIDs.contains(player.id) {
                            Label(player.name, systemImage: "checkmark")
                        } else {
                            Text(player.name)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Abbrechen") {
                    isShowingClipComposer = false
                    workspaceViewModel.clipStartTime = nil
                }
                .buttonStyle(SecondaryActionButtonStyle())
                Button("Speichern") {
                    let finalName = clipName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Clip \(format(start))"
                    : clipName

                    Task {
                        await workspaceViewModel.createClip(
                            store: dataStore,
                            name: finalName,
                            startSeconds: min(start, end),
                            endSeconds: max(start, end),
                            playerIDs: Array(clipPlayerIDs),
                            note: clipNote
                        )
                    }
                    clipName = ""
                    clipNote = ""
                    clipPlayerIDs.removeAll()
                    workspaceViewModel.clipStartTime = nil
                    isShowingClipComposer = false
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }

    private var shareComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Clip teilen")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Menu("Spieler") {
                ForEach(dataStore.players) { player in
                    Button {
                        if sharePlayerIDs.contains(player.id) {
                            sharePlayerIDs.remove(player.id)
                        } else {
                            sharePlayerIDs.insert(player.id)
                        }
                    } label: {
                        if sharePlayerIDs.contains(player.id) {
                            Label(player.name, systemImage: "checkmark")
                        } else {
                            Text(player.name)
                        }
                    }
                }
            }

            TextField("Nachricht", text: $shareMessage)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Abbrechen") {
                    sharingClipID = nil
                }
                .buttonStyle(SecondaryActionButtonStyle())
                Button("Senden") {
                    guard let clipID = sharingClipID else { return }
                    Task {
                        await workspaceViewModel.shareClip(
                            clipID,
                            to: Array(sharePlayerIDs),
                            message: shareMessage,
                            store: dataStore
                        )
                    }
                    sharingClipID = nil
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }

    private var shortcutLayer: some View {
        HStack(spacing: 0) {
            Button("") { playerViewModel.togglePlayPause() }
                .keyboardShortcut(.space, modifiers: [])
            Button("") { playerViewModel.frameStepBackward() }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("") { playerViewModel.frameStepForward() }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button("") { playerViewModel.zoomInTimeline() }
                .keyboardShortcut("+", modifiers: [.command])
            Button("") { playerViewModel.zoomOutTimeline() }
                .keyboardShortcut("-", modifiers: [.command])
            Button("") { isShowingMarkerComposer = true }
                .keyboardShortcut("m", modifiers: [.command])
            Button("") { toggleClipBoundary() }
                .keyboardShortcut("k", modifiers: [.command])
            Button("") {
                workspaceViewModel.isPresentationMode.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("") {
                workspaceViewModel.isCompareMode.toggle()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            Button("") {
                if let selectedDrawingID {
                    removeDrawing(selectedDrawingID)
                }
            }
            .keyboardShortcut(.delete, modifiers: [.command])
        }
        .hidden()
    }

    private func importVideo() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]

        if panel.runModal() == .OK, let url = panel.urls.first {
            Task {
                await workspaceViewModel.createAnalysis(from: url, title: importTitle, store: dataStore)
                await loadActiveSession()
            }
        }
        #else
        isShowingFileImporter = true
        #endif
    }

    private func loadActiveSession() async {
        workspaceViewModel.bootstrap(with: dataStore)
        guard let session = activeSession else { return }

        do {
            _ = try await dataStore.loadAnalysisSession(session.id)
            let refreshedSession = dataStore.analysisSessions.first(where: { $0.id == session.id }) ?? session
            let playbackURL = try await dataStore.playbackURL(for: refreshedSession.videoAssetID)
            activePlaybackURL = playbackURL
            playerViewModel.load(url: playbackURL)
            syncDrawingsFromStore()
        } catch {
            workspaceViewModel.statusMessage = error.localizedDescription
        }
    }

    private func syncDrawingsFromStore() {
        liveDrawings = workspaceViewModel.drawings(in: dataStore)
        selectedDrawingID = nil
    }

    @MainActor
    private func applyPendingClipReferenceIfNeeded() async {
        guard let ref = appState.consumePendingAnalysisClipReference() else { return }

        let targetSessionID: UUID?
        if let local = ref.analysisSessionID {
            targetSessionID = local
        } else if !ref.backendAnalysisSessionID.isEmpty {
            targetSessionID = dataStore.analysisSessions
                .first(where: { $0.backendSessionID == ref.backendAnalysisSessionID })?
                .id
        } else {
            targetSessionID = nil
        }

        if let targetSessionID {
            workspaceViewModel.selectedSessionID = targetSessionID
            await loadActiveSession()
        }

        let localClipID: UUID?
        if let clipID = ref.clipID {
            localClipID = clipID
        } else if !ref.backendClipID.isEmpty {
            localClipID = dataStore.analysisClips.first(where: { $0.backendClipID == ref.backendClipID })?.id
        } else {
            localClipID = nil
        }

        if let localClipID,
           let clip = dataStore.analysisClips.first(where: { $0.id == localClipID }) {
            workspaceViewModel.selectedClipID = clip.id
            playerViewModel.seek(to: clip.startSeconds)
        } else {
            playerViewModel.seek(to: ref.timeStart)
        }
    }

    private func toggleClipBoundary() {
        if workspaceViewModel.clipStartTime == nil {
            workspaceViewModel.clipStartTime = playerViewModel.currentTime
            workspaceViewModel.statusMessage = "Clip-Start gesetzt"
            return
        }
        if clipName.isEmpty {
            clipName = "Clip \(format(workspaceViewModel.clipStartTime ?? 0))"
        }
        isShowingClipComposer = true
    }

    private func comparePair() -> (left: AnalysisClip, right: AnalysisClip, playbackURL: URL)? {
        let clips = activeClips
        guard !clips.isEmpty else { return nil }
        guard let playbackURL = activePlaybackURL else { return nil }

        let left = clips.first(where: { $0.id == workspaceViewModel.compareClipLeftID }) ?? clips[0]
        let right = clips.first(where: { $0.id == workspaceViewModel.compareClipRightID }) ?? clips[min(1, clips.count - 1)]
        return (left, right, playbackURL)
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func removeDrawing(_ drawingID: UUID) {
        drawingViewModel.invalidateCleanup(for: drawingID)
        liveDrawings.removeAll { $0.id == drawingID }
        if selectedDrawingID == drawingID {
            selectedDrawingID = nil
        }
        Task {
            await persistPersistentDrawings()
        }
    }

    private func removeAllDrawings() {
        for drawing in liveDrawings {
            drawingViewModel.invalidateCleanup(for: drawing.id)
        }
        liveDrawings.removeAll()
        selectedDrawingID = nil
        Task {
            await persistPersistentDrawings()
        }
    }

    private func persistPersistentDrawings() async {
        let persistent = liveDrawings.filter { !$0.isTemporary }
        await workspaceViewModel.applyDrawings(persistent, store: dataStore)
    }
}

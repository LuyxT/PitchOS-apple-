import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct MessengerModuleWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var workspaceViewModel = MessengerWorkspaceViewModel()
    @StateObject private var listViewModel = ChatListViewModel()
    @StateObject private var threadViewModel = ChatThreadViewModel()
    @StateObject private var composerViewModel = MessageComposerViewModel()

    @State private var showGroupCreator = false
    @State private var showMediaImporter = false

    private var visibleChats: [MessengerChat] {
        let base = listViewModel.includeArchived ? dataStore.messengerArchivedChats : dataStore.messengerChats
        return listViewModel.orderedChats(from: base)
    }

    private var activeChat: MessengerChat? {
        guard let selected = listViewModel.selectedChatID else { return nil }
        return (dataStore.messengerChats + dataStore.messengerArchivedChats).first(where: { $0.id == selected })
    }

    private var activeMessages: [MessengerMessage] {
        guard let chatID = activeChat?.id else { return [] }
        return dataStore.messengerMessagesByChat[chatID] ?? []
    }

    private var availableClips: [AnalysisClip] {
        dataStore.analysisClips.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        Group {
            #if os(macOS)
            macLayout
            #else
            mobileLayout
            #endif
        }
        .background(AppTheme.background)
        .environment(\.colorScheme, .light)
        .fileImporter(
            isPresented: $showMediaImporter,
            allowedContentTypes: [.image, .movie],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let file = urls.first else { return }
            composerViewModel.pendingAttachmentURL = file
            composerViewModel.pendingAttachmentName = file.lastPathComponent
            composerViewModel.selectedCloudFileID = nil
            composerViewModel.selectedCloudFileName = ""
        }
        .onAppear {
            Task {
                await workspaceViewModel.bootstrap(store: dataStore)
                listViewModel.ensureValidSelection(chats: visibleChats)
            }
        }
        .onChange(of: listViewModel.includeArchived) { _, _ in
            Task {
                await dataStore.loadChats(cursor: nil, includeArchived: listViewModel.includeArchived, query: listViewModel.searchQuery)
                listViewModel.nextCursor = dataStore.messengerChatNextCursor
                listViewModel.ensureValidSelection(chats: visibleChats)
            }
        }
        .onChange(of: listViewModel.searchQuery) { _, query in
            workspaceViewModel.scheduleSearch(query: query, includeArchived: listViewModel.includeArchived, store: dataStore)
            Task {
                await dataStore.loadChats(cursor: nil, includeArchived: listViewModel.includeArchived, query: query)
                listViewModel.nextCursor = dataStore.messengerChatNextCursor
                listViewModel.ensureValidSelection(chats: visibleChats)
            }
        }
        .onChange(of: listViewModel.selectedChatID) { _, chatID in
            guard let chatID else { return }
            Task {
                await dataStore.loadMessages(chatID: chatID, before: nil, limit: 50)
                threadViewModel.setNextCursor(dataStore.messengerMessageNextCursorByChat[chatID], for: chatID)
                await dataStore.markChatRead(chatID: chatID, messageID: activeMessages.last?.id)
            }
        }
        .onChange(of: dataStore.messengerConnectionState) { _, state in
            if case .connected = state {
                workspaceViewModel.resetReconnectBackoff()
            } else if case .failed = state {
                workspaceViewModel.scheduleRealtimeReconnect(store: dataStore)
            }
        }
    }

    #if os(macOS)
    private var macLayout: some View {
        VStack(spacing: 10) {
            headerBar
            HStack(spacing: 10) {
                MessengerChatListView(
                    chats: visibleChats,
                    selectedChatID: $listViewModel.selectedChatID,
                    searchQuery: $listViewModel.searchQuery,
                    includeArchived: $listViewModel.includeArchived,
                    hasMore: listViewModel.nextCursor != nil,
                    onLoadMore: {
                        Task {
                            await dataStore.loadChats(
                                cursor: listViewModel.nextCursor,
                                includeArchived: listViewModel.includeArchived,
                                query: listViewModel.searchQuery
                            )
                            listViewModel.nextCursor = dataStore.messengerChatNextCursor
                        }
                    },
                    onRefresh: {
                        Task {
                            await dataStore.loadChats(cursor: nil, includeArchived: listViewModel.includeArchived, query: listViewModel.searchQuery)
                            listViewModel.nextCursor = dataStore.messengerChatNextCursor
                        }
                    },
                    onTogglePin: { chat in
                        Task { await dataStore.pinChat(chat.id) }
                    },
                    onToggleMute: { chat in
                        Task { await dataStore.muteChat(chat.id) }
                    },
                    onToggleArchive: { chat in
                        Task { await dataStore.archiveChat(chat.id) }
                    }
                )
                .frame(width: 320)

                MessengerThreadView(
                    chat: activeChat,
                    messages: activeMessages,
                    hasMore: activeChat.map { dataStore.messengerMessageNextCursorByChat[$0.id] != nil } ?? false,
                    onLoadOlder: {
                        guard let chat = activeChat else { return }
                        Task {
                            await dataStore.loadMessages(
                                chatID: chat.id,
                                before: activeMessages.first?.createdAt,
                                limit: 50
                            )
                            threadViewModel.setNextCursor(dataStore.messengerMessageNextCursorByChat[chat.id], for: chat.id)
                        }
                    },
                    onOpenClip: { ref in
                        appState.openMessengerClipReference(ref)
                    },
                    onRetryMessage: { message in
                        Task {
                            await dataStore.retryMessage(localMessageID: message.id)
                        }
                    },
                    onDeleteMessage: { message in
                        Task {
                            await dataStore.deleteMessage(localMessageID: message.id, chatID: message.chatID)
                        }
                    },
                    onMarkRead: {
                        guard let chat = activeChat else { return }
                        Task {
                            await dataStore.markChatRead(chatID: chat.id, messageID: activeMessages.last?.id)
                        }
                    },
                    composer: AnyView(
                        MessengerComposerView(
                            composerViewModel: composerViewModel,
                            availableClips: availableClips,
                            onPickMedia: pickMedia,
                            onDropCloudFile: handleDroppedCloudFile,
                            onSend: sendComposerMessage
                        )
                    )
                )
                .frame(maxWidth: .infinity)

                MessengerChatInfoView(
                    chat: activeChat,
                    onChangePermission: { permission in
                        guard let chat = activeChat else { return }
                        Task { try? await dataStore.updateChatPermissions(chatID: chat.id, permission: permission) }
                    },
                    onToggleArchive: {
                        guard let chat = activeChat else { return }
                        Task { await dataStore.archiveChat(chat.id) }
                    }
                )
                .frame(width: 280)
            }

            if !listViewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MessengerSearchResultsView(
                    results: dataStore.messengerSearchResults,
                    onSelect: handleSearchSelection
                )
                .frame(maxHeight: 180)
            }
        }
        .padding(12)
    }
    #endif

    private var mobileLayout: some View {
        VStack(spacing: 10) {
            headerBar
            if horizontalSizeClass == .regular {
                HStack(spacing: 10) {
                    MessengerChatListView(
                        chats: visibleChats,
                        selectedChatID: $listViewModel.selectedChatID,
                        searchQuery: $listViewModel.searchQuery,
                        includeArchived: $listViewModel.includeArchived,
                        hasMore: listViewModel.nextCursor != nil,
                        onLoadMore: {
                            Task {
                                await dataStore.loadChats(cursor: listViewModel.nextCursor, includeArchived: listViewModel.includeArchived, query: listViewModel.searchQuery)
                                listViewModel.nextCursor = dataStore.messengerChatNextCursor
                            }
                        },
                        onRefresh: {
                            Task {
                                await dataStore.loadChats(cursor: nil, includeArchived: listViewModel.includeArchived, query: listViewModel.searchQuery)
                                listViewModel.nextCursor = dataStore.messengerChatNextCursor
                            }
                        },
                        onTogglePin: { chat in Task { await dataStore.pinChat(chat.id) } },
                        onToggleMute: { chat in Task { await dataStore.muteChat(chat.id) } },
                        onToggleArchive: { chat in Task { await dataStore.archiveChat(chat.id) } }
                    )
                    .frame(width: 280)

                    MessengerThreadView(
                        chat: activeChat,
                        messages: activeMessages,
                        hasMore: activeChat.map { dataStore.messengerMessageNextCursorByChat[$0.id] != nil } ?? false,
                        onLoadOlder: {
                            guard let chat = activeChat else { return }
                            Task {
                                await dataStore.loadMessages(chatID: chat.id, before: activeMessages.first?.createdAt, limit: 50)
                            }
                        },
                        onOpenClip: { ref in appState.openMessengerClipReference(ref) },
                        onRetryMessage: { message in Task { await dataStore.retryMessage(localMessageID: message.id) } },
                        onDeleteMessage: { message in Task { await dataStore.deleteMessage(localMessageID: message.id, chatID: message.chatID) } },
                        onMarkRead: {
                            guard let chat = activeChat else { return }
                            Task { await dataStore.markChatRead(chatID: chat.id, messageID: activeMessages.last?.id) }
                        },
                        composer: AnyView(
                            MessengerComposerView(
                                composerViewModel: composerViewModel,
                                availableClips: availableClips,
                                onPickMedia: { showMediaImporter = true },
                                onDropCloudFile: handleDroppedCloudFile,
                                onSend: sendComposerMessage
                            )
                        )
                    )
                }
            } else if activeChat != nil {
                MessengerThreadView(
                    chat: activeChat,
                    messages: activeMessages,
                    hasMore: activeChat.map { dataStore.messengerMessageNextCursorByChat[$0.id] != nil } ?? false,
                    onLoadOlder: {
                        guard let chat = activeChat else { return }
                        Task {
                            await dataStore.loadMessages(chatID: chat.id, before: activeMessages.first?.createdAt, limit: 50)
                        }
                    },
                    onOpenClip: { ref in appState.openMessengerClipReference(ref) },
                    onRetryMessage: { message in Task { await dataStore.retryMessage(localMessageID: message.id) } },
                    onDeleteMessage: { message in Task { await dataStore.deleteMessage(localMessageID: message.id, chatID: message.chatID) } },
                    onMarkRead: {
                        guard let chat = activeChat else { return }
                        Task { await dataStore.markChatRead(chatID: chat.id, messageID: activeMessages.last?.id) }
                    },
                    composer: AnyView(
                        MessengerComposerView(
                            composerViewModel: composerViewModel,
                            availableClips: availableClips,
                            onPickMedia: { showMediaImporter = true },
                            onDropCloudFile: handleDroppedCloudFile,
                            onSend: sendComposerMessage
                        )
                    )
                )
            } else {
                MessengerChatListView(
                    chats: visibleChats,
                    selectedChatID: $listViewModel.selectedChatID,
                    searchQuery: $listViewModel.searchQuery,
                    includeArchived: $listViewModel.includeArchived,
                    hasMore: listViewModel.nextCursor != nil,
                    onLoadMore: {
                        Task {
                            await dataStore.loadChats(cursor: listViewModel.nextCursor, includeArchived: listViewModel.includeArchived, query: listViewModel.searchQuery)
                            listViewModel.nextCursor = dataStore.messengerChatNextCursor
                        }
                    },
                    onRefresh: {
                        Task {
                            await dataStore.loadChats(cursor: nil, includeArchived: listViewModel.includeArchived, query: listViewModel.searchQuery)
                            listViewModel.nextCursor = dataStore.messengerChatNextCursor
                        }
                    },
                    onTogglePin: { chat in Task { await dataStore.pinChat(chat.id) } },
                    onToggleMute: { chat in Task { await dataStore.muteChat(chat.id) } },
                    onToggleArchive: { chat in Task { await dataStore.archiveChat(chat.id) } }
                )
            }
        }
        .padding(10)
    }

    private var headerBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                directChatMenu
                groupButton
                Spacer(minLength: 8)
                connectionText
            }

            HStack(spacing: 8) {
                directChatMenu
                Menu("Aktionen") {
                    Button("Neue Gruppe") {
                        showGroupCreator = true
                    }
                }
                .menuStyle(.borderlessButton)
                Spacer(minLength: 8)
                connectionText
            }
        }
    }

    private var directChatMenu: some View {
        Menu("Direktchat") {
            ForEach(dataStore.messengerUserDirectory.filter { $0.backendUserID != dataStore.messengerCurrentUser?.userID }) { participant in
                Button(participant.displayName) {
                    Task {
                        try? await dataStore.createDirectChat(participantID: participant.backendUserID)
                        listViewModel.ensureValidSelection(chats: visibleChats)
                    }
                }
            }
        }
        .buttonStyle(SecondaryActionButtonStyle())
    }

    private var groupButton: some View {
        Button("Gruppe") {
            showGroupCreator = true
        }
        .buttonStyle(SecondaryActionButtonStyle())
        .popover(isPresented: $showGroupCreator) {
            groupCreator
                .padding(12)
                .frame(width: 320)
        }
    }

    private var connectionText: some View {
        Text(connectionLabel)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var groupCreator: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Neue Gruppe")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            TextField("Name", text: $workspaceViewModel.composeGroupName)
                .textFieldStyle(.roundedBorder)
            Picker("Schreibrechte", selection: $workspaceViewModel.groupWritePermission) {
                Text("Nur Trainer").tag(MessengerChatPermission.trainerOnly)
                Text("Alle").tag(MessengerChatPermission.allMembers)
                Text("Benutzerdefiniert").tag(MessengerChatPermission.custom)
            }
            .pickerStyle(.menu)

            DatePicker(
                "Temporär bis",
                selection: Binding(
                    get: { workspaceViewModel.temporaryGroupEndDate ?? Date() },
                    set: { workspaceViewModel.temporaryGroupEndDate = $0 }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )

            Text("Teilnehmer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(dataStore.messengerUserDirectory.filter { $0.backendUserID != dataStore.messengerCurrentUser?.userID }) { user in
                        Toggle(
                            user.displayName,
                            isOn: Binding(
                                get: { workspaceViewModel.selectedParticipantUserIDs.contains(user.backendUserID) },
                                set: { selected in
                                    if selected {
                                        workspaceViewModel.selectedParticipantUserIDs.insert(user.backendUserID)
                                    } else {
                                        workspaceViewModel.selectedParticipantUserIDs.remove(user.backendUserID)
                                    }
                                }
                            )
                        )
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #else
                        .toggleStyle(.switch)
                        #endif
                    }
                }
            }
            .frame(maxHeight: 160)

            HStack {
                Spacer()
                Button("Erstellen") {
                    Task {
                        await workspaceViewModel.createGroup(store: dataStore)
                        if workspaceViewModel.errorMessage == nil {
                            showGroupCreator = false
                            listViewModel.ensureValidSelection(chats: visibleChats)
                        }
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }

            if let error = workspaceViewModel.errorMessage {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
    }

    private var connectionLabel: String {
        switch dataStore.messengerConnectionState {
        case .placeholder:
            return "Placeholder"
        case .disconnected:
            return "Offline"
        case .connecting:
            return "Verbinden"
        case .connected:
            return "Live"
        case .failed:
            return "Verbindungsfehler"
        }
    }

    private func sendComposerMessage() {
        guard let chatID = activeChat?.id else { return }
        guard composerViewModel.canSend else { return }
        composerViewModel.isSending = true
        Task {
            if let fileURL = composerViewModel.pendingAttachmentURL {
                await dataStore.sendMedia(
                    chatID: chatID,
                    fileURL: fileURL,
                    contextLabel: composerViewModel.trimmedContext.isEmpty ? nil : composerViewModel.trimmedContext
                )
            } else if let cloudFileID = composerViewModel.selectedCloudFileID {
                await dataStore.sendCloudFileReference(
                    chatID: chatID,
                    cloudFileID: cloudFileID,
                    contextLabel: composerViewModel.trimmedContext.isEmpty ? nil : composerViewModel.trimmedContext
                )
            } else if let clipID = composerViewModel.selectedClipID {
                await dataStore.shareAnalysisClipToChat(
                    chatID: chatID,
                    clipID: clipID,
                    contextLabel: composerViewModel.trimmedContext.isEmpty ? nil : composerViewModel.trimmedContext
                )
            } else {
                await dataStore.sendText(
                    chatID: chatID,
                    text: composerViewModel.trimmedText,
                    contextLabel: composerViewModel.trimmedContext.isEmpty ? nil : composerViewModel.trimmedContext
                )
            }
            await MainActor.run {
                composerViewModel.isSending = false
                composerViewModel.clearAfterSend()
            }
        }
    }

    private func handleSearchSelection(_ result: MessengerSearchResult) {
        if let chatID = result.chatID {
            listViewModel.selectedChatID = chatID
            Task {
                await dataStore.loadMessages(chatID: chatID, before: nil, limit: 50)
            }
            return
        }
        if result.type == .analysisClip,
           let clip = availableClips.first(where: { $0.name.caseInsensitiveCompare(result.title) == .orderedSame }),
           let session = dataStore.analysisSessions.first(where: { $0.id == clip.sessionID }),
           let video = dataStore.analysisVideoAssets.first(where: { $0.id == clip.videoAssetID }) {
            appState.openMessengerClipReference(
                MessengerClipReference(
                    backendClipID: clip.backendClipID ?? "",
                    backendAnalysisSessionID: session.backendSessionID ?? "",
                    backendVideoAssetID: video.backendVideoID ?? "",
                    clipID: clip.id,
                    analysisSessionID: clip.sessionID,
                    videoAssetID: clip.videoAssetID,
                    clipName: clip.name,
                    timeStart: clip.startSeconds,
                    timeEnd: clip.endSeconds,
                    matchID: session.matchID
                )
            )
        }
    }

    private func pickMedia() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .movie]
        if panel.runModal() == .OK, let picked = panel.urls.first {
            composerViewModel.pendingAttachmentURL = picked
            composerViewModel.pendingAttachmentName = picked.lastPathComponent
            composerViewModel.selectedCloudFileID = nil
            composerViewModel.selectedCloudFileName = ""
        }
        #else
        showMediaImporter = true
        #endif
    }

    private func handleDroppedCloudFile(_ fileID: UUID) {
        guard let file = dataStore.cloudFiles.first(where: { $0.id == fileID }) else { return }
        switch file.type {
        case .clip:
            if let clipID = file.linkedAnalysisClipID {
                composerViewModel.selectedClipID = clipID
            }
            composerViewModel.selectedCloudFileID = nil
            composerViewModel.selectedCloudFileName = ""
            composerViewModel.pendingAttachmentURL = nil
            composerViewModel.pendingAttachmentName = ""
        default:
            composerViewModel.selectedCloudFileID = file.id
            composerViewModel.selectedCloudFileName = file.name
            composerViewModel.pendingAttachmentURL = nil
            composerViewModel.pendingAttachmentName = ""
        }
    }
}

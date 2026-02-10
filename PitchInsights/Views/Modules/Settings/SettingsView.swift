import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var appState: AppState

    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var profileViewModel = ProfileSettingsViewModel()
    @StateObject private var displayViewModel = DisplaySettingsViewModel()
    @StateObject private var notificationViewModel = NotificationSettingsViewModel()
    @StateObject private var securityViewModel = SecuritySettingsViewModel()
    @StateObject private var appInfoViewModel = AppInfoSettingsViewModel()
    @StateObject private var feedbackViewModel = FeedbackSettingsViewModel()
    @StateObject private var accountViewModel = AccountSettingsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            sectionBar
            Divider()
            ScrollView {
                currentSectionView
                    .padding(12)
            }
            statusFooter
        }
        .background(AppTheme.background)
        .environment(\.colorScheme, .light)
        .task {
            await bootstrap()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Label("System-Einstellungen", systemImage: "gearshape")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)

            Spacer()

            if viewModel.isBootstrapping {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task {
                    await bootstrap()
                }
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
    }

    private var sectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SettingsSection.allCases) { section in
                    if viewModel.selectedSection == section {
                        Button(section.title) {
                            viewModel.selectedSection = section
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    } else {
                        Button(section.title) {
                            viewModel.selectedSection = section
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(AppTheme.surface)
    }

    @ViewBuilder
    private var currentSectionView: some View {
        switch viewModel.selectedSection {
        case .personalProfile:
            ProfileSettingsView(viewModel: profileViewModel)
        case .languageRegion, .displayBehavior:
            DisplaySettingsView(viewModel: displayViewModel, focus: viewModel.selectedSection)
        case .notifications:
            NotificationSettingsView(viewModel: notificationViewModel)
        case .securityPrivacy:
            SecuritySettingsView(viewModel: securityViewModel)
        case .appInfo:
            AppInfoSettingsView(viewModel: appInfoViewModel)
        case .feedbackSupport:
            FeedbackSettingsView(viewModel: feedbackViewModel, activeModuleID: appState.activeModule.id)
        case .account:
            AccountSettingsView(viewModel: accountViewModel)
        }
    }

    private var statusFooter: some View {
        HStack(spacing: 8) {
            Text(currentStatusMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(currentStatusIsError ? Color.red : AppTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private var currentStatusMessage: String {
        let candidates: [String?] = [
            viewModel.errorMessage,
            profileViewModel.errorMessage,
            displayViewModel.errorMessage,
            notificationViewModel.errorMessage,
            securityViewModel.errorMessage,
            feedbackViewModel.errorMessage,
            accountViewModel.errorMessage,
            dataStore.settingsLastErrorMessage,
            feedbackViewModel.statusMessage,
            accountViewModel.statusMessage,
            securityViewModel.statusMessage,
            notificationViewModel.statusMessage,
            displayViewModel.statusMessage,
            profileViewModel.statusMessage,
            appInfoViewModel.statusMessage,
            viewModel.statusMessage
        ]
        return candidates.compactMap { $0 }.first ?? ""
    }

    private var currentStatusIsError: Bool {
        [
            viewModel.errorMessage,
            profileViewModel.errorMessage,
            displayViewModel.errorMessage,
            notificationViewModel.errorMessage,
            securityViewModel.errorMessage,
            feedbackViewModel.errorMessage,
            accountViewModel.errorMessage,
            dataStore.settingsLastErrorMessage
        ]
        .contains { item in
            guard let item else { return false }
            return !item.isEmpty
        }
    }

    private func bootstrap() async {
        await viewModel.bootstrap(store: dataStore)
        profileViewModel.load(store: dataStore)
        displayViewModel.load(store: dataStore)
        notificationViewModel.load(store: dataStore)
        securityViewModel.load(store: dataStore)
        appInfoViewModel.load(store: dataStore)
        accountViewModel.load(store: dataStore)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .frame(width: 1120, height: 760)
}

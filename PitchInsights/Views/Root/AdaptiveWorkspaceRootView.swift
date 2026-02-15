import SwiftUI

struct AdaptiveWorkspaceRootView: View {
    private let profile = DeviceProfileDetector.current

    var body: some View {
        switch profile {
        case .macDesktop:
            MacRootView()
        case .ipadTablet:
            IPadRootView()
        case .iphoneMobile:
            PhoneRootView()
        }
    }
}

#Preview {
    AdaptiveWorkspaceRootView()
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
        .environmentObject(AppSessionStore())
}

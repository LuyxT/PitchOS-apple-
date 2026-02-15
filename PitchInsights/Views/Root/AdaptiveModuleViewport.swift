import SwiftUI

struct AdaptiveModuleViewport: View {
    let module: Module
    let profile: DeviceProfile

    private var definition: ModuleDefinition {
        ModuleRegistry.definition(for: module)
    }

    var body: some View {
        Group {
            switch profile {
            case .ipadTablet:
                ipadViewport
            case .iphoneMobile:
                phoneViewport
            case .macDesktop:
                ModuleRegistry.makeView(for: module)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .motionScopePulse(scope: module.motionScope)
            }
        }
        .background(AppTheme.background)
    }

    private var ipadViewport: some View {
        GeometryReader { proxy in
            let availableWidth = max(320, proxy.size.width - 16)
            let availableHeight = max(420, proxy.size.height - 16)
            let baseWidth = min(1120, max(980, definition.windowMinimumSize.width))
            let fitScale = min(1, availableWidth / baseWidth)
            let baseHeight = max(definition.windowMinimumSize.height, availableHeight / fitScale)
            let scaledHeight = baseHeight * fitScale

            ScrollView(.vertical) {
                ModuleRegistry.makeView(for: module)
                    .frame(width: baseWidth, height: baseHeight, alignment: .topLeading)
                    .scaleEffect(fitScale, anchor: .topLeading)
                    .frame(width: availableWidth, height: scaledHeight, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .motionScopePulse(scope: module.motionScope)
            }
            .scrollIndicators(.visible)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.easeInOut(duration: 0.18), value: fitScale)
        }
    }

    private var phoneViewport: some View {
        GeometryReader { proxy in
            let availableWidth = max(320, proxy.size.width - 12)
            let availableHeight = max(420, proxy.size.height)

            ScrollView(.vertical) {
                ModuleRegistry.makeView(for: module)
                    .frame(width: availableWidth, alignment: .topLeading)
                    .frame(minHeight: availableHeight, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 6)
                    .motionScopePulse(scope: module.motionScope)
            }
            .scrollIndicators(.visible)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

#Preview {
    AdaptiveModuleViewport(module: .kalender, profile: .ipadTablet)
        .environmentObject(AppState())
        .environmentObject(AppDataStore())
}

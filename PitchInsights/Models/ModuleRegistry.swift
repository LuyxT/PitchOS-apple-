import Foundation
import SwiftUI

struct ModuleDefinition: Identifiable {
    let module: Module
    let title: String
    let iconName: String
    let supportedProfiles: Set<DeviceProfile>
    let appearsInPhoneTabBar: Bool
    let windowMinimumSize: CGSize
    let windowPreferredSize: CGSize
    let makeView: () -> AnyView

    var id: Module { module }
}

enum ModuleRegistry {
    private static let allDefinitions: [ModuleDefinition] = [
        define(
            module: .trainerProfil,
            supportedProfiles: [.macDesktop, .ipadTablet, .iphoneMobile],
            appearsInPhoneTabBar: true,
            minSize: CGSize(width: 1120, height: 760),
            preferredSize: CGSize(width: 1260, height: 820)
        ),
        define(
            module: .kader,
            supportedProfiles: [.macDesktop, .ipadTablet, .iphoneMobile],
            appearsInPhoneTabBar: true,
            minSize: CGSize(width: 1080, height: 700),
            preferredSize: CGSize(width: 1240, height: 820)
        ),
        define(
            module: .kalender,
            supportedProfiles: [.macDesktop, .ipadTablet, .iphoneMobile],
            appearsInPhoneTabBar: true,
            minSize: CGSize(width: 980, height: 660),
            preferredSize: CGSize(width: 1200, height: 820)
        ),
        define(
            module: .trainingsplanung,
            supportedProfiles: [.macDesktop, .ipadTablet],
            appearsInPhoneTabBar: false,
            minSize: CGSize(width: 1220, height: 760),
            preferredSize: CGSize(width: 1420, height: 900)
        ),
        define(
            module: .spielanalyse,
            supportedProfiles: [.macDesktop, .ipadTablet],
            appearsInPhoneTabBar: false,
            minSize: CGSize(width: 1260, height: 780),
            preferredSize: CGSize(width: 1460, height: 920)
        ),
        define(
            module: .taktiktafel,
            supportedProfiles: [.macDesktop, .ipadTablet],
            appearsInPhoneTabBar: false,
            minSize: CGSize(width: 1180, height: 760),
            preferredSize: CGSize(width: 1380, height: 900)
        ),
        define(
            module: .messenger,
            supportedProfiles: [.macDesktop, .ipadTablet, .iphoneMobile],
            appearsInPhoneTabBar: true,
            minSize: CGSize(width: 1180, height: 740),
            preferredSize: CGSize(width: 1380, height: 900)
        ),
        define(
            module: .dateien,
            supportedProfiles: [.macDesktop, .ipadTablet],
            appearsInPhoneTabBar: false,
            minSize: CGSize(width: 1240, height: 760),
            preferredSize: CGSize(width: 1460, height: 920)
        ),
        define(
            module: .verwaltung,
            supportedProfiles: [.macDesktop, .ipadTablet],
            appearsInPhoneTabBar: false,
            minSize: CGSize(width: 1220, height: 760),
            preferredSize: CGSize(width: 1440, height: 900)
        ),
        define(
            module: .mannschaftskasse,
            supportedProfiles: [.macDesktop, .ipadTablet],
            appearsInPhoneTabBar: false,
            minSize: CGSize(width: 1220, height: 760),
            preferredSize: CGSize(width: 1440, height: 900)
        ),
        define(
            module: .einstellungen,
            supportedProfiles: [.macDesktop, .ipadTablet],
            appearsInPhoneTabBar: false,
            minSize: CGSize(width: 1120, height: 760),
            preferredSize: CGSize(width: 1320, height: 860)
        )
    ]

    static let allModules: [Module] = allDefinitions.map(\.module)

    static let enabledModules: [Module] = {
        let available = Set(allModules)
        guard
            let raw = ProcessInfo.processInfo.environment["ENABLED_MODULES"],
            !raw.isEmpty
        else {
            return allModules
        }

        let requested = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { Module(rawValue: $0) }
            .filter { available.contains($0) }

        return requested.isEmpty ? allModules : requested
    }()

    static let phoneTabOrder: [Module] = [.kalender, .messenger, .trainerProfil, .kader]

    static func isEnabled(_ module: Module) -> Bool {
        enabledModules.contains(module)
    }

    static func definition(for module: Module) -> ModuleDefinition {
        allDefinitions.first(where: { $0.module == module }) ?? fallbackDefinition(for: module)
    }

    static func modules(for profile: DeviceProfile) -> [Module] {
        enabledModules.filter { definition(for: $0).supportedProfiles.contains(profile) }
    }

    static func phoneTabModules() -> [Module] {
        let available = Set(modules(for: .iphoneMobile))
        return phoneTabOrder.filter { available.contains($0) }
    }

    static func makeView(for module: Module) -> AnyView {
        definition(for: module).makeView()
    }

    private static func define(
        module: Module,
        supportedProfiles: Set<DeviceProfile>,
        appearsInPhoneTabBar: Bool,
        minSize: CGSize,
        preferredSize: CGSize
    ) -> ModuleDefinition {
        ModuleDefinition(
            module: module,
            title: module.title,
            iconName: module.iconName,
            supportedProfiles: supportedProfiles,
            appearsInPhoneTabBar: appearsInPhoneTabBar,
            windowMinimumSize: minSize,
            windowPreferredSize: preferredSize,
            makeView: { AnyView(WorkspaceSwitchView(module: module)) }
        )
    }

    private static func fallbackDefinition(for module: Module) -> ModuleDefinition {
        ModuleDefinition(
            module: module,
            title: module.title,
            iconName: module.iconName,
            supportedProfiles: [.macDesktop, .ipadTablet],
            appearsInPhoneTabBar: false,
            windowMinimumSize: CGSize(width: 1120, height: 760),
            windowPreferredSize: CGSize(width: 1320, height: 860),
            makeView: { AnyView(WorkspaceSwitchView(module: module)) }
        )
    }
}

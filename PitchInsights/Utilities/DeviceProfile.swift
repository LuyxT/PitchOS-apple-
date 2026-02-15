import SwiftUI

#if os(iOS)
import UIKit
#endif

enum DeviceProfile: Hashable {
    case macDesktop
    case ipadTablet
    case iphoneMobile
}

enum DeviceProfileDetector {
    static var current: DeviceProfile {
        #if os(macOS)
        return .macDesktop
        #elseif os(iOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return .ipadTablet
        case .phone:
            return .iphoneMobile
        default:
            return .ipadTablet
        }
        #else
        return .macDesktop
        #endif
    }
}

import SwiftUI

enum AppTheme {
    static let primary = Color(red: 0.0627, green: 0.7255, blue: 0.5059) // #10b981
    static let primaryDark = Color(red: 0.0196, green: 0.6, blue: 0.4118) // #059669

    static let background = Color(red: 0.9608, green: 0.9608, blue: 0.9686) // #f5f5f7
    static let surface = Color.white
    static let surfaceAlt = Color(red: 0.93, green: 0.93, blue: 0.95)
    static let border = Color(red: 0.898, green: 0.898, blue: 0.918) // #e5e5ea
    static let textPrimary = Color(red: 0.1137, green: 0.1137, blue: 0.1216) // #1d1d1f
    static let textSecondary = Color.black.opacity(0.6)

    static let dockBackground = Color.white.opacity(0.78)
    static let dockBorder = Color.black.opacity(0.08)
    static let hover = primary.opacity(0.12)
    static let shadow = Color.black.opacity(0.18)
}

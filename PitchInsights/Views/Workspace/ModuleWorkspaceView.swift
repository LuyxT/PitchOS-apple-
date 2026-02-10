import SwiftUI

struct ModuleWorkspaceView: View {
    let module: Module
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Text(module.title)
                .font(.system(size: 24, weight: .semibold))
            Text(subtitle)
                .foregroundStyle(AppTheme.textSecondary)
                .font(.system(size: 13))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ModuleWorkspaceView(module: .trainerProfil, subtitle: "Platzhalter")
        .frame(width: 800, height: 500)
}

import SwiftUI

extension View {
    @ViewBuilder
    func adminCheckboxStyle() -> some View {
        #if os(macOS)
        self.toggleStyle(.checkbox)
        #else
        self
        #endif
    }
}


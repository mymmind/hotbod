import SwiftUI

enum ForgeElevationLevel {
    case none
    case tabBar
    case accentButton
    case metricTile(Color)
}

extension View {
    @ViewBuilder
    func forgeElevation(_ level: ForgeElevationLevel) -> some View {
        switch level {
        case .none:
            self
        case .tabBar:
            shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        case .accentButton:
            shadow(color: ForgeColors.accent.opacity(0.35), radius: 12, y: 6)
        case .metricTile(let accent):
            shadow(color: accent.opacity(0.08), radius: 16, y: 6)
        }
    }

    func forgeMinTapTarget() -> some View {
        frame(minWidth: ForgeTarget.min, minHeight: ForgeTarget.min)
            .contentShape(Rectangle())
    }
}

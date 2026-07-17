import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum ForgeColors {
    // MARK: - Semantic (preferred) — dark-only

    static let backgroundPrimary = color(0x121212)
    static let surface = color(0x1C1C1E)
    static let surfaceInverse = color(0xF2F2F7)

    static let textPrimary = color(0xFFFFFF)
    static let textSecondary = color(0x8E8E93)
    static let textOnInverse = color(0xFFFFFF)

    static let borderSubtle = Color.white.opacity(0.20)

    static let accent = color(0xFF5247)
    static let accentHot = color(0xFF4D8A)
    static let accentBlue = color(0x4D8BF7)
    static let accentGreen = color(0x34C759)
    static let accentAmber = color(0xFFB340)
    static let destructive = color(0xFF453A)

    // MARK: - Legacy aliases (migrate to semantic names over time)

    static let background = backgroundPrimary
    static let foreground = textPrimary
    static let muted = textSecondary

    static var border: Color { borderSubtle }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentHot, accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var focusGradient: LinearGradient {
        LinearGradient(
            colors: [accentAmber, accentHot],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func readiness(_ percentage: Double) -> Color {
        if percentage >= 70 { return accentGreen }
        if percentage >= 50 { return accentAmber }
        return accent
    }

    // MARK: - Private

    private static func color(_ hex: UInt32) -> Color {
#if canImport(UIKit)
        Color(uiColor: UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        ))
#else
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
#endif
    }
}

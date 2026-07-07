import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum ForgeColors {
    // MARK: - Semantic (preferred)

    static let backgroundPrimary = adaptive(hexLight: 0xFFFFFF, hexDark: 0x121212)
    static let surface = adaptive(hexLight: 0xFFFFFF, hexDark: 0x1C1C1E)
    static let surfaceElevated = adaptive(hexLight: 0xFFFFFF, hexDark: 0x2C2C2E)
    static let surfaceInverse = adaptive(hexLight: 0x000000, hexDark: 0xF2F2F7)

    static let textPrimary = adaptive(hexLight: 0x000000, hexDark: 0xFFFFFF)
    static let textSecondary = adaptive(hexLight: 0x8E8E93, hexDark: 0x8E8E93)
    static let textOnInverse = adaptive(hexLight: 0xFFFFFF, hexDark: 0xFFFFFF)

    static let borderSubtle = adaptive(
        light: Color.black.opacity(0.15),
        dark: Color.white.opacity(0.20)
    )

    static let accent = adaptive(hexLight: 0xFF3D2E, hexDark: 0xFF5247)
    static let accentHot = adaptive(hexLight: 0xFF2E7A, hexDark: 0xFF4D8A)
    static let accentBlue = adaptive(hexLight: 0x2663EB, hexDark: 0x4D8BF7)
    static let accentGreen = adaptive(hexLight: 0x00B86B, hexDark: 0x34C759)
    static let accentAmber = adaptive(hexLight: 0xFF9E00, hexDark: 0xFFB340)
    static let destructive = adaptive(hexLight: 0xDB2626, hexDark: 0xFF453A)
    static let success = accentGreen

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

    private static func adaptive(hexLight: UInt32, hexDark: UInt32) -> Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? uiColor(hexDark) : uiColor(hexLight)
        })
#else
        Color(hex: hexLight)
#endif
    }

    private static func adaptive(light: Color, dark: Color) -> Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
#else
        light
#endif
    }

#if canImport(UIKit)
    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
#endif
}

#if !canImport(UIKit)
private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
#endif

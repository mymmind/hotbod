import SwiftUI

enum ForgeRadius {
    static let none: CGFloat = 0
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let pill: CGFloat = 32
    static let full: CGFloat = 999

    static let brutalist = none
    static let soft = lg
}

extension RoundedRectangle {
    static func forge(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

import SwiftUI

enum ForgeTypography {
    // Canonical type ramp (Dynamic Type)
    static let hero = Font.system(.largeTitle, design: .serif).weight(.black)
    static let display = Font.system(.title, design: .default).weight(.heavy).italic()
    static let title = Font.system(.title2, design: .default).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let label = Font.system(.caption, design: .default).weight(.medium)
    static let cta = Font.system(.caption, design: .default).weight(.bold).italic()
    static let metric = Font.system(.title3, design: .monospaced).weight(.bold)
    static let metricHero = Font.system(.largeTitle, design: .monospaced).weight(.bold)
    static let sessionTitle = Font.system(.title2, design: .default).weight(.heavy).italic()
    static let tabLabel = Font.system(.caption2, design: .default).weight(.medium)

    // Legacy aliases
    static let largeTitle = hero
    static let displayTitle = Font.system(.title, design: .serif).weight(.black)
    static let displayAthletic = display
    static let heading = title
    static let caption = label
    static let ctaLabel = cta
    static let monoMetric = metric
    static let heroMetric = metricHero
}

extension Font {
    static func forgeTabLabel(selected: Bool) -> Font {
        Font.system(.caption2, design: .default).weight(selected ? .semibold : .medium)
    }

    static func forgeTabIcon(selected: Bool) -> Font {
        Font.system(size: ForgeIcons.tab, weight: selected ? .semibold : .regular)
    }
}

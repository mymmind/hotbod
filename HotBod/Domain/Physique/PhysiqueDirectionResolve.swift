import Foundation

enum PhysiqueDirectionResolve {
    static func resolved(
        matches: [PhysiqueArchetypeMatch],
        catalog: [String: PhysiqueArchetypeCatalogEntry]
    ) -> [(match: PhysiqueArchetypeMatch, entry: PhysiqueArchetypeCatalogEntry)] {
        matches.compactMap { match in
            guard let entry = catalog[match.archetypeId] else { return nil }
            return (match: match, entry: entry)
        }
    }
}

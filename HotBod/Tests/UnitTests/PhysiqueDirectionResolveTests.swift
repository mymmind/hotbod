import XCTest
@testable import HotBod

final class PhysiqueDirectionResolveTests: XCTestCase {
    func testResolvedOmitsUnknownArchetypeIds() {
        let catalog: [String: PhysiqueArchetypeCatalogEntry] = [
            "classic_athletic": PhysiqueArchetypeCatalogEntry(
                id: "classic_athletic",
                genericLabel: "Classic athletic",
                referenceLabel: nil,
                tags: [],
                similarityHints: []
            ),
        ]
        let matches = [
            PhysiqueArchetypeMatch(
                archetypeId: "not_in_catalog",
                rank: 1,
                similarityDimension: "Lean silhouette",
                confidence: .medium
            ),
        ]

        XCTAssertTrue(PhysiqueDirectionResolve.resolved(matches: matches, catalog: catalog).isEmpty)
    }

    func testResolvedPairsKnownMatchesWithCatalogEntries() {
        let entry = PhysiqueArchetypeCatalogEntry(
            id: "classic_athletic",
            genericLabel: "Classic athletic",
            referenceLabel: nil,
            tags: [],
            similarityHints: []
        )
        let match = PhysiqueArchetypeMatch(
            archetypeId: "classic_athletic",
            rank: 1,
            similarityDimension: "Lean silhouette",
            confidence: .high
        )

        let resolved = PhysiqueDirectionResolve.resolved(
            matches: [match],
            catalog: ["classic_athletic": entry]
        )

        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved[0].match, match)
        XCTAssertEqual(resolved[0].entry, entry)
    }
}

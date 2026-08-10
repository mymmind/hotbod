import XCTest
@testable import HotBod

final class PhysiqueDirectionCopyTests: XCTestCase {
    func testReferenceLinePrefixesReferenceLabel() {
        let entry = PhysiqueArchetypeCatalogEntry(
            id: "classic_athletic",
            genericLabel: "Classic athletic",
            referenceLabel: "Brad Pitt — Fight Club era",
            tags: ["lean"],
            similarityHints: ["Lean silhouette"]
        )
        XCTAssertEqual(
            PhysiqueDirectionCopy.referenceLine(for: entry),
            "Reference: Brad Pitt — Fight Club era"
        )
        var genericOnly = entry
        genericOnly.referenceLabel = nil
        XCTAssertNil(PhysiqueDirectionCopy.referenceLine(for: genericOnly))
    }
}

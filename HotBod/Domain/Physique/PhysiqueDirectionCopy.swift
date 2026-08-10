import Foundation

enum PhysiqueDirectionCopy {
    static func referenceLine(for entry: PhysiqueArchetypeCatalogEntry) -> String? {
        entry.referenceLabel.map { "Reference: \($0)" }
    }
}

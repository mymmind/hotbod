import Foundation

struct PhysiqueArchetypeCatalogEntry: Codable, Hashable, Identifiable {
    var id: String
    var genericLabel: String
    var referenceLabel: String?
    var tags: [String]
    var similarityHints: [String]
}

struct PhysiqueArchetypeMatch: Codable, Hashable {
    var archetypeId: String
    var rank: Int
    var similarityDimension: String
    var confidence: PhysiqueObservationConfidence
}

import Foundation

struct PhysiquePhotoQuality: Codable, Hashable {
    var anglesAvailable: [String]
    var lightingQuality: String
    var overallConfidence: Double
}

struct PhysiqueBuildSummary: Codable, Hashable {
    var overallArchetype: String
    var frameSize: String
    var shoulderToWaist: String
    var waist: String
    var torso: String
    var muscularity: String
    var leanness: String
}

struct PhysiqueMuscleEntry: Codable, Hashable {
    var muscle: PhysiqueFocusMuscle
    var current: String
    var priorityRank: Int?
    var notes: String
    var confidence: PhysiqueObservationConfidence
}

struct PhysiqueDevelopmentPriority: Codable, Hashable {
    var muscle: PhysiqueFocusMuscle
    var reason: String
}

struct PhysiqueTrainingBias: Codable, Hashable {
    var preferredMuscleGroups: [MuscleGroup]
    var rationale: String
}

struct PhysiqueConfidenceBands: Codable, Hashable {
    var high: [String]
    var medium: [String]
    var low: [String]
}

struct PhysiqueAssessment: Identifiable, Hashable {
    let id: UUID
    var createdAt: Date
    var frontPhotoId: UUID
    var backPhotoId: UUID
    var sidePhotoId: UUID?
    var photoQuality: PhysiquePhotoQuality
    var physique: PhysiqueBuildSummary
    var muscleEntries: [PhysiqueMuscleEntry]
    var developmentPriorities: [PhysiqueDevelopmentPriority]
    var trainingBias: PhysiqueTrainingBias
    var limitations: [String]
    var confidenceBands: PhysiqueConfidenceBands
    var source: PhysiqueAssessmentSource
    var whyTodaySummary: String
    var physiqueDirections: [PhysiqueArchetypeMatch]
    var trendAdaptation: PhysiqueTrendAdaptation?

    init(
        id: UUID,
        createdAt: Date,
        frontPhotoId: UUID,
        backPhotoId: UUID,
        sidePhotoId: UUID?,
        photoQuality: PhysiquePhotoQuality,
        physique: PhysiqueBuildSummary,
        muscleEntries: [PhysiqueMuscleEntry],
        developmentPriorities: [PhysiqueDevelopmentPriority],
        trainingBias: PhysiqueTrainingBias,
        limitations: [String],
        confidenceBands: PhysiqueConfidenceBands,
        source: PhysiqueAssessmentSource,
        whyTodaySummary: String,
        physiqueDirections: [PhysiqueArchetypeMatch] = [],
        trendAdaptation: PhysiqueTrendAdaptation? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.frontPhotoId = frontPhotoId
        self.backPhotoId = backPhotoId
        self.sidePhotoId = sidePhotoId
        self.photoQuality = photoQuality
        self.physique = physique
        self.muscleEntries = muscleEntries
        self.developmentPriorities = developmentPriorities
        self.trainingBias = trainingBias
        self.limitations = limitations
        self.confidenceBands = confidenceBands
        self.source = source
        self.whyTodaySummary = whyTodaySummary
        self.physiqueDirections = physiqueDirections
        self.trendAdaptation = trendAdaptation
    }
}

extension PhysiqueAssessment: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case frontPhotoId
        case backPhotoId
        case sidePhotoId
        case photoQuality
        case physique
        case muscleEntries
        case developmentPriorities
        case trainingBias
        case limitations
        case confidenceBands
        case source
        case whyTodaySummary
        case physiqueDirections
        case trendAdaptation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        frontPhotoId = try container.decode(UUID.self, forKey: .frontPhotoId)
        backPhotoId = try container.decode(UUID.self, forKey: .backPhotoId)
        sidePhotoId = try container.decodeIfPresent(UUID.self, forKey: .sidePhotoId)
        photoQuality = try container.decode(PhysiquePhotoQuality.self, forKey: .photoQuality)
        physique = try container.decode(PhysiqueBuildSummary.self, forKey: .physique)
        muscleEntries = try container.decode([PhysiqueMuscleEntry].self, forKey: .muscleEntries)
        developmentPriorities = try container.decode(
            [PhysiqueDevelopmentPriority].self,
            forKey: .developmentPriorities
        )
        trainingBias = try container.decode(PhysiqueTrainingBias.self, forKey: .trainingBias)
        limitations = try container.decode([String].self, forKey: .limitations)
        confidenceBands = try container.decode(PhysiqueConfidenceBands.self, forKey: .confidenceBands)
        source = try container.decode(PhysiqueAssessmentSource.self, forKey: .source)
        whyTodaySummary = try container.decode(String.self, forKey: .whyTodaySummary)
        physiqueDirections = try container.decodeIfPresent(
            [PhysiqueArchetypeMatch].self,
            forKey: .physiqueDirections
        ) ?? []
        trendAdaptation = try container.decodeIfPresent(
            PhysiqueTrendAdaptation.self,
            forKey: .trendAdaptation
        )
    }
}

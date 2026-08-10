import Foundation

actor LocalPhysiqueAssessmentRepository: PhysiqueAssessmentRepository {
    static let maxHistoryCount = 12
    private let historyKey: String
    private let legacyKey: String

    init(
        historyKey: String = "physique_assessments.json",
        legacyKey: String = "physique_assessment.json"
    ) {
        self.historyKey = historyKey
        self.legacyKey = legacyKey
    }

    func fetchActive() async throws -> PhysiqueAssessment? {
        try await fetchHistory().first
    }

    func fetchHistory() async throws -> [PhysiqueAssessment] {
        try migrateLegacyIfNeeded()
        return loadDocument().assessments
    }

    func fetch(id: UUID) async throws -> PhysiqueAssessment? {
        try await fetchHistory().first { $0.id == id }
    }

    func saveActive(_ assessment: PhysiqueAssessment) async throws {
        try migrateLegacyIfNeeded()
        var assessments = loadDocument().assessments
        assessments.removeAll { $0.id == assessment.id }
        assessments.insert(assessment, at: 0)
        if assessments.count > Self.maxHistoryCount {
            assessments = Array(assessments.prefix(Self.maxHistoryCount))
        }
        PersistenceHelper.save(
            PhysiqueAssessmentHistoryDocument(assessments: assessments),
            to: historyKey
        )
        PersistenceHelper.remove(legacyKey)
    }

    func clearActive() async throws { try await clearAll() }

    func clearAll() async throws {
        PersistenceHelper.remove(historyKey)
        PersistenceHelper.remove(legacyKey)
    }

    private func loadDocument() -> PhysiqueAssessmentHistoryDocument {
        PersistenceHelper.load(PhysiqueAssessmentHistoryDocument.self, from: historyKey)
            ?? PhysiqueAssessmentHistoryDocument(assessments: [])
    }

    private func migrateLegacyIfNeeded() throws {
        let existing = PersistenceHelper.load(
            PhysiqueAssessmentHistoryDocument.self,
            from: historyKey
        )
        if let existing, !existing.assessments.isEmpty { return }
        guard let legacy = PersistenceHelper.load(PhysiqueAssessment.self, from: legacyKey) else {
            return
        }
        PersistenceHelper.save(
            PhysiqueAssessmentHistoryDocument(assessments: [legacy]),
            to: historyKey
        )
        PersistenceHelper.remove(legacyKey)
    }
}

import Foundation

actor LocalPhysiqueAssessmentRepository: PhysiqueAssessmentRepository {
    private let key: String

    init(key: String = "physique_assessment.json") {
        self.key = key
    }

    func fetchActive() async throws -> PhysiqueAssessment? {
        PersistenceHelper.load(PhysiqueAssessment.self, from: key)
    }

    func saveActive(_ assessment: PhysiqueAssessment) async throws {
        PersistenceHelper.save(assessment, to: key)
    }

    func clearActive() async throws {
        PersistenceHelper.remove(key)
    }
}

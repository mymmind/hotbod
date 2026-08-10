import Foundation

struct UnavailablePhysiqueAssessmentService: PhysiqueAssessmentServing, Sendable {
    func assess(_ request: PhysiqueAssessmentRequest) async throws -> PhysiqueAssessment {
        throw URLError(.notConnectedToInternet)
    }
}

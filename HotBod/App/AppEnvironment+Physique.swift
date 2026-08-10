import Foundation

extension AppEnvironment {
    func loadActivePhysiqueAssessment() async {
        activePhysiqueAssessment = try? await physiqueAssessmentRepository.fetchActive()
    }

    func saveActivePhysiqueAssessment(_ assessment: PhysiqueAssessment) async {
        try? await physiqueAssessmentRepository.saveActive(assessment)
        activePhysiqueAssessment = assessment
    }
}

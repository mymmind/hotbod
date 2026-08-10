import Foundation

enum PhysiqueAssessPipeline {
    static func applyTrendAdaptation(
        assessment: PhysiqueAssessment,
        previous: PhysiqueAssessment?,
        photos: [BodyProgressPhoto]
    ) -> PhysiqueAssessment {
        guard let previous else { return assessment }
        let previousRatio = photos.first { $0.id == previous.frontPhotoId }?.analysis?.shoulderWaistRatio
        let currentRatio = photos.first { $0.id == assessment.frontPhotoId }?.analysis?.shoulderWaistRatio
        let diff = PhysiqueAssessmentDiffEngine.diff(
            previous: previous,
            current: assessment,
            previousFrontRatio: previousRatio,
            currentFrontRatio: currentRatio
        )
        return PhysiqueTrendBiasAdapter.adapt(
            current: assessment,
            previous: previous,
            diff: diff
        ).assessment
    }
}

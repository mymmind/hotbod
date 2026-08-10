import Foundation

extension AppEnvironment {
    func loadActivePhysiqueAssessment() async {
        activePhysiqueAssessment = try? await physiqueAssessmentRepository.fetchActive()
    }

    func saveActivePhysiqueAssessment(_ assessment: PhysiqueAssessment) async {
        try? await physiqueAssessmentRepository.saveActive(assessment)
        activePhysiqueAssessment = assessment
    }

    func assessPhysique(photos: [BodyProgressPhoto]? = nil) async -> PhysiqueAssessment? {
        guard hasCompletedOnboarding, let profile = userProfile else {
            physiqueStatusMessage = nil
            return nil
        }

        let photoList: [BodyProgressPhoto]
        if let photos {
            photoList = photos
        } else {
            photoList = await fetchBodyPhotos()
        }

        do {
            let assessment = try await physiqueAssessmentService.assess(
                photos: photoList,
                profile: profile
            )
            await saveActivePhysiqueAssessment(assessment)
            physiqueStatusMessage = assessment.source == .onDevice
                ? "Using on-device estimate."
                : nil
            return assessment
        } catch let error as PhysiqueAssessmentError {
            physiqueStatusMessage = physiqueStatusMessage(for: error)
            return nil
        } catch {
            physiqueStatusMessage = nil
            return nil
        }
    }

    func hasStalePhysiquePhotos(photos: [BodyProgressPhoto]? = nil) async -> Bool {
        guard let active = activePhysiqueAssessment else { return false }
        let photoList: [BodyProgressPhoto]
        if let photos {
            photoList = photos
        } else {
            photoList = await fetchBodyPhotos()
        }
        return PhysiquePhotoGate.isStale(active: active, photos: photoList)
    }

    private func physiqueStatusMessage(for error: PhysiqueAssessmentError) -> String {
        switch error {
        case .missingAngles(let angles):
            if angles == [.back] {
                return "Add a back photo to unlock a full assessment."
            }
            if angles.contains(.front), angles.contains(.back) {
                return "Add front and back photos to get a focus plan."
            }
            if angles.contains(.front) {
                return "Add a front photo to unlock assessment."
            }
            return "Add front and back photos to get a focus plan."
        case .qualityFailed(let failures):
            if let first = failures.first {
                return "\(first.0.rawValue.capitalized) photo: \(first.1)"
            }
            return "Photo quality too low for assessment."
        case .notOnboarded:
            return "Complete onboarding to run a physique assessment."
        }
    }
}

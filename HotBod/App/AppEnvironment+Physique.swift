import Foundation

extension AppEnvironment {
    func loadActivePhysiqueAssessment() async {
        let history = (try? await physiqueAssessmentRepository.fetchHistory()) ?? []
        physiqueAssessmentHistory = history
        activePhysiqueAssessment = history.first
    }

    func saveActivePhysiqueAssessment(_ assessment: PhysiqueAssessment) async {
        try? await physiqueAssessmentRepository.saveActive(assessment)
        await loadActivePhysiqueAssessment()
        await reschedulePhysiqueReassessReminder()
    }

    func sinceLastPhysiqueDiff(photos: [BodyProgressPhoto]) -> PhysiqueAssessmentDiff? {
        guard physiqueAssessmentHistory.count >= 2 else { return nil }
        let current = physiqueAssessmentHistory[0]
        let previous = physiqueAssessmentHistory[1]
        let currentRatio = photos.first { $0.id == current.frontPhotoId }?.analysis?.shoulderWaistRatio
        let previousRatio = photos.first { $0.id == previous.frontPhotoId }?.analysis?.shoulderWaistRatio
        return PhysiqueAssessmentDiffEngine.diff(
            previous: previous,
            current: current,
            previousFrontRatio: previousRatio,
            currentFrontRatio: currentRatio
        )
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
            let previous = try? await physiqueAssessmentRepository.fetchActive()
            var assessment = try await physiqueAssessmentService.assess(
                photos: photoList,
                profile: profile
            )
            assessment = PhysiqueAssessPipeline.applyTrendAdaptation(
                assessment: assessment,
                previous: previous,
                photos: photoList
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
        case .missingAngles:
            return "Add a front photo to get a focus plan."
        case .qualityFailed(let failures):
            if let first = failures.first {
                return "\(first.0.rawValue.capitalized) photo: \(first.1)"
            }
            return "Photo quality too low for assessment."
        case .notOnboarded:
            return "Complete onboarding to run a physique assessment."
        }
    }

    func loadPhysiqueIllustration(for assessmentId: UUID) async {
        do {
            if let (record, data) = try await physiqueIllustrationStore.fetch(assessmentId: assessmentId) {
                physiqueIllustration = record
                physiqueIllustrationImageData = data
            } else if physiqueIllustration?.assessmentId != assessmentId {
                physiqueIllustration = nil
                physiqueIllustrationImageData = nil
            }
        } catch {
            if physiqueIllustration?.assessmentId != assessmentId {
                physiqueIllustration = nil
                physiqueIllustrationImageData = nil
            }
        }
    }

    func generatePhysiqueIllustration(
        assessment: PhysiqueAssessment,
        photos: [BodyProgressPhoto]
    ) async {
        guard hasCompletedOnboarding, userProfile != nil else {
            physiqueIllustrationStatus = nil
            return
        }

        var photoList = photos
        if photoList.first(where: { $0.id == assessment.frontPhotoId }) == nil {
            photoList = await fetchBodyPhotos()
        }

        guard let frontPhoto = photoList.first(where: { $0.id == assessment.frontPhotoId }),
              BodyPhotoImageProcessor.fileExists(at: frontPhoto.localImagePath),
              let uiImage = BodyPhotoImageProcessor.loadUIImage(at: frontPhoto.localImagePath),
              let uploadData = PhysiqueIllustrationImageCodec.jpegDataForUpload(from: uiImage) else {
            physiqueIllustrationStatus = "Illustration unavailable."
            return
        }

        let hints = PhysiqueIllustrationHintsBuilder.make(from: assessment)
        isGeneratingPhysiqueIllustration = true
        physiqueIllustrationStatus = nil

        defer { isGeneratingPhysiqueIllustration = false }

        do {
            let imageData = try await physiqueIllustrationService.generate(
                assessmentId: assessment.id,
                hints: hints,
                imageData: uploadData
            )
            let record = try await physiqueIllustrationStore.save(
                assessmentId: assessment.id,
                sourcePhotoId: frontPhoto.id,
                imageData: imageData
            )
            physiqueIllustration = record
            physiqueIllustrationImageData = imageData
            physiqueIllustrationStatus = nil
        } catch let error as PhysiqueIllustrationError {
            physiqueIllustrationStatus = physiqueIllustrationStatusMessage(for: error)
        } catch {
            physiqueIllustrationStatus = "Illustration unavailable."
        }
    }

    func physiqueIllustrationStatusMessage(for error: PhysiqueIllustrationError) -> String {
        switch error {
        case .notConfigured:
            return "Illustration unavailable."
        case .unavailable, .invalidResponse:
            return "Illustration unavailable."
        case .serverMessage(let message):
            return sanitizedIllustrationServerMessage(message)
        }
    }

    private func sanitizedIllustrationServerMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Illustration unavailable." }

        let lower = trimmed.lowercased()
        let infraSubstrings = ["openai", "api_key", "not configured", "internal server"]
        if infraSubstrings.contains(where: { lower.contains($0) }) {
            return "Illustration unavailable."
        }
        if trimmed.count > 200 || trimmed.localizedCaseInsensitiveContains("base64") {
            return "Illustration unavailable."
        }
        return trimmed
    }

    func physiqueSplitSuggestion(
        for assessment: PhysiqueAssessment,
        profile: UserProfile
    ) -> PhysiqueSplitSuggestion? {
        PhysiqueSplitSuggestionEvaluator.evaluate(
            assessmentId: assessment.id,
            currentSplit: profile.preferredSplit,
            daysPerWeek: profile.trainingDaysPerWeek,
            preferredMuscleGroups: assessment.trainingBias.preferredMuscleGroups,
            avoidedMuscleGroups: profile.avoidedMuscleGroups ?? [],
            dismissedAssessmentId: PhysiqueSplitSuggestionPreferences.dismissedAssessmentId
        )
    }

    func dismissPhysiqueSplitSuggestion(assessmentId: UUID) {
        PhysiqueSplitSuggestionPreferences.markHandled(assessmentId: assessmentId)
    }

    @discardableResult
    func applyPhysiqueSplitSuggestion(_ suggestion: PhysiqueSplitSuggestion) async -> Bool {
        guard var profile = userProfile, profile.preferredSplit == suggestion.from else {
            return false
        }
        let previousSplit = profile.preferredSplit
        let previousIndex = programState.splitDayIndex

        profile.preferredSplit = suggestion.to
        guard await updateUserProfile(profile, refreshWorkout: false) else {
            return false
        }

        var state = programState
        state.splitDayIndex = 0
        programState = state
        try? await programStateRepository.saveState(state)

        // Completed today: split + rotation take effect on the next workout.
        // Do not call regenerate (it returns false when today is completed).
        if isTodayWorkoutCompleted {
            PhysiqueSplitSuggestionPreferences.markHandled(assessmentId: suggestion.assessmentId)
            return true
        }

        let regenerated = await regenerateTodayWorkout(profile: profile)
        if !regenerated {
            var rolledBack = profile
            rolledBack.preferredSplit = previousSplit
            _ = await updateUserProfile(rolledBack, refreshWorkout: false)
            var rolledState = programState
            rolledState.splitDayIndex = previousIndex
            programState = rolledState
            try? await programStateRepository.saveState(rolledState)
            return false
        }

        PhysiqueSplitSuggestionPreferences.markHandled(assessmentId: suggestion.assessmentId)
        return true
    }
}

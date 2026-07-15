import Foundation

extension AppEnvironment {
    /// Permanently deletes cloud account data (when signed in) and wipes all local user data.
    func deleteAccount() async throws {
        let shouldClearAuthSession = isSignedIn && authService.isAvailable
        if shouldClearAuthSession {
            try await authService.deleteAccount()
        }
        try await wipeAllLocalUserData(clearAuthSession: shouldClearAuthSession)
    }

    /// Removes all persisted user data on this device without touching cloud auth.
    func wipeAllLocalUserData(clearAuthSession: Bool = false) async throws {
        workoutGenerationToken &+= 1
        isWorkoutGenerationActive = false
        isReservingWorkoutGeneration = false
        sessionSaveTask?.cancel()
        sessionSaveTask = nil

        try await exerciseRepository.resetUserPreferences()
        try await exerciseRepository.resetCustomExercises()
        PersistenceHelper.clearAllPersistedData()
        AppGroupSessionStore.clearAll()
        resetRuntimeStateAfterDataDeletion()
        if clearAuthSession, authService.isAvailable {
            try await authService.signOut()
        }
    }

    private func resetRuntimeStateAfterDataDeletion() {
        userProfile = nil
        todayWorkout = nil
        programState = TrainingProgramState()
        recoveryStates = RecoveryCalculator.defaultStates()
        hasCompletedOnboarding = false
        sorenessLevel = .none
        lastValidation = nil
        lastGenerationFailure = nil
        isSignedIn = false
        authEmail = nil
        syncMessage = nil
        coachWorkoutUpdateMessage = nil
        photoCloudBackupEnabled = false
        healthReadiness = .empty
        paywallFeature = nil
        bodyPhotoRevision &+= 1
    }
}

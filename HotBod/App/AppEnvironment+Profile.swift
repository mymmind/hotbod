import Foundation

extension AppEnvironment {
    @discardableResult
    func updateUserProfile(_ profile: UserProfile, refreshWorkout: Bool = false) async -> Bool {
        var updated = profile
        updated.updatedAt = Date()
        do {
            try await userProfileRepository.saveProfile(updated)
            userProfile = updated
            await cloudSyncIfSignedIn {
                try await cloudSyncService.pushProfile(updated)
            }
            await rescheduleAllLocalReminders()
            if refreshWorkout {
                _ = await regenerateTodayWorkout(profile: updated)
            }
            return true
        } catch {
            syncMessage = error.localizedDescription
            return false
        }
    }

    func completeOnboarding(profile: UserProfile) async throws {
        try await userProfileRepository.saveProfile(profile)
        try await userProfileRepository.setOnboardingComplete(true)
        userProfile = profile
        hasCompletedOnboarding = true
        recoveryStates = RecoveryCalculator.defaultStates()
        try await recoveryRepository.saveRecoveryStates(recoveryStates)
    }

    /// Completes onboarding, ensures today's plan exists, schedules reminders, and
    /// auto-starts today's session when generation succeeds.
    func finishOnboardingAndStartTodayWorkout(
        profile: UserProfile,
        lockSplit: Bool = false
    ) async -> WorkoutSession? {
        var updated = profile
        updated.updatedAt = Date()
        OnboardingProfileEditing.normalizeForCompletion(&updated, lockSplit: lockSplit)
        guard OnboardingProfileEditing.hasValidSchedule(updated) else {
            syncMessage = "Select at least two training days."
            return nil
        }

        do {
            try await completeOnboarding(profile: updated)
        } catch {
            syncMessage = error.localizedDescription
            return nil
        }

        await normalizeProgramStateForToday(profile: updated)
        await rescheduleAllLocalReminders()
        guard await ensureTodayWorkoutOnLaunch(profile: updated),
              let workout = todayWorkout else {
            if todayWorkout == nil {
                syncMessage = "Onboarding saved, but today's workout could not be generated. Open Today to regenerate."
            }
            return nil
        }

        // Always auto-start after onboarding generation — reminder days are not a start gate.
        return await resumeOrStartWorkout(
            from: workout,
            deferStartTimestamp: !UITestConfiguration.isUITesting
        )
    }

    func resetOnboarding() async throws {
        try await userProfileRepository.setOnboardingComplete(false)
        hasCompletedOnboarding = false
    }
}

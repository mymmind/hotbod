import Foundation

extension AppEnvironment {
    @discardableResult
    func updateUserProfile(_ profile: UserProfile, refreshWorkout: Bool = false) async -> Bool {
        var updated = profile
        updated.updatedAt = Date()
        do {
            try await userProfileRepository.saveProfile(updated)
            userProfile = updated
            if isSignedIn {
                try? await cloudSyncService.pushProfile(updated)
            }
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
    }

    func resetOnboarding() async throws {
        try await userProfileRepository.setOnboardingComplete(false)
        hasCompletedOnboarding = false
    }
}

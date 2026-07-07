import Foundation

extension AppEnvironment {
    func signUp(email: String, password: String) async throws {
        try await authService.signUp(email: email, password: password)
        try await signIn(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        try await authService.signIn(email: email, password: password)
        isSignedIn = true
        authEmail = email
        await alignProfileWithAuthUser()
        await pullFromCloud()
        try await pushToCloud()
        syncMessage = "Signed in. Data synced."
    }

    func signOut() async throws {
        try await authService.signOut()
        isSignedIn = false
        authEmail = nil
        syncMessage = "Signed out."
    }

    func syncNow() async {
        guard isSignedIn else {
            syncMessage = "Sign in to sync."
            return
        }
        do {
            try await pushToCloud()
            syncMessage = "Sync complete."
        } catch {
            syncMessage = error.localizedDescription
        }
    }

    func setPhotoCloudBackup(_ enabled: Bool) async {
        photoCloudBackupEnabled = enabled
        guard isSignedIn else { return }
        try? await cloudSyncService.setPhotoBackupEnabled(enabled)
    }

    func alignProfileWithAuthUser() async {
        guard let userId = await authService.currentUserId() else { return }
        if let profile = userProfile, profile.id != userId {
            let aligned = UserProfile(
                id: userId,
                name: profile.name,
                age: profile.age,
                heightCm: profile.heightCm,
                weightKg: profile.weightKg,
                goal: profile.goal,
                experienceLevel: profile.experienceLevel,
                trainingLocation: profile.trainingLocation,
                availableEquipment: profile.availableEquipment,
                trainingDaysPerWeek: profile.trainingDaysPerWeek,
                preferredSessionLengthMinutes: profile.preferredSessionLengthMinutes,
                preferredSplit: profile.preferredSplit,
                preferredTrainingDays: profile.preferredTrainingDays,
                timeOfDayPreference: profile.timeOfDayPreference,
                limitations: profile.limitations,
                limitationNotes: profile.limitationNotes,
                preferredMuscleGroups: profile.preferredMuscleGroups,
                avoidedMuscleGroups: profile.avoidedMuscleGroups,
                proteinGoalGrams: profile.proteinGoalGrams,
                photoTrackingEnabled: profile.photoTrackingEnabled,
                includeWarmupSets: profile.includeWarmupSets,
                createdAt: profile.createdAt,
                updatedAt: Date()
            )
            try? await userProfileRepository.saveProfile(aligned)
            userProfile = aligned
        }
    }

    func pullFromCloud() async {
        do {
            try await cloudSyncService.pullAll(local: syncStores)
            userProfile = try? await userProfileRepository.fetchProfile()
            todayWorkout = try? await workoutRepository.fetchTodayWorkout()
            programState = (try? await programStateRepository.fetchState()) ?? programState
            hasCompletedOnboarding = (try? await userProfileRepository.isOnboardingComplete()) ?? hasCompletedOnboarding
        } catch {
            syncMessage = error.localizedDescription
        }
    }

    func pushToCloud() async throws {
        try await cloudSyncService.pushAll(local: syncStores)
    }
}

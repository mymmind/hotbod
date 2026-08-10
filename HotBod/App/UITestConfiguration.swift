import Foundation
import UIKit

enum UITestConfiguration {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITesting")
    }

    static var shouldSkipOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-SkipOnboarding")
    }

    static var shouldResetState: Bool {
        ProcessInfo.processInfo.arguments.contains("-ResetState")
    }

    static var shouldMockAI: Bool {
        ProcessInfo.processInfo.arguments.contains("-MockAI")
            || ProcessInfo.processInfo.environment["MOCK_AI"] == "1"
    }

    static var shouldMockFoodSearch: Bool {
        ProcessInfo.processInfo.arguments.contains("-MockFoodSearch")
            || ProcessInfo.processInfo.environment["MOCK_FOOD_SEARCH"] == "1"
    }

    static var shouldMockPhotoPicker: Bool {
        ProcessInfo.processInfo.arguments.contains("-MockPhotoPicker")
    }

    static var shouldForceRestDay: Bool {
        ProcessInfo.processInfo.arguments.contains("-ForceRestDay")
    }

    static var shouldGrantPro: Bool {
        isUITesting
            || ProcessInfo.processInfo.arguments.contains("-GrantPro")
            || ProcessInfo.processInfo.environment["GRANT_PRO"] == "1"
    }

    static var shouldOpenSettings: Bool {
        ProcessInfo.processInfo.arguments.contains("-OpenSettings")
    }

    static var shouldStartWorkout: Bool {
        ProcessInfo.processInfo.arguments.contains("-StartWorkout")
    }

    static var shouldOpenWorkoutPreview: Bool {
        ProcessInfo.processInfo.arguments.contains("-OpenWorkoutPreview")
    }

    static var requestedTab: AppRouter.MainTab? {
        guard isUITesting else { return nil }
        for argument in ProcessInfo.processInfo.arguments {
            guard argument.hasPrefix("-OpenTab=") else { continue }
            let rawValue = String(argument.dropFirst("-OpenTab=".count)).lowercased()
            if rawValue == "coach" { return .physique }
            return AppRouter.MainTab.allCases.first { $0.title.lowercased() == rawValue }
        }
        return nil
    }

    static var onboardingStartStep: Int? {
        guard isUITesting else { return nil }
        for argument in ProcessInfo.processInfo.arguments {
            guard argument.hasPrefix("-OnboardingStep=") else { continue }
            return Int(String(argument.dropFirst("-OnboardingStep=".count)))
        }
        return nil
    }

    static var onboardingPreset: String? {
        guard isUITesting else { return nil }
        for argument in ProcessInfo.processInfo.arguments {
            guard argument.hasPrefix("-OnboardingPreset=") else { continue }
            return String(argument.dropFirst("-OnboardingPreset=".count))
        }
        return nil
    }

    static var shouldAutoFinishOnboarding: Bool {
        isUITesting && ProcessInfo.processInfo.arguments.contains("-AutoFinishOnboarding")
    }

    static var shouldSeedPhysiqueHistory: Bool {
        isUITesting && ProcessInfo.processInfo.arguments.contains("-SeedPhysiqueHistory")
    }

    static var shouldSeedPhysiqueIllustrationReady: Bool {
        isUITesting && ProcessInfo.processInfo.arguments.contains("-SeedPhysiqueIllustrationReady")
    }

    static func applyLaunchConfiguration() {
        if shouldResetState {
            PersistenceHelper.clearAllPersistedData()
        }
    }

    @MainActor
    static func resetOnboardingState(in environment: AppEnvironment) {
        environment.onboardingViewModel = OnboardingViewModel()
    }

    static func defaultOnboardedProfile() -> UserProfile {
        var profile = UserProfile.empty()
        profile.name = "UI Test User"
        if shouldForceRestDay {
            profile.reminderTrainingDays = Array(
                Weekday.allCases.filter { $0 != TrainingSchedule.weekday() }.prefix(2)
            )
        } else {
            profile.reminderTrainingDays = [.monday, .tuesday, .thursday, .friday]
        }
        return profile
    }

    @MainActor
    static func applyDeepLinks(environment: AppEnvironment, router: AppRouter) async {
        guard isUITesting, shouldSkipOnboarding else { return }
        guard case .main = router.route else { return }

        if let tab = requestedTab {
            router.selectedTab = tab
        }

        if shouldOpenSettings {
            router.navigate(to: .settings)
        }

        await seedPhysiqueHistoryIfNeeded(in: environment)
        await seedPhysiqueIllustrationReadyIfNeeded(in: environment)
        await environment.loadActivePhysiqueAssessment()

        if shouldStartWorkout {
            environment.cancelWorkoutGenerationIfNeeded()
            await environment.cancelActiveWorkoutIfNeeded()
            await environment.seedUITestTodayWorkoutIfNeeded(force: true)
            if let workout = environment.todayWorkout,
               let session = await environment.resumeOrStartWorkout(from: workout) {
                router.replace(with: .workoutSession(session))
            }
        }

        if shouldOpenWorkoutPreview {
            if let profile = environment.userProfile {
                if environment.todayWorkout == nil {
                    _ = await environment.ensureTodayWorkoutOnLaunch(profile: profile)
                }
                for _ in 0..<60 where environment.todayWorkout == nil {
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
            if let workout = environment.todayWorkout {
                router.navigate(to: .workoutPreview(workout))
            }
        }
    }

    @MainActor
    static func seedPhysiqueHistoryIfNeeded(in environment: AppEnvironment) async {
        guard shouldSeedPhysiqueHistory else { return }

        let olderId = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        let newerId = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
        let frontPhotoId = UUID()
        let backPhotoId = UUID()

        let older = PhysiqueAssessment(
            id: olderId,
            createdAt: Date().addingTimeInterval(-30 * 24 * 3600),
            frontPhotoId: frontPhotoId,
            backPhotoId: backPhotoId,
            sidePhotoId: nil,
            photoQuality: PhysiquePhotoQuality(
                anglesAvailable: ["front", "back"],
                lightingQuality: "Even",
                overallConfidence: 0.72
            ),
            physique: PhysiqueBuildSummary(
                overallArchetype: "Athletic build with moderate shoulder-to-waist contrast",
                frameSize: "Medium",
                shoulderToWaist: "Moderate contrast",
                waist: "Defined",
                torso: "Balanced",
                muscularity: "Moderate",
                leanness: "Moderate"
            ),
            muscleEntries: [
                PhysiqueMuscleEntry(
                    muscle: .lateralDelts,
                    current: "Moderate side delt development",
                    priorityRank: 1,
                    notes: "Visible from front angle",
                    confidence: .high
                )
            ],
            developmentPriorities: [
                PhysiqueDevelopmentPriority(muscle: .lats, reason: "Width"),
                PhysiqueDevelopmentPriority(muscle: .upperChest, reason: "Shelf")
            ],
            trainingBias: PhysiqueTrainingBias(
                preferredMuscleGroups: [.shoulders, .back, .chest],
                rationale: "Prioritize shoulder width, back width, and upper chest for frame balance."
            ),
            limitations: [
                "Visual estimate only — not a medical assessment.",
                "Side photo missing; rear detail may be less reliable."
            ],
            confidenceBands: PhysiqueConfidenceBands(
                high: ["Front shoulder line"],
                medium: ["Back lat spread"],
                low: ["Rear delt detail without side photo"]
            ),
            source: .onDevice,
            whyTodaySummary: "Bias shoulders, back, and chest to improve visual frame balance."
        )

        let newer = PhysiqueAssessment(
            id: newerId,
            createdAt: Date(),
            frontPhotoId: frontPhotoId,
            backPhotoId: backPhotoId,
            sidePhotoId: nil,
            photoQuality: PhysiquePhotoQuality(
                anglesAvailable: ["front", "back"],
                lightingQuality: "Even",
                overallConfidence: 0.72
            ),
            physique: PhysiqueBuildSummary(
                overallArchetype: "Athletic build with moderate shoulder-to-waist contrast",
                frameSize: "Large",
                shoulderToWaist: "Moderate contrast",
                waist: "Defined",
                torso: "Balanced",
                muscularity: "Moderate",
                leanness: "Moderate"
            ),
            muscleEntries: [
                PhysiqueMuscleEntry(
                    muscle: .lateralDelts,
                    current: "Moderate side delt development",
                    priorityRank: 1,
                    notes: "Visible from front angle",
                    confidence: .high
                )
            ],
            developmentPriorities: [
                PhysiqueDevelopmentPriority(muscle: .lateralDelts, reason: "Caps"),
                PhysiqueDevelopmentPriority(muscle: .lats, reason: "Width")
            ],
            trainingBias: PhysiqueTrainingBias(
                preferredMuscleGroups: [.shoulders, .back, .chest],
                rationale: "Prioritize shoulder width, back width, and upper chest for frame balance."
            ),
            limitations: [
                "Visual estimate only — not a medical assessment.",
                "Side photo missing; rear detail may be less reliable."
            ],
            confidenceBands: PhysiqueConfidenceBands(
                high: ["Front shoulder line"],
                medium: ["Back lat spread"],
                low: ["Rear delt detail without side photo"]
            ),
            source: .onDevice,
            whyTodaySummary: "Bias shoulders, back, and chest to improve visual frame balance."
        )

        let adapted = PhysiqueAssessPipeline.applyTrendAdaptation(
            assessment: newer,
            previous: older,
            photos: []
        )

        await environment.saveActivePhysiqueAssessment(older)
        await environment.saveActivePhysiqueAssessment(adapted)
    }

    @MainActor
    static func seedPhysiqueIllustrationReadyIfNeeded(in environment: AppEnvironment) async {
        guard shouldSeedPhysiqueIllustrationReady else { return }
        guard let profile = environment.userProfile else { return }

        let frontPhotoId = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let backPhotoId = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        let assessmentId = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!

        let dir = environment.bodyPhotosDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "\(frontPhotoId.uuidString).jpg"
        let fileURL = dir.appendingPathComponent(filename)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in }
        if let jpeg = image.jpegData(compressionQuality: 0.85) {
            try? jpeg.write(to: fileURL, options: .atomic)
        }

        let frontPhoto = BodyProgressPhoto(
            id: frontPhotoId,
            userId: profile.id,
            date: Date(),
            poseType: .frontRelaxed,
            localImagePath: filename
        )
        try? await environment.bodyProgressRepository.savePhoto(frontPhoto)
        environment.bumpBodyPhotoRevision()

        let assessment = PhysiqueAssessment(
            id: assessmentId,
            createdAt: Date(),
            frontPhotoId: frontPhotoId,
            backPhotoId: backPhotoId,
            sidePhotoId: nil,
            photoQuality: PhysiquePhotoQuality(
                anglesAvailable: ["front", "back"],
                lightingQuality: "Even",
                overallConfidence: 0.72
            ),
            physique: PhysiqueBuildSummary(
                overallArchetype: "Athletic build with moderate shoulder-to-waist contrast",
                frameSize: "Medium",
                shoulderToWaist: "Moderate contrast",
                waist: "Defined",
                torso: "Balanced",
                muscularity: "Moderate",
                leanness: "Moderate"
            ),
            muscleEntries: [
                PhysiqueMuscleEntry(
                    muscle: .lateralDelts,
                    current: "Moderate side delt development",
                    priorityRank: 1,
                    notes: "Visible from front angle",
                    confidence: .high
                )
            ],
            developmentPriorities: [
                PhysiqueDevelopmentPriority(muscle: .lateralDelts, reason: "Caps"),
                PhysiqueDevelopmentPriority(muscle: .lats, reason: "Width")
            ],
            trainingBias: PhysiqueTrainingBias(
                preferredMuscleGroups: [.shoulders, .back, .chest],
                rationale: "Prioritize shoulder width, back width, and upper chest for frame balance."
            ),
            limitations: [
                "Visual estimate only — not a medical assessment."
            ],
            confidenceBands: PhysiqueConfidenceBands(
                high: ["Front shoulder line"],
                medium: ["Back lat spread"],
                low: []
            ),
            source: .onDevice,
            whyTodaySummary: "Bias shoulders, back, and chest to improve visual frame balance."
        )

        await environment.saveActivePhysiqueAssessment(assessment)
    }
}

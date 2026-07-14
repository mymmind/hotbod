import Foundation

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
            profile.preferredTrainingDays = Array(
                Weekday.allCases.filter { $0 != TrainingSchedule.weekday() }.prefix(2)
            )
            profile.trainingDaysPerWeek = profile.preferredTrainingDays.count
        } else {
            profile.trainingDaysPerWeek = 4
            profile.preferredTrainingDays = [.monday, .tuesday, .thursday, .friday]
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
}

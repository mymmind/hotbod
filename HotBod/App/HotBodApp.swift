import SwiftUI

@main
struct HotBodApp: App {
    @State private var environment = HotBodApp.makeEnvironment()
    @State private var router = AppRouter(initialRoute: LaunchRouteResolver.initialRoute())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(router)
                .environment(\.forgeFeedback, environment.feedbackService)
                .task {
                    UITestConfiguration.applyLaunchConfiguration()
                    if UITestConfiguration.shouldResetState {
                        UITestConfiguration.resetOnboardingState(in: environment)
                    }
                    await environment.bootstrap()
                    if UITestConfiguration.shouldSkipOnboarding {
                        router.route = .main
                        await UITestConfiguration.applyDeepLinks(environment: environment, router: router)
                        return
                    }
                    if environment.hasCompletedOnboarding {
                        router.route = .main
                    } else if case .onboarding = router.route {
                        return
                    } else {
                        router.route = .onboarding
                    }
                }
        }
    }

    private static func makeEnvironment() -> AppEnvironment {
        if UITestConfiguration.isUITesting {
            return AppEnvironment(
                aiWorkoutService: UITestConfiguration.shouldMockAI ? MockAIWorkoutService() : nil,
                foodSearchService: UITestConfiguration.shouldMockFoodSearch ? MockFoodSearchService() : nil,
                authService: NoOpAuthService(),
                cloudSyncService: NoOpCloudSyncService()
            )
        }
        return AppEnvironment()
    }
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            switch router.route {
            case .onboarding:
                OnboardingContainerView()
                    .forgeAnimatedContent(id: "onboarding")
            case .main:
                MainTabView()
                    .forgeAnimatedContent(id: "main")
            case .workoutSession(let session):
                NavigationStack {
                    WorkoutSessionView(session: session)
                }
                .forgeAnimatedContent(id: session.id)
            case .workoutPreview(let workout):
                NavigationStack {
                    WorkoutPreviewView(workout: workout)
                }
                .forgeAnimatedContent(id: workout.id)
            case .exerciseDetail(let id):
                NavigationStack {
                    ExerciseDetailView(exerciseId: id)
                }
                .forgeAnimatedContent(id: id)
            case .settings:
                NavigationStack {
                    SettingsView(presentation: .routerOverlay)
                }
                .forgeAnimatedContent(id: "settings")
            case .coach:
                NavigationStack {
                    CoachView(presentation: .routerOverlay)
                }
                .forgeAnimatedContent(id: "coach")
            }
        }
        .animation(UITestConfiguration.isUITesting ? nil : ForgeMotion.standard, value: router.route)
        .tint(ForgeColors.accent)
    }
}

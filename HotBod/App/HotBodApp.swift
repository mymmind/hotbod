import SwiftUI

@main
struct HotBodApp: App {
    @State private var environment = AppEnvironment()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(router)
                .task {
                    await environment.bootstrap()
                    router.route = environment.hasCompletedOnboarding ? .main : .onboarding
                }
        }
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
        .animation(ForgeMotion.standard, value: router.route)
        .tint(ForgeColors.accent)
    }
}

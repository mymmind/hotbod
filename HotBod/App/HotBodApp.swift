import SwiftUI

@main
struct HotBodApp: App {
    @UIApplicationDelegateAdaptor(HotBodAppDelegate.self) private var appDelegate
    @State private var environment = HotBodApp.makeEnvironment()
    @State private var router = AppRouter(initialRoute: LaunchRouteResolver.initialRoute())
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(router)
                .environment(\.forgeFeedback, environment.feedbackService)
                .onAppear {
                    appDelegate.router = router
                    appDelegate.flushPendingNavigation()
                    if !UITestConfiguration.isUITesting {
                        PhoneWatchConnectivity.activate()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        guard !UITestConfiguration.isUITesting else { return }
                        Task { await environment.handleAppBecameActive() }
                    case .background:
                        Task { await environment.flushPendingWorkoutSessionSave() }
                    default:
                        break
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    guard !UITestConfiguration.isUITesting else { return }
                    Task { await environment.handleCalendarDayChangedWhileActive() }
                }
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
    @State private var countdownLine = "Start when ready."

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
            case .physique:
                NavigationStack {
                    PhysiqueView()
                }
                .forgeAnimatedContent(id: "physique")
            }
        }
        .animation(UITestConfiguration.isUITesting ? nil : ForgeMotion.standard, value: router.route)
        .tint(ForgeColors.accent)
        .preferredColorScheme(.dark)
        .overlay {
            if let session = router.workoutStartCountdownSession {
                WorkoutStartCountdownView(openingLine: countdownLine) {
                    Task { await WorkoutStartFlow.finishCountdown(environment: environment, router: router) }
                }
                .task(id: session.id) {
                    countdownLine = WorkoutStartCountdown.openingLine(for: session)
                    let exercises = await environment.fetchAllExercises()
                    let firstId = session.exercises.min { $0.orderIndex < $1.orderIndex }?.exerciseId
                    let name = exercises.first { $0.id == firstId }?.name
                    countdownLine = WorkoutStartCountdown.openingLine(for: session, exerciseName: name)
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(
            UITestConfiguration.isUITesting ? nil : ForgeMotion.standard,
            value: router.workoutStartCountdownSession?.id
        )
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard !UITestConfiguration.isUITesting else { return }
            guard !router.suppressesWatchCommands else { return }
            drainWatchControlCommands()
            guard !environment.hasActiveWorkoutSession else { return }
            if let workout = environment.todayWorkout, !environment.isTodayWorkoutCompleted {
                PhoneWatchSessionBridge.publishReady(title: workout.title)
            } else {
                PhoneWatchSessionBridge.publishIdle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotbodWatchCommandsPending)) { _ in
            guard !UITestConfiguration.isUITesting else { return }
            guard !router.suppressesWatchCommands else { return }
            drainWatchControlCommands()
        }
    }

    private func drainWatchControlCommands() {
        let commands = AppGroupSessionStore.consumeCommands { action in
            action == .startWorkout || action == .endWorkout
        }
        for command in commands {
            switch command.action {
            case .startWorkout:
                Task { await environment.startTodayWorkoutFromWatch(router: router) }
            case .endWorkout:
                Task { await environment.endActiveWorkoutFromWatch() }
            default:
                break
            }
        }
    }
}

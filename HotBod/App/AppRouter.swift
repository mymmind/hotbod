import SwiftUI
import Observation

enum AppRoute: Hashable {
    case onboarding
    case main
    case workoutSession(WorkoutSession)
    case workoutPreview(GeneratedWorkout)
    case exerciseDetail(String)
    case settings
    case coach
}

@Observable
@MainActor
final class AppRouter {
    var route: AppRoute
    var selectedTab: MainTab = .today
    private(set) var routeStack: [AppRoute] = []

    init(initialRoute: AppRoute = .onboarding) {
        route = initialRoute
    }

    enum MainTab: Int, CaseIterable, Identifiable {
        case today, train, protein, progress, coach

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .today: "Today"
            case .train: "Train"
            case .protein: "Protein"
            case .progress: "Progress"
            case .coach: "Coach"
            }
        }

        var icon: String {
            switch self {
            case .today: "sun.max"
            case .train: "dumbbell"
            case .protein: "fork.knife"
            case .progress: "chart.line.uptrend.xyaxis"
            case .coach: "bubble.left.and.bubble.right"
            }
        }
    }

    func showMain() {
        routeStack.removeAll()
        route = .main
    }

    func showOnboarding() {
        routeStack.removeAll()
        route = .onboarding
    }

    /// Push a full-screen route on top of the current screen (typically from main tabs).
    func navigate(to newRoute: AppRoute) {
        switch route {
        case .main:
            routeStack = [.main]
        default:
            routeStack.append(route)
        }
        route = newRoute
    }

    /// Replace the current overlay route without stacking (e.g. preview → active session).
    func replace(with newRoute: AppRoute) {
        routeStack.removeAll()
        if case .main = newRoute {
            route = .main
            return
        }
        routeStack = [.main]
        route = newRoute
    }

    /// Pop one level in the overlay stack, or return to main tabs.
    func dismissRoute() {
        if let previous = routeStack.popLast() {
            route = previous
        } else {
            route = .main
        }
    }

    /// Dismiss all overlays and return to main tabs.
    func dismissToMain() {
        routeStack.removeAll()
        route = .main
    }
}

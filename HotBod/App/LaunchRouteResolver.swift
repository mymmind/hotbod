import Foundation

enum LaunchRouteResolver {
    private static let onboardingKey = "onboarding_complete.json"

    static func initialRoute() -> AppRoute {
        if UITestConfiguration.isUITesting {
            return UITestConfiguration.shouldSkipOnboarding ? .main : .onboarding
        }
        let hasCompletedOnboarding = PersistenceHelper.load(Bool.self, from: onboardingKey) ?? false
        return hasCompletedOnboarding ? .main : .onboarding
    }
}

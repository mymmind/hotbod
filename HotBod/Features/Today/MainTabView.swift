import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        @Bindable var environment = environment

        ZStack(alignment: .bottom) {
            Group {
                switch router.selectedTab {
                case .today:
                    TodayView()
                case .train:
                    TrainView()
                case .protein:
                    ProteinTrackerView()
                case .progress:
                    ProgressDashboardView()
                case .coach:
                    CoachView(presentation: .tab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ForgeFloatingTabBar(selectedTab: $router.selectedTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
        }
        .sheet(item: $environment.paywallFeature) { feature in
            ForgePaywallView(feature: feature)
        }
        .onAppear {
            if let tab = UITestConfiguration.requestedTab {
                router.selectedTab = tab
            }
        }
    }
}

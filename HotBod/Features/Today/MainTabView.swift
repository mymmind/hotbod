import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

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
    }
}

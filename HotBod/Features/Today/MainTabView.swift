import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var showsHardcoreHello = false

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
                case .physique:
                    PhysiqueView()
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
        .task { evaluateHardcoreHello() }
        .overlay {
            if showsHardcoreHello {
                HardcoreHelloView {
                    HardcoreHelloStore().markSeen()
                    withAnimation(helloAnimation) {
                        showsHardcoreHello = false
                    }
                }
                .transition(UITestConfiguration.isUITesting ? .identity : ForgeMotion.rise)
                .zIndex(3)
            }
        }
        .animation(helloAnimation, value: showsHardcoreHello)
    }

    private var helloAnimation: Animation? {
        UITestConfiguration.isUITesting ? nil : ForgeMotion.standard
    }

    private func evaluateHardcoreHello() {
        let store = HardcoreHelloStore()
        showsHardcoreHello = HardcoreHelloGate.shouldPresent(
            isTestFlight: HardcoreHelloGate.isCurrentInstallTestFlight,
            isUITesting: UITestConfiguration.isUITesting,
            seenCampaignID: store.seenCampaignID
        )
    }
}

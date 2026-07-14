import SwiftUI

struct ForgeFloatingTabBar: View {
    @Binding var selectedTab: AppRouter.MainTab
    @Environment(\.forgeFeedback) private var feedback

    var body: some View {
        HStack(spacing: ForgeSpacing.s0) {
            ForEach(AppRouter.MainTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, ForgeSpacing.s2)
        .padding(.vertical, ForgeSpacing.s2)
        .background {
            Capsule()
                .fill(ForgeColors.surface)
                .forgeElevation(.tabBar)
                .overlay {
                    Capsule()
                        .stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline)
                }
        }
    }

    private func tabButton(_ tab: AppRouter.MainTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            guard selectedTab != tab else { return }
            feedback.play(.tabSelection)
            withAnimation(ForgeMotion.quick) { selectedTab = tab }
        } label: {
            VStack(spacing: ForgeSpacing.s1) {
                Image(systemName: tab.icon)
                    .font(.forgeTabIcon(selected: isSelected))
                    .frame(width: ForgeTarget.min, height: ForgeTarget.min)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(ForgeColors.accent.opacity(0.12))
                        }
                    }
                Text(tab.title)
                    .font(.forgeTabLabel(selected: isSelected))
            }
            .foregroundStyle(isSelected ? ForgeColors.accent : ForgeColors.textSecondary)
            .frame(maxWidth: .infinity)
            .forgeMinTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tab.title), tab")
        .accessibilityIdentifier("tab.\(tab.title.lowercased())")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

enum ForgeTabBarMetrics {
    static let scrollClearance = ForgeSpacing.tabClearance
}

extension View {
    func forgeFloatingTabBarClearance(enabled: Bool = true) -> some View {
        modifier(ForgeTabBarClearanceModifier(enabled: enabled))
    }
}

private struct ForgeTabBarClearanceModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.contentMargins(.bottom, ForgeTabBarMetrics.scrollClearance, for: .scrollContent)
        } else {
            content
        }
    }
}

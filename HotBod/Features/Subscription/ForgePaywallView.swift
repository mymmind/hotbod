import SwiftUI

struct ForgePaywallView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    let feature: ProFeature

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.s5) {
                    hero
                    featureCard
                    benefitsList
                    plansSection
                    if let error = environment.subscriptionService.lastError {
                        Text(error)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.destructive)
                    }
                    legalCopy
                }
                .padding(ForgeSpacing.s5)
            }
            .background(ForgeColors.background)
            .navigationTitle("HotBod Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(ForgeColors.accent)
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s2) {
            Text("TRAIN SMARTER")
                .font(ForgeTypography.caption)
                .tracking(ForgeTracking.eyebrowWide)
                .foregroundStyle(ForgeColors.accent)
            Text("Unlock the full coaching loop.")
                .font(ForgeTypography.displayAthletic)
                .foregroundStyle(ForgeColors.textPrimary)
            Text("Unlimited generation, coach-applied workouts, progress history, and shareable session cards.")
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.textSecondary)
        }
    }

    private var featureCard: some View {
        ForgeCard {
            ForgeSectionHeader(title: "You hit a Pro limit", accent: ForgeColors.accent)
            Text(feature.title)
                .font(ForgeTypography.heading)
            Text(feature.subtitle)
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.textSecondary)
        }
    }

    private var benefitsList: some View {
        ForgeCard {
            ForgeSectionHeader(title: "Pro includes", accent: ForgeColors.accentGreen)
            ForEach(ProFeature.allCases) { item in
                HStack(alignment: .top, spacing: ForgeSpacing.s3) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ForgeColors.accentGreen)
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(ForgeTypography.label)
                        Text(item.subtitle)
                            .font(ForgeTypography.caption)
                            .foregroundStyle(ForgeColors.muted)
                    }
                }
            }
        }
    }

    private var plansSection: some View {
        VStack(spacing: ForgeSpacing.s3) {
            ForEach(environment.subscriptionService.plans) { plan in
                Button {
                    Task {
                        let purchased = await environment.subscriptionService.purchase(planID: plan.id)
                        if purchased { dismiss() }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(plan.displayName)
                                    .font(ForgeTypography.heading)
                                if plan.isBestValue {
                                    Text("BEST VALUE")
                                        .font(ForgeTypography.caption)
                                        .tracking(ForgeTracking.tight)
                                        .foregroundStyle(ForgeColors.accentGreen)
                                }
                            }
                            Text(plan.periodLabel)
                                .font(ForgeTypography.caption)
                                .foregroundStyle(ForgeColors.muted)
                        }
                        Spacer()
                        Text(plan.displayPrice)
                            .font(ForgeTypography.monoMetric)
                            .foregroundStyle(ForgeColors.accent)
                    }
                    .padding(ForgeSpacing.s4)
                    .background(ForgeColors.surface)
                    .overlay(Rectangle().stroke(ForgeColors.border, lineWidth: ForgeBorder.hairline))
                }
                .buttonStyle(.plain)
                .disabled(environment.subscriptionService.isLoading)
            }

            ForgeButton(
                title: environment.subscriptionService.isLoading ? "Processing…" : "Restore Purchases",
                style: .secondary,
                isLoading: environment.subscriptionService.isLoading
            ) {
                Task { await environment.subscriptionService.restore() }
            }
        }
    }

    private var legalCopy: some View {
        Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled at least 24 hours before the period ends.")
            .font(ForgeTypography.caption)
            .foregroundStyle(ForgeColors.muted)
    }
}

#Preview {
    ForgePaywallView(feature: .unlimitedGeneration)
        .environment(AppEnvironment())
}

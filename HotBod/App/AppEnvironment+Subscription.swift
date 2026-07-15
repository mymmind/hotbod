import Foundation

extension AppEnvironment {
    var isPro: Bool { SubscriptionConfig.unrestrictedAccess || subscriptionService.isPro }

    func canAccess(_ feature: ProFeature) -> Bool {
        if SubscriptionConfig.unrestrictedAccess || isPro { return true }
        switch feature {
        case .unlimitedGeneration:
            refreshRegenerationWeekIfNeeded()
            return remainingFreeRegenerations > 0
        case .coachWorkoutApply, .bodyPhotoHistory, .workoutExport:
            return false
        }
    }

    var remainingFreeRegenerations: Int {
        if SubscriptionConfig.unrestrictedAccess { return FreeTierLimits.weeklyRegenerations }
        return max(0, FreeTierLimits.weeklyRegenerations - programState.weeklyRegenerationCount)
    }

    func presentPaywall(for feature: ProFeature) {
        guard !SubscriptionConfig.unrestrictedAccess else { return }
        paywallFeature = feature
    }

    func refreshRegenerationWeekIfNeeded(now: Date = Date()) {
        let calendar = Calendar.current
        guard let anchor = programState.regenerationWeekAnchor else {
            programState.regenerationWeekAnchor = startOfWeek(for: now, calendar: calendar)
            return
        }
        let currentWeek = startOfWeek(for: now, calendar: calendar)
        if !calendar.isDate(anchor, equalTo: currentWeek, toGranularity: .weekOfYear) {
            programState.weeklyRegenerationCount = 0
            programState.regenerationWeekAnchor = currentWeek
        }
    }

    func persistRegenerationWeekRefreshIfNeeded(now: Date = Date()) async {
        let before = programState
        refreshRegenerationWeekIfNeeded(now: now)
        guard programState != before else { return }
        try? await programStateRepository.saveState(programState)
        await cloudSyncIfSignedIn {
            try await cloudSyncService.pushProgramState(programState)
        }
    }

    func recordRegenerationUsage() async {
        guard !SubscriptionConfig.unrestrictedAccess else { return }
        refreshRegenerationWeekIfNeeded()
        programState.weeklyRegenerationCount += 1
        try? await programStateRepository.saveState(programState)
    }

    private func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}

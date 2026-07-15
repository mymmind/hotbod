import Foundation

extension AppEnvironment {
    /// Refreshes day-scoped state when the app returns to the foreground.
    /// Skipped during bootstrap so cold launch never writes partial defaults over persisted data.
    func handleAppBecameActive() async {
        guard !isBootstrapping, hasCompletedBootstrap else { return }
        await refreshDayScopedState(pullCloudFirst: true)
    }

    /// Refreshes day-scoped state when the calendar day changes while the app stays foregrounded.
    func handleCalendarDayChangedWhileActive() async {
        guard !isBootstrapping, hasCompletedBootstrap else { return }
        await refreshDayScopedState(pullCloudFirst: true)
    }

    /// Serializes day-scoped refresh so concurrent foreground/midnight triggers do not overlap.
    func refreshDayScopedState(pullCloudFirst: Bool) async {
        if dayScopedRefreshInProgress, let existing = dayScopedRefreshTask {
            await existing.value
            return
        }

        dayScopedRefreshInProgress = true
        defer {
            dayScopedRefreshInProgress = false
            dayScopedRefreshTask = nil
        }

        let task = Task { @MainActor in
            await performDayScopedRefresh(pullCloudFirst: pullCloudFirst)
        }
        dayScopedRefreshTask = task
        await task.value
    }

    private func performDayScopedRefresh(pullCloudFirst: Bool) async {
        guard hasCompletedOnboarding, userProfile != nil else { return }

        if pullCloudFirst, isSignedIn {
            let localDecayReference = programState.lastRecoveryDecayAppliedAt
            await pullFromCloud()
            await mergeDecayReferenceAfterCloudPull(local: localDecayReference)
            recoveryStates = RecoveryCalculator.normalizeStates(
                (try? await recoveryRepository.fetchRecoveryStates()) ?? recoveryStates
            )
        }

        await refreshHealthReadiness()
        await persistRegenerationWeekRefreshIfNeeded()
        await applyRecoveryDecay()
        await revalidateTodayPlanForCurrentDay()
        calendarDayRevision &+= 1
    }
}

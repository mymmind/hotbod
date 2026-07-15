import Foundation

extension AppEnvironment {
    func applyRecoveryDecay(now: Date = Date()) async {
        guard let profile = userProfile else { return }
        var states = recoveryStates
        let decay = RecoveryCalculator.decayRecovery(
            states: states,
            experienceLevel: profile.experienceLevel,
            lastDecayAppliedAt: programState.lastRecoveryDecayAppliedAt,
            now: now
        )
        states = decay.states
        recoveryStates = states
        try? await recoveryRepository.saveRecoveryStates(states)

        var state = programState
        state.lastRecoveryDecayAppliedAt = decay.lastDecayAppliedAt
        programState = state
        try? await programStateRepository.saveState(state)
        await cloudSyncIfSignedIn {
            try await cloudSyncService.pushProgramState(state)
        }
    }

    func refreshHealthReadiness() async {
        await healthKitReadinessService.requestAuthorizationIfNeeded()
        healthReadiness = await healthKitReadinessService.fetchReadinessSnapshot()
    }

    func setSoreness(_ level: SorenessLevel) {
        sorenessLevel = level
    }
}

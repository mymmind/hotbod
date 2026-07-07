import Foundation

extension AppEnvironment {
    func applyRecoveryDecay() async {
        guard let profile = userProfile else { return }
        var states = recoveryStates
        states = RecoveryCalculator.decayRecovery(states: states, experienceLevel: profile.experienceLevel)
        states = RecoveryCalculator.applySoreness(states: states, level: sorenessLevel)
        recoveryStates = states
        try? await recoveryRepository.saveRecoveryStates(states)
    }

    func refreshHealthReadiness() async {
        await healthKitReadinessService.requestAuthorizationIfNeeded()
        healthReadiness = await healthKitReadinessService.fetchReadinessSnapshot()
    }

    func setSoreness(_ level: SorenessLevel) async {
        sorenessLevel = level
        await applyRecoveryDecay()
    }
}

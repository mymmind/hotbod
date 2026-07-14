import Foundation

extension AppEnvironment {
    func requestHealthKitWorkoutExportAuthorization() async {
        await healthKitWorkoutExportService.requestAuthorizationIfNeeded()
    }

    func exportCompletedWorkoutIfEnabled(_ session: WorkoutSession) async {
        guard userProfile?.exportWorkoutsToHealthKit == true else { return }
        let bodyWeight = userProfile?.weightKg ?? 80
        await healthKitWorkoutExportService.exportCompletedWorkout(session, bodyWeightKg: bodyWeight)
    }
}

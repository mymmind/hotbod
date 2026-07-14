import Foundation
import HealthKit

enum HealthKitWorkoutBuilder {
    static func interval(for session: WorkoutSession) -> (start: Date, end: Date, duration: TimeInterval)? {
        let end = session.completedAt ?? Date()
        let start = session.startedAt ?? end.addingTimeInterval(-Double(session.estimatedDurationMinutes * 60))
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return nil }
        return (start, end, duration)
    }

    static func energyBurnedKcal(session: WorkoutSession, bodyWeightKg: Double) -> Double? {
        guard let interval = interval(for: session) else { return nil }
        let kcal = WorkoutSessionCalculator.estimatedCaloriesBurned(
            elapsedSeconds: Int(interval.duration.rounded()),
            bodyWeightKg: bodyWeightKg
        )
        return kcal > 0 ? Double(kcal) : nil
    }
}

protocol HealthKitWorkoutExportService: Sendable {
    var isAvailable: Bool { get }
    func requestAuthorizationIfNeeded() async
    func exportCompletedWorkout(_ session: WorkoutSession, bodyWeightKg: Double) async
}

struct NoOpHealthKitWorkoutExportService: HealthKitWorkoutExportService, Sendable {
    var isAvailable: Bool { false }

    func requestAuthorizationIfNeeded() async {}

    func exportCompletedWorkout(_ session: WorkoutSession, bodyWeightKg: Double) async {}
}

actor HealthKitWorkoutExportServiceImpl: HealthKitWorkoutExportService {
    private let store = HKHealthStore()

    nonisolated var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorizationIfNeeded() async {
        guard isAvailable else { return }
        let workoutType = HKObjectType.workoutType()
        do {
            try await store.requestAuthorization(toShare: [workoutType], read: [])
        } catch {
            // Authorization denied or entitlement missing — export stays optional.
        }
    }

    func exportCompletedWorkout(_ session: WorkoutSession, bodyWeightKg: Double) async {
        guard isAvailable,
              session.status == .completed,
              let interval = HealthKitWorkoutBuilder.interval(for: session) else { return }

        await requestAuthorizationIfNeeded()

        let energy = HealthKitWorkoutBuilder.energyBurnedKcal(session: session, bodyWeightKg: bodyWeightKg)
            .map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) }

        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: interval.start,
            end: interval.end,
            duration: interval.duration,
            totalEnergyBurned: energy,
            totalDistance: nil,
            metadata: [
                HKMetadataKeyWorkoutBrandName: "HotBod",
                "hotbod_session_id": session.id.uuidString
            ]
        )

        do {
            try await store.save(workout)
        } catch {
            // Export is best-effort; session completion must not fail.
        }
    }
}

enum HealthKitWorkoutExportServiceFactory {
    static func makeDefault() -> any HealthKitWorkoutExportService {
        if HKHealthStore.isHealthDataAvailable() {
            return HealthKitWorkoutExportServiceImpl()
        }
        return NoOpHealthKitWorkoutExportService()
    }
}

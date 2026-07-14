import Foundation
import os
@testable import HotBod

final class SlowMockWorkoutGenerationService: WorkoutGenerationService, @unchecked Sendable {
    private let callCount = OSAllocatedUnfairLock(initialState: 0)
    let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64 = 100_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    func generate(input: WorkoutGenerationInput) async throws -> GeneratedWorkout {
        let call = callCount.withLock { count -> Int in
            count += 1
            return count
        }

        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()

        return GeneratedWorkout(
            id: UUID(),
            title: "Generation-\(call)",
            estimatedDurationMinutes: 45,
            focus: [.chest],
            exercises: [
                PlannedExercise(
                    exerciseId: "bench_press",
                    orderIndex: 0,
                    targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60)]
                )
            ],
            rationale: "",
            safetyNotes: [],
            generatedBy: .rulesEngine,
            createdAt: Date()
        )
    }

    func validate(workout: GeneratedWorkout, input: WorkoutGenerationInput) -> WorkoutValidationResult {
        WorkoutValidationResult(isValid: true, errors: [], warnings: [], suggestions: [])
    }
}

final class FixedMockWorkoutGenerationService: WorkoutGenerationService, @unchecked Sendable {
    var workout: GeneratedWorkout
    var validationResult: WorkoutValidationResult

    init(
        workout: GeneratedWorkout,
        validationResult: WorkoutValidationResult = WorkoutValidationResult(
            isValid: true,
            errors: [],
            warnings: [],
            suggestions: []
        )
    ) {
        self.workout = workout
        self.validationResult = validationResult
    }

    func generate(input: WorkoutGenerationInput) async throws -> GeneratedWorkout {
        workout
    }

    func validate(workout: GeneratedWorkout, input: WorkoutGenerationInput) -> WorkoutValidationResult {
        validationResult
    }
}

final class FailingMockWorkoutGenerationService: WorkoutGenerationService, @unchecked Sendable {
    func generate(input: WorkoutGenerationInput) async throws -> GeneratedWorkout {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Generation failed"])
    }

    func validate(workout: GeneratedWorkout, input: WorkoutGenerationInput) -> WorkoutValidationResult {
        WorkoutValidationResult(isValid: false, errors: ["failed"], warnings: [], suggestions: [])
    }
}

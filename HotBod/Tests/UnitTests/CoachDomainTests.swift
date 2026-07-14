import XCTest
@testable import HotBod

final class AIWorkoutPayloadMapperTests: XCTestCase {
    func testMapsValidPayloadToGeneratedWorkout() {
        let payload = AIWorkoutPayload(
            title: "Upper Push",
            estimatedDurationMinutes: 40,
            focus: ["chest", "shoulders"],
            exercises: [
                AIPlannedExercisePayload(
                    exerciseId: "bench_press",
                    reason: "Primary press",
                    restSeconds: 120,
                    sets: [
                        AIPlannedSetPayload(targetRepsMin: 6, targetRepsMax: 8, targetWeightKg: 80, rpeTarget: 8)
                    ]
                ),
                AIPlannedExercisePayload(
                    exerciseId: "dumbbell_press",
                    reason: nil,
                    restSeconds: nil,
                    sets: [AIPlannedSetPayload(targetRepsMin: 10, targetRepsMax: 12, targetWeightKg: nil, rpeTarget: nil)]
                ),
                AIPlannedExercisePayload(
                    exerciseId: "push_up",
                    reason: nil,
                    restSeconds: 90,
                    sets: [AIPlannedSetPayload(targetRepsMin: 12, targetRepsMax: 15, targetWeightKg: nil, rpeTarget: nil)]
                ),
                AIPlannedExercisePayload(
                    exerciseId: "cable_fly",
                    reason: nil,
                    restSeconds: 60,
                    sets: [AIPlannedSetPayload(targetRepsMin: 12, targetRepsMax: 15, targetWeightKg: nil, rpeTarget: nil)]
                )
            ],
            rationale: "Balanced push session.",
            safetyNotes: ["Warm up shoulders."]
        )

        let workout = AIWorkoutPayloadMapper.toGeneratedWorkout(payload)
        XCTAssertEqual(workout.title, "Upper Push")
        XCTAssertEqual(workout.exercises.count, 4)
        XCTAssertEqual(workout.exercises.first?.exerciseId, "bench_press")
        XCTAssertEqual(workout.generatedBy, .aiAssisted)
        XCTAssertEqual(workout.focus, [.chest, .shoulders])
    }

    func testNormalizesHyphenatedExerciseIds() {
        let catalog = [makeTestExercise(id: "barbell_back_squat", primaryMuscles: [.quads], pattern: .squat)]
        let payload = AIWorkoutPayload(
            title: "Legs",
            estimatedDurationMinutes: 40,
            focus: ["quads"],
            exercises: [
                AIPlannedExercisePayload(
                    exerciseId: "Barbell-Back-Squat ",
                    reason: nil,
                    restSeconds: 90,
                    sets: [AIPlannedSetPayload(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60, rpeTarget: 7)]
                ),
                AIPlannedExercisePayload(
                    exerciseId: "bench_press",
                    reason: nil,
                    restSeconds: 90,
                    sets: [AIPlannedSetPayload(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 60, rpeTarget: 7)]
                ),
                AIPlannedExercisePayload(
                    exerciseId: "dumbbell_press",
                    reason: nil,
                    restSeconds: 90,
                    sets: [AIPlannedSetPayload(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 40, rpeTarget: 7)]
                ),
                AIPlannedExercisePayload(
                    exerciseId: "push_up",
                    reason: nil,
                    restSeconds: 90,
                    sets: [AIPlannedSetPayload(targetRepsMin: 8, targetRepsMax: 12, targetWeightKg: nil, rpeTarget: 7)]
                )
            ],
            rationale: "",
            safetyNotes: []
        )

        let result = AIWorkoutPayloadMapper.map(payload, catalog: catalog)
        XCTAssertEqual(result.workout.exercises.first?.exerciseId, "barbell_back_squat")
    }

    func testDropsUnknownExerciseIds() {
        let catalog = [makeTestExercise(id: "bench_press")]
        let payload = AIWorkoutPayload(
            title: "Test",
            estimatedDurationMinutes: 30,
            focus: ["chest"],
            exercises: [
                AIPlannedExercisePayload(
                    exerciseId: "totally_unknown_move",
                    reason: nil,
                    restSeconds: 90,
                    sets: [AIPlannedSetPayload(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: nil, rpeTarget: nil)]
                ),
                AIPlannedExercisePayload(
                    exerciseId: "bench_press",
                    reason: nil,
                    restSeconds: 90,
                    sets: [AIPlannedSetPayload(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: nil, rpeTarget: nil)]
                )
            ],
            rationale: "",
            safetyNotes: []
        )

        let result = AIWorkoutPayloadMapper.map(payload, catalog: catalog)
        XCTAssertEqual(result.droppedExerciseIds, ["totally_unknown_move"])
        XCTAssertEqual(result.workout.exercises.count, 1)
        XCTAssertEqual(result.workout.exercises.first?.exerciseId, "bench_press")
    }

    func testRemoteCoachResponseDecoding() throws {
        let json = """
        {
          "intent": "modifyWorkout",
          "content": "Trimmed accessories.",
          "proposedWorkout": null,
          "safetyNotes": [],
          "validation": null
        }
        """
        let response = try JSONDecoder().decode(RemoteCoachResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.intent, "modifyWorkout")
        XCTAssertNil(response.proposedWorkout)
    }

    func testRegression_validationDecodesWithoutSuggestions() throws {
        let json = """
        {
          "isValid": true,
          "errors": [],
          "warnings": []
        }
        """
        let validation = try JSONDecoder().decode(WorkoutValidationResult.self, from: Data(json.utf8))
        XCTAssertTrue(validation.isValid)
        XCTAssertEqual(validation.suggestions, [])
    }
}

final class CoachModificationSafetyTests: XCTestCase {
    func testSafeDurationReduction() {
        let current = makeCoachTestWorkout(duration: 45, exerciseIds: ["a", "b", "c", "d"], setsPerExercise: 3)
        let proposed = makeCoachTestWorkout(duration: 30, exerciseIds: ["a", "b", "c", "d"], setsPerExercise: 3)
        XCTAssertTrue(CoachModificationSafety.isSafeModification(
            proposed: proposed,
            current: current,
            allowedExerciseIds: ["a", "b", "c", "d", "e"]
        ))
    }

    func testUnsafeDurationIncrease() {
        let current = makeCoachTestWorkout(duration: 30, exerciseIds: ["a", "b", "c", "d"], setsPerExercise: 3)
        let proposed = makeCoachTestWorkout(duration: 45, exerciseIds: ["a", "b", "c", "d"], setsPerExercise: 3)
        XCTAssertFalse(CoachModificationSafety.isSafeModification(
            proposed: proposed,
            current: current,
            allowedExerciseIds: ["a", "b", "c", "d"]
        ))
    }

    func testUnsafeUnknownExercise() {
        let current = makeCoachTestWorkout(duration: 45, exerciseIds: ["a", "b", "c", "d"], setsPerExercise: 3)
        let proposed = makeCoachTestWorkout(duration: 30, exerciseIds: ["a", "b", "c", "unknown"], setsPerExercise: 3)
        XCTAssertFalse(CoachModificationSafety.isSafeModification(
            proposed: proposed,
            current: current,
            allowedExerciseIds: ["a", "b", "c", "d"]
        ))
    }

    func testUnsafeSetCountIncreaseBeyondTwentyPercent() {
        let current = makeCoachTestWorkout(duration: 45, exerciseIds: ["a", "b", "c", "d"], setsPerExercise: 3)
        let proposed = makeCoachTestWorkout(duration: 30, exerciseIds: ["a", "b", "c", "d"], setsPerExercise: 4)
        XCTAssertFalse(CoachModificationSafety.isSafeModification(
            proposed: proposed,
            current: current,
            allowedExerciseIds: ["a", "b", "c", "d"]
        ))
    }

    func testSafeExerciseSwapWithinAllowedIds() {
        let current = makeCoachTestWorkout(duration: 45, exerciseIds: ["a", "b", "c", "d"], setsPerExercise: 3)
        let proposed = makeCoachTestWorkout(duration: 30, exerciseIds: ["a", "b", "e", "d"], setsPerExercise: 3)
        XCTAssertTrue(CoachModificationSafety.isSafeModification(
            proposed: proposed,
            current: current,
            allowedExerciseIds: ["a", "b", "c", "d", "e"]
        ))
    }

    private func makeCoachTestWorkout(
        duration: Int,
        exerciseIds: [String],
        setsPerExercise: Int
    ) -> GeneratedWorkout {
        GeneratedWorkout(
            id: UUID(),
            title: "Test",
            estimatedDurationMinutes: duration,
            focus: [.chest],
            exercises: exerciseIds.enumerated().map { index, id in
                PlannedExercise(
                    exerciseId: id,
                    orderIndex: index,
                    targetSets: (0..<setsPerExercise).map { _ in PlannedSet(targetRepsMin: 8, targetRepsMax: 10) }
                )
            },
            rationale: "",
            safetyNotes: [],
            generatedBy: .aiAssisted,
            createdAt: Date()
        )
    }
}

final class CoachOfflineModifyTests: XCTestCase {
    func testParsesShorterWorkoutDuration() {
        var profile = UserProfile.empty()
        profile.preferredSessionLengthMinutes = 50
        let options = CoachOfflineModify.generationOptions(from: "Make this workout shorter", profile: profile)
        XCTAssertEqual(options.targetDurationMinutes, 35)
    }

    func testRestDayMessageIncludesNextTrainingDay() {
        var profile = UserProfile.empty()
        let today = TrainingSchedule.weekday()
        profile.preferredTrainingDays = Weekday.allCases.filter { $0 != today }
        let message = CoachOfflineModify.restDayMessage(profile: profile)
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.lowercased().contains("rest day") == true)
    }
}

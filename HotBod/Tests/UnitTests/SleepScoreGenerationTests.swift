import XCTest
@testable import HotBod

final class SleepScoreGenerationTests: XCTestCase {
    func testPoorSleepRecoveryPenaltyAppliedToSortKey() {
        let profile = UserProfile.empty()
        let recovery: [MuscleGroup: Double] = [.back: 60, .shoulders: 60]
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [.back],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: recovery,
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(sleepScore: 40, soreness: .none),
            splitDayFocus: .upper
        )
        XCTAssertEqual(recoverySortKeyForTests(.back, input: input, preferred: [.back]), 65)
        XCTAssertEqual(recoverySortKeyForTests(.shoulders, input: input, preferred: []), 50)
    }

    func testNilSleepScoreLeavesRecoveryUnchanged() {
        let profile = UserProfile.empty()
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: [.back: 60],
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(sleepScore: nil, soreness: .none),
            splitDayFocus: .upper
        )
        XCTAssertEqual(recoverySortKeyForTests(.back, input: input, preferred: []), 60)
    }

    func testPoorSleepCapsRpeAndReducesCompoundSets() async throws {
        let service = RulesWorkoutGenerationService()
        var profile = UserProfile.empty()
        profile.experienceLevel = .intermediate
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 80.0) }),
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(sleepScore: 40, soreness: .none),
            splitDayFocus: .push
        )
        let workout = try await service.generate(input: input)
        let exercises = try await LocalExerciseRepository().fetchAll()
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        let compoundSets = workout.exercises.compactMap { planned -> Int? in
            guard let exercise = exerciseMap[planned.exerciseId],
                  exercise.resolvedMechanics == .compound else { return nil }
            return planned.targetSets.filter { !$0.isWarmup }.count
        }
        if let firstCompoundCount = compoundSets.first {
            XCTAssertLessThanOrEqual(firstCompoundCount, 3)
        }

        for planned in workout.exercises {
            for set in planned.targetSets {
                XCTAssertLessThanOrEqual(set.rpeTarget ?? 10, GenerationConstants.Session.poorSleepMaxRpe)
            }
        }
    }

    func testRegression_sleepScore01ScaleAppliesPoorSleepPenalty() {
        XCTAssertEqual(GenerationConstants.Recovery.normalizeSleepScore(0.35), 35)
        XCTAssertEqual(GenerationConstants.Recovery.normalizeSleepScore(0.95), 95)
        XCTAssertEqual(GenerationConstants.Recovery.normalizeSleepScore(40), 40)
        XCTAssertEqual(GenerationConstants.Recovery.normalizeSleepScore(Optional(0.4)), 40)

        let profile = UserProfile.empty()
        let recovery: [MuscleGroup: Double] = [.back: 60, .shoulders: 60]
        let input = WorkoutGenerationInput(
            userProfile: profile,
            goal: profile.goal,
            experienceLevel: profile.experienceLevel,
            availableEquipment: profile.availableEquipment,
            targetDurationMinutes: 45,
            preferredMuscleGroups: [.back],
            avoidedMuscleGroups: [],
            injuries: [],
            recentWorkouts: [],
            muscleRecovery: recovery,
            exerciseStats: [],
            userPreferences: WorkoutPreferences(),
            readiness: ReadinessInput(sleepScore: 0.40, soreness: .none),
            splitDayFocus: .upper
        )
        // 0.40 on HealthKit scale == 40 on generation scale → poor-sleep −10 penalty
        XCTAssertEqual(recoverySortKeyForTests(.back, input: input, preferred: [.back]), 65)
        XCTAssertEqual(recoverySortKeyForTests(.shoulders, input: input, preferred: []), 50)

        let rpe = WorkoutGenerationAlgorithms.rpeTarget(
            sessionMode: .standard,
            experience: .intermediate,
            isDeload: false,
            sleepScore: 0.40
        )
        XCTAssertEqual(rpe, GenerationConstants.Session.poorSleepMaxRpe)
    }
}

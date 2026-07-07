import XCTest
@testable import HotBod

final class ExerciseFilterTests: XCTestCase {
    func testSearchByName() {
        let exercises = [
            makeExercise(id: "bench_press", name: "Bench Press", muscles: [.chest]),
            makeExercise(id: "squat", name: "Squat", muscles: [.quads])
        ]
        let result = ExerciseFilter.apply(exercises: exercises, query: "bench", filters: ExerciseFilters())
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "bench_press")
    }

    func testFilterByMuscle() {
        let exercises = [
            makeExercise(id: "bench_press", name: "Bench Press", muscles: [.chest]),
            makeExercise(id: "squat", name: "Squat", muscles: [.quads])
        ]
        let result = ExerciseFilter.apply(exercises: exercises, query: "", filters: ExerciseFilters(muscleGroup: .quads))
        XCTAssertEqual(result.count, 1)
    }

    private func makeExercise(id: String, name: String, muscles: [MuscleGroup]) -> Exercise {
        Exercise(
            id: id, name: name, slug: id, primaryMuscles: muscles, secondaryMuscles: [],
            equipment: [.barbell], movementPattern: .squat, difficulty: .intermediate,
            forceType: nil, mechanics: nil, instructions: [], formCues: [], commonMistakes: [],
            contraindications: [], substitutions: [], progressions: [], regressions: [],
            demoVideos: [], imageUrl: nil, tags: []
        )
    }
}

final class ExerciseSubstitutionTests: XCTestCase {
    func testFindsSamePatternSubstitute() {
        let exercises = [
            makeExercise(id: "bench_press", name: "Bench Press", pattern: .horizontalPush, muscles: [.chest]),
            makeExercise(id: "dumbbell_press", name: "Dumbbell Press", pattern: .horizontalPush, muscles: [.chest])
        ]
        let subs = ExerciseSubstitution.candidates(
            for: "bench_press",
            from: exercises,
            availableEquipment: [.dumbbell, .barbell, .bench],
            injuries: []
        )
        XCTAssertEqual(subs.first?.id, "dumbbell_press")
    }

    func testPrefersSameSubstitutionGroup() {
        var bench = makeExercise(id: "bench_press", name: "Bench Press", pattern: .horizontalPush, muscles: [.chest])
        bench.substitutionGroupId = "chest_horizontal_push"
        var dumbbell = makeExercise(id: "dumbbell_press", name: "Dumbbell Press", pattern: .horizontalPush, muscles: [.chest])
        dumbbell.substitutionGroupId = "chest_horizontal_push"
        var fly = makeExercise(id: "cable_fly", name: "Cable Fly", pattern: .isolation, muscles: [.chest])
        fly.substitutionGroupId = "chest_isolation"

        let subs = ExerciseCatalog.substitutes(
            for: "bench_press",
            from: [bench, dumbbell, fly],
            availableEquipment: Equipment.allCases,
            injuries: []
        )
        XCTAssertEqual(subs.first?.id, "dumbbell_press")
        XCTAssertFalse(subs.contains(where: { $0.id == "cable_fly" }))
    }

    func testFetchExercisesInGroup() {
        var bench = makeExercise(id: "bench_press", name: "Bench Press", pattern: .horizontalPush, muscles: [.chest])
        bench.substitutionGroupId = "chest_horizontal_push"
        var dumbbell = makeExercise(id: "dumbbell_press", name: "Dumbbell Press", pattern: .horizontalPush, muscles: [.chest])
        dumbbell.substitutionGroupId = "chest_horizontal_push"

        let group = ExerciseCatalog.exercises(inGroup: "chest_horizontal_push", from: [bench, dumbbell])
        XCTAssertEqual(group.map(\.id).sorted(), ["bench_press", "dumbbell_press"])
    }

    private func makeExercise(id: String, name: String, pattern: MovementPattern, muscles: [MuscleGroup]) -> Exercise {
        Exercise(
            id: id, name: name, slug: id, primaryMuscles: muscles, secondaryMuscles: [],
            equipment: [.dumbbell, .barbell], movementPattern: pattern, difficulty: .intermediate,
            forceType: nil, mechanics: nil, instructions: [], formCues: [], commonMistakes: [],
            contraindications: [], substitutions: [], progressions: [], regressions: [],
            demoVideos: [], imageUrl: nil, tags: []
        )
    }
}

final class ExerciseSeedMechanicsTests: XCTestCase {
    func testBenchPressLoadsCompoundMechanics() {
        let bench = ExerciseCatalogLoader.loadExercises().first { $0.id == "bench_press" }
        XCTAssertEqual(bench?.mechanics, .compound)
        XCTAssertEqual(bench?.resolvedMechanics, .compound)
    }

    func testIsolationPatternLoadsIsolationMechanics() {
        let curl = ExerciseCatalogLoader.loadExercises().first { $0.movementPattern == .isolation }
        XCTAssertNotNil(curl)
        XCTAssertEqual(curl?.mechanics, .isolation)
    }
}

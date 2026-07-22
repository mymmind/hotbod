# Core Finisher Diversity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static plank/dead-bug core ender with one Fitbod-style finisher (3–5 sets, 30s rest) selected by session role + recency, backed by an expanded core catalog.

**Architecture:** Keep append-at-end via `CoreFinisherPlanner`. Replace the hardcoded preference list with an allowlist + planner-local `CoreRole` map, score by `splitDayFocus` then demote recently logged finishers using `UserExerciseStats.recentSets` (because `WorkoutSessionSummary` has no exercise IDs). Expand `ExerciseSeed.json` / `ExerciseContent.json` so the pool has real variety.

**Tech Stack:** Swift 6, SwiftUI/SwiftData app target, XCTest, XcodeGen (`xcodegen generate` after new Swift files under `HotBod/`), `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-07-22-core-finisher-diversity-design.md`

## Global Constraints

- iOS 17+.
- Local-first; no backend dependency.
- Exactly **one** finisher when enabled and candidates exist; **zero** when pool empty.
- Sets/rest: beginner 3 / intermediate 4 / advanced 5, all with **30s** rest.
- Intensity: beginner `.light`; intermediate/advanced `.moderate`.
- Roles stay planner-local (no `coreRole` on `Exercise` schema).
- Exclude cardio abs and heavy hinges: never allowlist `mountain_climber`, `deadlift`, `good_morning`, `medicine_ball_slam`.
- Recency signal: `exerciseStats` (not `WorkoutSessionSummary` — summaries lack exercise IDs). Document this as the intentional implementation of the spec’s rotation requirement.
- New algorithm → unit tests required; regressions use `testRegression_` prefix where fixing broken behavior.
- Do not alter unrelated uncommitted working-tree changes.
- Final verification: focused unit tests, then build.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Algorithms/CoreFinisherPlanner.swift` | Allowlist, role map, scoring, single-finisher prescription |
| `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift` | Pass `splitDayFocus` + `exerciseStats` into planner |
| `HotBod/Resources/ExerciseSeed.json` | New core exercise seeds |
| `HotBod/Resources/ExerciseContent.json` | Content overlays + substitution group ID lists |
| `HotBod/Tests/UnitTests/CoreFinisherPlannerTests.swift` | Domain unit coverage (extract/move from feedback tests) |
| `HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift` | Keep generation integration toggle tests; remove old planner class |

### Spec → API refinement

```swift
enum CoreFinisherPlanner {
    static func appendCoreFinisher(
        to planned: inout [PlannedExercise],
        exercises: [Exercise],
        availableEquipment: [Equipment],
        experience: ExperienceLevel,
        splitDayFocus: SplitDayFocus?,
        exerciseStats: [UserExerciseStats]
    )
}
```

---

### Task 1: Failing planner tests (single finisher + prescription)

**Files:**
- Create: `HotBod/Tests/UnitTests/CoreFinisherPlannerTests.swift`
- Modify: `HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift` (delete `CoreFinisherPlannerTests` class only; leave `testCoreFinisherAppendedWhenEnabled`)

**Interfaces:**
- Consumes: existing `makeTestExercise`, `CoreFinisherPlanner.appendCoreFinisher` (signature will change in Task 2)
- Produces: failing tests that lock desired behavior

- [ ] **Step 1: Create dedicated test file with helpers and failing cases**

```swift
import XCTest
@testable import HotBod

final class CoreFinisherPlannerTests: XCTestCase {
    private func core(_ id: String, muscles: [MuscleGroup] = [.abs], pattern: MovementPattern = .isolation, equipment: [Equipment] = [.bodyweight], difficulty: ExerciseDifficulty = .beginner) -> Exercise {
        var exercise = makeTestExercise(id: id, primaryMuscles: muscles, pattern: pattern, equipment: equipment)
        exercise.difficulty = difficulty
        return exercise
    }

    private func benchPlanned() -> [PlannedExercise] {
        [
            PlannedExercise(
                exerciseId: "bench_press",
                orderIndex: 0,
                targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
            )
        ]
    }

    func testAppendsExactlyOneFinisher() {
        let catalog = [
            makeTestExercise(id: "bench_press"),
            core("plank", pattern: .antiRotation),
            core("dead_bug", pattern: .antiRotation),
            core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .intermediate)
        ]
        var planned = benchPlanned()
        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: catalog,
            availableEquipment: Equipment.allCases,
            experience: .intermediate,
            splitDayFocus: .push,
            exerciseStats: []
        )
        XCTAssertEqual(planned.count, 2)
        XCTAssertTrue(CoreFinisherPlanner.allowlist.contains(planned[1].exerciseId))
    }

    func testPrescriptionMatchesExperience() {
        let cases: [(ExperienceLevel, Int)] = [(.beginner, 3), (.intermediate, 4), (.advanced, 5)]
        for (experience, expectedSets) in cases {
            var planned = benchPlanned()
            CoreFinisherPlanner.appendCoreFinisher(
                to: &planned,
                exercises: [makeTestExercise(id: "bench_press"), core("crunch")],
                availableEquipment: [.bodyweight],
                experience: experience,
                splitDayFocus: .pull,
                exerciseStats: []
            )
            let finisher = planned.last!
            XCTAssertEqual(finisher.targetSets.count, expectedSets, "\(experience)")
            XCTAssertEqual(finisher.restSeconds, 30, "\(experience)")
            XCTAssertEqual(finisher.intensity, experience == .beginner ? .light : .moderate, "\(experience)")
        }
    }

    func testTimedHoldGetsMultipleTimedSets() {
        var planned = benchPlanned()
        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: [makeTestExercise(id: "bench_press"), core("plank", pattern: .antiRotation)],
            availableEquipment: [.bodyweight],
            experience: .beginner,
            splitDayFocus: .fullBody,
            exerciseStats: []
        )
        let finisher = planned.last!
        XCTAssertEqual(finisher.exerciseId, "plank")
        XCTAssertEqual(finisher.targetSets.count, 3)
        XCTAssertTrue(finisher.targetSets.allSatisfy { ($0.targetDurationSeconds ?? 0) > 0 })
    }

    func testEmptyPoolAppendsNothing() {
        var planned = benchPlanned()
        CoreFinisherPlanner.appendCoreFinisher(
            to: &planned,
            exercises: [makeTestExercise(id: "bench_press")],
            availableEquipment: [.bodyweight],
            experience: .intermediate,
            splitDayFocus: .push,
            exerciseStats: []
        )
        XCTAssertEqual(planned.count, 1)
    }
}
```

- [ ] **Step 2: Remove duplicate class from `WorkoutFeedbackDomainTests.swift`**

Delete the entire `final class CoreFinisherPlannerTests` block (the old `testAppendsCoreFinisherExercises` that expected the old API / count).

- [ ] **Step 3: Run tests — expect compile failure or assertion failure on old signature**

```bash
xcodegen generate
xcodebuild test -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/CoreFinisherPlannerTests
```

Expected: FAIL (missing parameters and/or wrong set counts / count == 2).

- [ ] **Step 4: Commit**

```bash
git add HotBod/Tests/UnitTests/CoreFinisherPlannerTests.swift HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift
git commit -m "$(cat <<'EOF'
test: lock core finisher to one Fitbod-style prescription

EOF
)"
```

---

### Task 2: Implement allowlist + single-finisher prescription

**Files:**
- Modify: `HotBod/Domain/Algorithms/CoreFinisherPlanner.swift`
- Modify: `HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift` (update call site so the app compiles; scoring can still be naive)

**Interfaces:**
- Consumes: `ExerciseMetadataResolver.resolvedPrescriptionType`, `defaultDurationSeconds`
- Produces: new `appendCoreFinisher` signature; `CoreFinisherPlanner.allowlist`; still picks first allowlisted candidate (scoring in Task 3)

- [ ] **Step 1: Rewrite `CoreFinisherPlanner.swift` skeleton**

Replace file contents with:

```swift
import Foundation

enum CoreRole: String, CaseIterable {
    case flexion, antiExtension, antiRotation, lateral, lowerBack
}

enum CoreFinisherPlanner {
    static let allowlist: Set<String> = [
        // existing
        "plank", "dead_bug", "bird_dog", "side_plank", "russian_twist",
        "ab_wheel_rollout", "hanging_leg_raise", "cable_crunch", "pallof_press",
        // new (Task 5 catalog)
        "crunch", "reverse_crunch", "lying_leg_raise", "hanging_knee_raise",
        "bicycle_crunch", "back_extension"
    ]

    private static let roleById: [String: CoreRole] = [
        "crunch": .flexion,
        "reverse_crunch": .flexion,
        "lying_leg_raise": .flexion,
        "hanging_knee_raise": .flexion,
        "hanging_leg_raise": .flexion,
        "cable_crunch": .flexion,
        "ab_wheel_rollout": .antiExtension,
        "plank": .antiExtension,
        "dead_bug": .antiRotation,
        "bird_dog": .antiRotation,
        "pallof_press": .antiRotation,
        "side_plank": .lateral,
        "russian_twist": .lateral,
        "bicycle_crunch": .lateral,
        "back_extension": .lowerBack
    ]

    static func appendCoreFinisher(
        to planned: inout [PlannedExercise],
        exercises: [Exercise],
        availableEquipment: [Equipment],
        experience: ExperienceLevel,
        splitDayFocus: SplitDayFocus?,
        exerciseStats: [UserExerciseStats]
    ) {
        guard !planned.isEmpty else { return }

        let existingIds = Set(planned.map(\.exerciseId))
        let candidates = exercises.filter { exercise in
            guard allowlist.contains(exercise.id) else { return false }
            guard !existingIds.contains(exercise.id) else { return false }
            guard exercise.movementPattern != .cardio else { return false }
            return EquipmentFilter.isExerciseAvailable(exercise, availableEquipment: availableEquipment)
        }
        guard let selected = selectFinisher(
            from: candidates,
            planned: planned,
            splitDayFocus: splitDayFocus,
            experience: experience,
            exerciseStats: exerciseStats
        ) else { return }

        planned.append(buildFinisherExercise(selected, orderIndex: planned.count, experience: experience, splitDayFocus: splitDayFocus))
        for index in planned.indices {
            planned[index].orderIndex = index
        }
    }

    // Task 3 replaces this naive pick
    private static func selectFinisher(
        from candidates: [Exercise],
        planned: [PlannedExercise],
        splitDayFocus: SplitDayFocus?,
        experience: ExperienceLevel,
        exerciseStats: [UserExerciseStats]
    ) -> Exercise? {
        candidates.sorted { $0.id < $1.id }.first
    }

    private static func setCount(for experience: ExperienceLevel) -> Int {
        switch experience {
        case .beginner: 3
        case .intermediate: 4
        case .advanced: 5
        }
    }

    private static func intensity(for experience: ExperienceLevel) -> IntensityTarget {
        experience == .beginner ? .light : .moderate
    }

    private static func role(for exercise: Exercise) -> CoreRole {
        if let mapped = roleById[exercise.id] { return mapped }
        if exercise.primaryMuscles.contains(.lowerBack) { return .lowerBack }
        if exercise.movementPattern == .rotation { return .lateral }
        if exercise.movementPattern == .isolation { return .flexion }
        return .antiRotation
    }

    private static func buildFinisherExercise(
        _ exercise: Exercise,
        orderIndex: Int,
        experience: ExperienceLevel,
        splitDayFocus: SplitDayFocus?
    ) -> PlannedExercise {
        let count = setCount(for: experience)
        let prescription = ExerciseMetadataResolver.resolvedPrescriptionType(for: exercise)
        let sets: [PlannedSet]
        switch prescription {
        case .time:
            let seconds = ExerciseMetadataResolver.defaultDurationSeconds(for: exercise)
            sets = (0..<count).map { _ in
                PlannedSet(
                    targetRepsMin: 0,
                    targetRepsMax: 0,
                    rpeTarget: 7,
                    targetDurationSeconds: seconds
                )
            }
        case .distance, .distanceOrTime:
            let meters = ExerciseMetadataResolver.defaultDistanceMeters(for: exercise)
            sets = (0..<count).map { _ in
                PlannedSet(
                    targetRepsMin: 0,
                    targetRepsMax: 0,
                    rpeTarget: 7,
                    targetDistanceMeters: meters
                )
            }
        case .reps:
            sets = (0..<count).map { _ in
                PlannedSet(
                    targetRepsMin: 10,
                    targetRepsMax: 15,
                    rpeTarget: 7
                )
            }
        }

        let roleName = role(for: exercise).rawValue
        let focusLabel = splitDayFocus?.displayName.lowercased() ?? "session"
        return PlannedExercise(
            exerciseId: exercise.id,
            orderIndex: orderIndex,
            targetSets: sets,
            restSeconds: 30,
            intensity: intensity(for: experience),
            reason: "Core finisher — \(roleName) for today’s \(focusLabel)."
        )
    }
}
```

- [ ] **Step 2: Update call site in `WorkoutGenerationService.swift`**

Replace the `CoreFinisherPlanner.appendCoreFinisher(...)` call with:

```swift
CoreFinisherPlanner.appendCoreFinisher(
    to: &planned,
    exercises: allExercises,
    availableEquipment: input.availableEquipment,
    experience: input.experienceLevel,
    splitDayFocus: input.splitDayFocus,
    exerciseStats: input.exerciseStats
)
```

- [ ] **Step 3: Run Task 1 tests**

```bash
xcodebuild test -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/CoreFinisherPlannerTests
```

Expected: PASS for prescription / exactly-one / empty pool. (Session-bias tests added next may not exist yet.)

- [ ] **Step 4: Commit**

```bash
git add HotBod/Domain/Algorithms/CoreFinisherPlanner.swift HotBod/Services/WorkoutGeneration/WorkoutGenerationService.swift
git commit -m "$(cat <<'EOF'
feat: prescribe one multi-set core finisher with 30s rest

EOF
)"
```

---

### Task 3: Session-aware role scoring

**Files:**
- Modify: `HotBod/Domain/Algorithms/CoreFinisherPlanner.swift`
- Modify: `HotBod/Tests/UnitTests/CoreFinisherPlannerTests.swift`

**Interfaces:**
- Consumes: `SplitDayFocus`, `role(for:)`, allowlist candidates
- Produces: `preferredRole(for:planned:)` + scored `selectFinisher`

- [ ] **Step 1: Add failing session-bias tests**

```swift
func testPushPrefersAntiExtension() {
    let catalog = [
        makeTestExercise(id: "bench_press"),
        core("crunch"), // flexion
        core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .intermediate),
        core("pallof_press", muscles: [.obliques], pattern: .antiRotation, equipment: [.cable])
    ]
    var planned = benchPlanned()
    CoreFinisherPlanner.appendCoreFinisher(
        to: &planned,
        exercises: catalog,
        availableEquipment: Equipment.allCases,
        experience: .intermediate,
        splitDayFocus: .push,
        exerciseStats: []
    )
    XCTAssertEqual(planned.last?.exerciseId, "ab_wheel_rollout")
}

func testPullPrefersFlexion() {
    let catalog = [
        makeTestExercise(id: "barbell_row", primaryMuscles: [.back], pattern: .horizontalPull),
        core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .intermediate),
        core("hanging_knee_raise", equipment: [.pullUpBar], difficulty: .beginner),
        core("plank", pattern: .antiRotation)
    ]
    var planned = [
        PlannedExercise(
            exerciseId: "barbell_row",
            orderIndex: 0,
            targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
        )
    ]
    CoreFinisherPlanner.appendCoreFinisher(
        to: &planned,
        exercises: catalog,
        availableEquipment: Equipment.allCases,
        experience: .intermediate,
        splitDayFocus: .pull,
        exerciseStats: []
    )
    XCTAssertEqual(planned.last?.exerciseId, "hanging_knee_raise")
}

func testDeadliftInSessionPenalizesLowerBackFinisher() {
    let catalog = [
        makeTestExercise(id: "deadlift", primaryMuscles: [.hamstrings, .glutes, .lowerBack], pattern: .hinge),
        core("back_extension", muscles: [.lowerBack], pattern: .hinge, difficulty: .beginner),
        core("dead_bug", pattern: .antiRotation)
    ]
    var planned = [
        PlannedExercise(
            exerciseId: "deadlift",
            orderIndex: 0,
            targetSets: [PlannedSet(targetRepsMin: 5, targetRepsMax: 5)]
        )
    ]
    CoreFinisherPlanner.appendCoreFinisher(
        to: &planned,
        exercises: catalog,
        availableEquipment: [.bodyweight],
        experience: .intermediate,
        splitDayFocus: .legs,
        exerciseStats: []
    )
    XCTAssertEqual(planned.last?.exerciseId, "dead_bug")
}

func testBeginnerPrefersEasierDifficultyWhenTiedOnRole() {
    let catalog = [
        makeTestExercise(id: "bench_press"),
        core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .advanced),
        core("plank", pattern: .antiRotation, difficulty: .beginner)
    ]
    var planned = benchPlanned()
    CoreFinisherPlanner.appendCoreFinisher(
        to: &planned,
        exercises: catalog,
        availableEquipment: [.bodyweight],
        experience: .beginner,
        splitDayFocus: .push,
        exerciseStats: []
    )
    XCTAssertEqual(planned.last?.exerciseId, "plank")
}
```

- [ ] **Step 2: Run tests — expect FAIL on push/pull assertions**

```bash
xcodebuild test -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/CoreFinisherPlannerTests/testPushPrefersAntiExtension \
  -only-testing:HotBodTests/CoreFinisherPlannerTests/testPullPrefersFlexion
```

Expected: FAIL (naive alphabetical / first pick).

- [ ] **Step 3: Implement scoring inside `selectFinisher`**

Replace `selectFinisher` + add helpers:

```swift
private static func selectFinisher(
    from candidates: [Exercise],
    planned: [PlannedExercise],
    splitDayFocus: SplitDayFocus?,
    experience: ExperienceLevel,
    exerciseStats: [UserExerciseStats]
) -> Exercise? {
    guard !candidates.isEmpty else { return nil }
    let preferred = preferredRole(for: splitDayFocus, planned: planned, exerciseStats: exerciseStats)
    let penalizeLowerBack = planned.contains { $0.exerciseId == "deadlift" || $0.exerciseId == "good_morning" }
    let statsById = Dictionary(uniqueKeysWithValues: exerciseStats.map { ($0.exerciseId, $0) })

    return candidates.max { lhs, rhs in
        score(lhs, preferred: preferred, experience: experience, penalizeLowerBack: penalizeLowerBack, statsById: statsById)
        < score(rhs, preferred: preferred, experience: experience, penalizeLowerBack: penalizeLowerBack, statsById: statsById)
    }
}

private static func preferredRole(
    for focus: SplitDayFocus?,
    planned: [PlannedExercise],
    exerciseStats: [UserExerciseStats]
) -> CoreRole {
    switch focus {
    case .push, .upper: return .antiExtension
    case .pull: return .flexion
    case .legs, .lower: return .antiRotation
    case .fullBody, .none:
        return leastRecentlyUsedRole(exerciseStats: exerciseStats)
    }
}

private static func leastRecentlyUsedRole(exerciseStats: [UserExerciseStats]) -> CoreRole {
    let now = Date()
    var lastUsed: [CoreRole: Date] = [:]
    for stats in exerciseStats {
        guard allowlist.contains(stats.exerciseId),
              let role = roleById[stats.exerciseId],
              let latest = stats.recentSets.map(\.completedAt).max() else { continue }
        if let existing = lastUsed[role] {
            lastUsed[role] = max(existing, latest)
        } else {
            lastUsed[role] = latest
        }
    }
    return CoreRole.allCases.min { lhs, rhs in
        let l = lastUsed[lhs] ?? .distantPast
        let r = lastUsed[rhs] ?? .distantPast
        if l != r { return l < r }
        return lhs.rawValue < rhs.rawValue
    } ?? .antiRotation
}

private static func score(
    _ exercise: Exercise,
    preferred: CoreRole,
    experience: ExperienceLevel,
    penalizeLowerBack: Bool,
    statsById: [String: UserExerciseStats]
) -> Double {
    var value = 0.0
    let exerciseRole = role(for: exercise)
    if exerciseRole == preferred { value += 100 }
    else if compatible(preferred, exerciseRole) { value += 40 }

    if penalizeLowerBack && exerciseRole == .lowerBack { value -= 80 }

    switch (experience, exercise.difficulty) {
    case (.beginner, .advanced): value -= 50
    case (.beginner, .intermediate): value -= 15
    case (.intermediate, .advanced): value -= 10
    default: break
    }

    if let latest = statsById[exercise.id]?.recentSets.map(\.completedAt).max() {
        let days = Date().timeIntervalSince(latest) / 86_400
        if days < 3 { value -= 60 }
        else if days < 7 { value -= 30 }
    } else if let roleLast = roleLastUsed(exerciseRole, statsById: statsById) {
        let days = Date().timeIntervalSince(roleLast) / 86_400
        if days < 3 { value -= 25 }
    }

    // Stable tie-break: lexicographically smaller id wins when scores equal
    // (handled by max + secondary compare)
    value -= Double(exercise.id.utf8.count) * 0.0001
    value -= Double(exercise.id.unicodeScalars.map(\.value).reduce(0, +)) * 0.0000001
    return value
}

private static func compatible(_ preferred: CoreRole, _ other: CoreRole) -> Bool {
    switch preferred {
    case .antiExtension: return other == .antiRotation
    case .flexion: return other == .lateral
    case .antiRotation: return other == .lateral || other == .antiExtension
    case .lateral: return other == .antiRotation
    case .lowerBack: return other == .antiRotation
    }
}

private static func roleLastUsed(_ role: CoreRole, statsById: [String: UserExerciseStats]) -> Date? {
    roleById.compactMap { id, mapped -> Date? in
        guard mapped == role, let stats = statsById[id] else { return nil }
        return stats.recentSets.map(\.completedAt).max()
    }.max()
}
```

Note: For deterministic ties between equal scores, prefer sorting:

```swift
return candidates.sorted { lhs, rhs in
    let ls = score(lhs, preferred: preferred, experience: experience, penalizeLowerBack: penalizeLowerBack, statsById: statsById)
    let rs = score(rhs, preferred: preferred, experience: experience, penalizeLowerBack: penalizeLowerBack, statsById: statsById)
    if ls != rs { return ls > rs }
    return lhs.id < rhs.id
}.first
```

- [ ] **Step 4: Run CoreFinisherPlannerTests**

```bash
xcodebuild test -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/CoreFinisherPlannerTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Algorithms/CoreFinisherPlanner.swift HotBod/Tests/UnitTests/CoreFinisherPlannerTests.swift
git commit -m "$(cat <<'EOF'
feat: score core finishers by session role and difficulty

EOF
)"
```

---

### Task 4: Recency demotion tests

**Files:**
- Modify: `HotBod/Tests/UnitTests/CoreFinisherPlannerTests.swift`

**Interfaces:**
- Consumes: scoring already in Task 3
- Produces: regression coverage that recent finisher IDs lose

- [ ] **Step 1: Add recency test**

```swift
func testRecentlyLoggedFinisherIsDemoted() {
    let catalog = [
        makeTestExercise(id: "bench_press"),
        core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .intermediate),
        core("plank", pattern: .antiRotation, difficulty: .beginner)
    ]
    let recent = UserExerciseStats(
        exerciseId: "ab_wheel_rollout",
        recentSets: [
            CompletedSet(setIndex: 0, reps: 10, completedAt: Date())
        ],
        preferredRepRangeMin: 8,
        preferredRepRangeMax: 12
    )
    var planned = benchPlanned()
    CoreFinisherPlanner.appendCoreFinisher(
        to: &planned,
        exercises: catalog,
        availableEquipment: [.bodyweight],
        experience: .intermediate,
        splitDayFocus: .push,
        exerciseStats: [recent]
    )
    XCTAssertEqual(planned.last?.exerciseId, "plank")
}

func testRegression_plankNotAlwaysSelectedWhenFresherOptionsExist() {
    let catalog = [
        makeTestExercise(id: "bench_press"),
        core("plank", pattern: .antiRotation),
        core("dead_bug", pattern: .antiRotation),
        core("ab_wheel_rollout", pattern: .antiRotation, difficulty: .intermediate)
    ]
    let stalePlank = UserExerciseStats(
        exerciseId: "plank",
        recentSets: [CompletedSet(setIndex: 0, reps: 0, durationSeconds: 45, completedAt: Date())],
        preferredRepRangeMin: 1,
        preferredRepRangeMax: 1
    )
    var planned = benchPlanned()
    CoreFinisherPlanner.appendCoreFinisher(
        to: &planned,
        exercises: catalog,
        availableEquipment: [.bodyweight],
        experience: .intermediate,
        splitDayFocus: .push,
        exerciseStats: [stalePlank]
    )
    XCTAssertEqual(planned.last?.exerciseId, "ab_wheel_rollout")
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/CoreFinisherPlannerTests/testRecentlyLoggedFinisherIsDemoted \
  -only-testing:HotBodTests/CoreFinisherPlannerTests/testRegression_plankNotAlwaysSelectedWhenFresherOptionsExist
```

Expected: PASS (scoring already handles this). If FAIL, tune the `< 3 day` penalty until demotion wins over role match for the stale preferred exercise while still allowing an alternate same-role candidate.

- [ ] **Step 3: Commit**

```bash
git add HotBod/Tests/UnitTests/CoreFinisherPlannerTests.swift HotBod/Domain/Algorithms/CoreFinisherPlanner.swift
git commit -m "$(cat <<'EOF'
test: demote recently logged core finishers

EOF
)"
```

---

### Task 5: Expand core catalog (seed + content)

**Files:**
- Modify: `HotBod/Resources/ExerciseSeed.json`
- Modify: `HotBod/Resources/ExerciseContent.json`

**Interfaces:**
- Consumes: existing seed DTO shape / content overlay shape
- Produces: six new IDs on allowlist become loadable exercises

- [ ] **Step 1: Append seed entries** (place near other core exercises; JSON array element)

Add these objects (instructions can be short stubs — content overlay supplies quality copy):

```json
{
  "id": "crunch",
  "name": "Crunch",
  "primaryMuscles": ["abs"],
  "secondaryMuscles": [],
  "equipment": ["bodyweight"],
  "movementPattern": "isolation",
  "difficulty": "beginner",
  "instructions": ["Lie on your back with knees bent.", "Crunch ribs toward pelvis.", "Lower with control."],
  "formCues": ["Exhale on the crunch.", "Keep low back lightly pressed down."],
  "commonMistakes": ["Yanking the neck.", "Using hip flexors only."],
  "substitutions": ["cable_crunch", "reverse_crunch"],
  "demoVideos": [],
  "mechanics": "isolation"
},
{
  "id": "reverse_crunch",
  "name": "Reverse Crunch",
  "primaryMuscles": ["abs"],
  "secondaryMuscles": [],
  "equipment": ["bodyweight"],
  "movementPattern": "isolation",
  "difficulty": "beginner",
  "instructions": ["Lie on your back with hips flexed.", "Curl pelvis toward ribs.", "Lower without swinging."],
  "formCues": ["Move the pelvis, not the legs alone.", "Control the eccentric."],
  "commonMistakes": ["Using momentum.", "Arching the low back."],
  "substitutions": ["crunch", "lying_leg_raise"],
  "demoVideos": [],
  "mechanics": "isolation"
},
{
  "id": "lying_leg_raise",
  "name": "Lying Leg Raise",
  "primaryMuscles": ["abs"],
  "secondaryMuscles": [],
  "equipment": ["bodyweight"],
  "movementPattern": "isolation",
  "difficulty": "intermediate",
  "instructions": ["Lie flat with legs extended.", "Raise legs by flexing the trunk.", "Lower under control without arching."],
  "formCues": ["Posterior pelvic tilt before lifting.", "Press low back down."],
  "commonMistakes": ["Swinging legs.", "Arching lumbar spine."],
  "substitutions": ["hanging_knee_raise", "reverse_crunch"],
  "demoVideos": [],
  "mechanics": "isolation"
},
{
  "id": "hanging_knee_raise",
  "name": "Hanging Knee Raise",
  "primaryMuscles": ["abs"],
  "secondaryMuscles": [],
  "equipment": ["pullUpBar"],
  "movementPattern": "isolation",
  "difficulty": "beginner",
  "instructions": ["Hang from a pull-up bar.", "Raise knees toward chest without swinging.", "Lower to a still hang."],
  "formCues": ["Brace before lifting.", "Minimize kip."],
  "commonMistakes": ["Swinging.", "Shrugging into the ears."],
  "substitutions": ["hanging_leg_raise", "lying_leg_raise"],
  "demoVideos": [],
  "mechanics": "isolation"
},
{
  "id": "bicycle_crunch",
  "name": "Bicycle Crunch",
  "primaryMuscles": ["abs", "obliques"],
  "secondaryMuscles": [],
  "equipment": ["bodyweight"],
  "movementPattern": "rotation",
  "difficulty": "beginner",
  "instructions": ["Lie on your back with hands lightly behind head.", "Alternate elbow-to-opposite-knee while extending the other leg.", "Keep the motion controlled."],
  "formCues": ["Rotate through the trunk.", "Do not pull the neck."],
  "commonMistakes": ["Racing the tempo.", "Elbow yanking."],
  "substitutions": ["russian_twist", "side_plank"],
  "demoVideos": [],
  "mechanics": "isolation"
},
{
  "id": "back_extension",
  "name": "Back Extension",
  "primaryMuscles": ["lowerBack"],
  "secondaryMuscles": ["glutes", "hamstrings"],
  "equipment": ["bodyweight", "machine"],
  "movementPattern": "hinge",
  "difficulty": "beginner",
  "instructions": ["Set up on a back-extension bench or floor cobra position as available.", "Extend the torso by squeezing glutes and low back.", "Stop at a neutral long spine — do not hyperextend."],
  "formCues": ["Lead with glutes.", "Brace abs lightly.", "Neutral neck."],
  "commonMistakes": ["Overarching lumbar spine.", "Using momentum."],
  "substitutions": ["bird_dog"],
  "demoVideos": [],
  "mechanics": "isolation"
}
```

Validate JSON after editing:

```bash
python3 -c "import json; json.load(open('HotBod/Resources/ExerciseSeed.json')); print('seed ok')"
```

- [ ] **Step 2: Update `ExerciseContent.json`**

1. Add `exerciseIds` to substitution groups:
   - `core_flexion_rotation`: add `crunch`, `reverse_crunch`, `lying_leg_raise`, `hanging_knee_raise`, `bicycle_crunch`
   - Add new group or reuse for lower back — prefer a small group:

```json
{
  "id": "core_lower_back",
  "name": "Lower Back Endurance",
  "primaryMuscles": ["lowerBack"],
  "movementPattern": "hinge",
  "description": "Controlled lower-back and posterior-chain endurance finishers.",
  "exerciseIds": ["back_extension", "bird_dog"]
}
```

2. Add content overlays for each new ID (mirror `cable_crunch` / `plank` quality — description, aliases, instructions, formCues, commonMistakes, substitutionGroupId).

Example overlay key:

```json
"crunch": {
  "description": "A floor flexion pattern that shortens the abs through a controlled rib-to-pelvis crunch.",
  "aliases": ["Ab Crunch", "Floor Crunch"],
  "substitutionGroupId": "core_flexion_rotation",
  "instructions": [
    "Lie on your back with knees bent and feet flat.",
    "Lightly support the head without pulling on the neck.",
    "Crunch by bringing ribs toward pelvis while pressing the low back down.",
    "Lower slowly until the abs lengthen without losing contact through the lumbar spine."
  ],
  "formCues": ["Exhale as you crunch.", "Move the ribs, not the chin.", "Keep tempo controlled."],
  "commonMistakes": ["Yanking the neck.", "Sitting all the way up into a sit-up.", "Using momentum."]
}
```

Repeat for `reverse_crunch`, `lying_leg_raise`, `hanging_knee_raise`, `bicycle_crunch`, `back_extension` (`substitutionGroupId`: `core_lower_back`).

Validate:

```bash
python3 -c "import json; json.load(open('HotBod/Resources/ExerciseContent.json')); print('content ok')"
```

- [ ] **Step 3: Smoke-load catalog in a unit test or one-off assertion**

Add to `CoreFinisherPlannerTests`:

```swift
func testNewCoreSeedsAreLoadableAndAllowlisted() throws {
    let catalog = ExerciseCatalogLoader.loadExercises()
    let ids = Set(catalog.map(\.id))
    for id in ["crunch", "reverse_crunch", "lying_leg_raise", "hanging_knee_raise", "bicycle_crunch", "back_extension"] {
        XCTAssertTrue(ids.contains(id), id)
        XCTAssertTrue(CoreFinisherPlanner.allowlist.contains(id), id)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/CoreFinisherPlannerTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Resources/ExerciseSeed.json HotBod/Resources/ExerciseContent.json HotBod/Tests/UnitTests/CoreFinisherPlannerTests.swift
git commit -m "$(cat <<'EOF'
feat: expand core catalog for diverse finishers

EOF
)"
```

---

### Task 6: Generation integration + equipment gate

**Files:**
- Modify: `HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift`
- Modify: `HotBod/Tests/UnitTests/CoreFinisherPlannerTests.swift`

**Interfaces:**
- Consumes: `RulesWorkoutGenerationService`, wired planner
- Produces: stronger integration assertions

- [ ] **Step 1: Tighten `testCoreFinisherAppendedWhenEnabled`**

Update assertions to require exactly one allowlisted finisher at end when core is enabled:

```swift
let finishers = workout.exercises.filter { CoreFinisherPlanner.allowlist.contains($0.exerciseId) }
XCTAssertEqual(finishers.count, 1)
XCTAssertEqual(workout.exercises.last?.exerciseId, finishers.first?.exerciseId)
XCTAssertEqual(finishers.first?.restSeconds, 30)
XCTAssertEqual(finishers.first?.targetSets.count, 4) // intermediate in makeGenerationInput
```

Confirm `makeGenerationInput` uses `.intermediate` experience (it already does in that file).

- [ ] **Step 2: Add equipment filter unit test**

```swift
func testPullUpBarRaisesExcludedWithoutBar() {
    let catalog = [
        makeTestExercise(id: "bench_press"),
        core("hanging_knee_raise", equipment: [.pullUpBar]),
        core("crunch")
    ]
    var planned = benchPlanned()
    CoreFinisherPlanner.appendCoreFinisher(
        to: &planned,
        exercises: catalog,
        availableEquipment: [.bodyweight],
        experience: .intermediate,
        splitDayFocus: .pull,
        exerciseStats: []
    )
    XCTAssertEqual(planned.last?.exerciseId, "crunch")
}
```

- [ ] **Step 3: Run focused + related generation tests**

```bash
xcodebuild test -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/CoreFinisherPlannerTests \
  -only-testing:HotBodTests/WorkoutGenerationFeedbackTests
```

Expected: PASS.

- [ ] **Step 4: Build app**

```bash
xcodebuild build -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift HotBod/Tests/UnitTests/CoreFinisherPlannerTests.swift
git commit -m "$(cat <<'EOF'
test: assert generated workouts get one proper core finisher

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Exactly one finisher | 1–2 |
| 3/4/5 sets × 30s rest | 1–2 |
| Timed holds multi-set | 1–2 |
| Session-aware roles | 3 |
| Legs → antiRotation; deadlift penalty | 3 |
| Full body LRU role | 3 (`leastRecentlyUsedRole`) |
| Recency demotion | 3–4 (`exerciseStats`) |
| Catalog expansion (6 IDs) | 5 |
| Content / groups | 5 |
| Wire generation service | 2 (+6 asserts) |
| Equipment filter | 6 |
| Toggle still works | 6 (`WorkoutGenerationFeedbackTests`) |
| No schema `coreRole` | satisfied |
| No cardio finishers | allowlist + cardio filter |

## Placeholder / consistency review

- No TBD steps.
- API uses `exerciseStats` consistently (spec’s `recentWorkouts` intent preserved without inventing exercise IDs on summaries).
- Allowlist IDs match Task 5 seed IDs.
- Call site updated in Task 2 so the tree always compiles between tasks.

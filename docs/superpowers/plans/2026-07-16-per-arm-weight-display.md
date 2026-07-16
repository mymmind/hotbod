# Per-Arm Weight Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make dual handheld exercise loads read as weight per arm in session, preview, and settings, and classify bilateral dumbbell/kettlebell push/pull moves as `.perHand`.

**Architecture:** Keep Codable case `WeightDisplaySemantics.perHand`. Centralize user-facing unit strings on the enum. Expand `ExerciseMetadataResolver` with force-total IDs + push/pull heuristic. Thread that semantics into TARGET, best-set, and preview formatters (no volume math changes).

**Tech Stack:** Swift 6, SwiftUI, XCTest, `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-07-16-per-arm-weight-display-design.md`

## Global Constraints

- iOS 17+.
- Preserve local-first architecture; no backend dependency.
- Do not rename Codable case `perHand`.
- Do not double volume (`weightKg × reps` stays as-is).
- Logged weight remains per implement.
- Use **per arm** wording for all `.perHand` surfaces (including carries / lunges).
- Regression tests use the `testRegression_` prefix where fixing a user-visible bug.
- Final verification: build + relevant `HotBodTests` via `xcodebuild`.
- Do not alter unrelated uncommitted changes.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Enums/DomainEnums.swift` | `sessionWeightLabel`, `settingsWeightLabel`, new `compactLoadUnit` |
| `HotBod/Domain/Models/ExerciseMetadataResolver.swift` | Force-total set, expanded push/pull heuristic, keep force-per-hand IDs |
| `HotBod/Features/WorkoutSession/WorkoutSessionView+Metrics.swift` | Use `compactLoadUnit` in TARGET/suffix + best-set |
| `HotBod/Features/WorkoutSession/WorkoutPreviewViews.swift` | Preview load labels respect semantics |
| `HotBod/Features/Settings/SettingsView+SessionStructure.swift` | Max dumbbell helper uses per-arm copy |
| `HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift` | Resolver + label unit tests (`ExerciseMetadataResolverTests`) |
| `HotBod/Tests/UnitTests/Phase2AlgorithmsTests.swift` | Preview formatter per-arm assertions |

---

### Task 1: Centralize “per arm” labels on `WeightDisplaySemantics`

**Files:**
- Modify: `HotBod/Domain/Enums/DomainEnums.swift` (`WeightDisplaySemantics`)
- Modify: `HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift` (`ExerciseMetadataResolverTests`)

**Interfaces:**
- Produces: `WeightDisplaySemantics.sessionWeightLabel` → `"KG / ARM"` for `.perHand`, `"KG"` for `.total`
- Produces: `WeightDisplaySemantics.settingsWeightLabel` → `"kg per arm"` for `.perHand`, `"kg"` for `.total`
- Produces: `WeightDisplaySemantics.compactLoadUnit` → `"kg per arm"` for `.perHand`, `"kg"` for `.total`

- [ ] **Step 1: Write failing label tests**

Add to `ExerciseMetadataResolverTests` in `HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift`:

```swift
func testPerHandSessionWeightLabelIsKgPerArm() {
    XCTAssertEqual(WeightDisplaySemantics.perHand.sessionWeightLabel, "KG / ARM")
    XCTAssertEqual(WeightDisplaySemantics.total.sessionWeightLabel, "KG")
}

func testPerHandCompactLoadUnitIsKgPerArm() {
    XCTAssertEqual(WeightDisplaySemantics.perHand.compactLoadUnit, "kg per arm")
    XCTAssertEqual(WeightDisplaySemantics.total.compactLoadUnit, "kg")
}

func testPerHandSettingsWeightLabelIsKgPerArm() {
    XCTAssertEqual(WeightDisplaySemantics.perHand.settingsWeightLabel, "kg per arm")
    XCTAssertEqual(WeightDisplaySemantics.total.settingsWeightLabel, "kg")
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/ExerciseMetadataResolverTests/testPerHandSessionWeightLabelIsKgPerArm \
  -only-testing:HotBodTests/ExerciseMetadataResolverTests/testPerHandCompactLoadUnitIsKgPerArm \
  -only-testing:HotBodTests/ExerciseMetadataResolverTests/testPerHandSettingsWeightLabelIsKgPerArm \
  test
```

Expected: FAIL — `compactLoadUnit` missing and/or strings still `"KG EACH"` / `"kg each"` / `"kg per dumbbell"`.

- [ ] **Step 3: Update `WeightDisplaySemantics`**

In `HotBod/Domain/Enums/DomainEnums.swift`, replace the enum body properties with:

```swift
enum WeightDisplaySemantics: String, Codable, CaseIterable, Hashable {
    /// Total load (barbell, machine stack, etc.).
    case total
    /// Weight per dumbbell / kettlebell / hand (displayed as per arm).
    case perHand

    var sessionWeightLabel: String {
        switch self {
        case .total: "KG"
        case .perHand: "KG / ARM"
        }
    }

    /// Compact unit for TARGET lines, preview loads, and best-set copy.
    var compactLoadUnit: String {
        switch self {
        case .total: "kg"
        case .perHand: "kg per arm"
        }
    }

    var settingsWeightLabel: String {
        switch self {
        case .total: "kg"
        case .perHand: "kg per arm"
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Re-run the same `xcodebuild` command as Step 2.  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Enums/DomainEnums.swift \
  HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift
git commit -m "$(cat <<'EOF'
feat: label per-hand loads as kg per arm

EOF
)"
```

---

### Task 2: Hybrid resolver (force-total + push/pull heuristic)

**Files:**
- Modify: `HotBod/Domain/Models/ExerciseMetadataResolver.swift`
- Modify: `HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift`

**Interfaces:**
- Consumes: `Exercise.weightDisplaySemantics`, `Exercise.id`, `Exercise.equipment`, `Exercise.movementPattern`
- Produces: `ExerciseMetadataResolver.resolvedWeightDisplaySemantics(for:) -> WeightDisplaySemantics` with order: explicit → force-total IDs → force-per-hand IDs → dumbbell/KB + pattern heuristic → `.total`

- [ ] **Step 1: Write failing resolver tests**

Add to `ExerciseMetadataResolverTests`:

```swift
func testRegression_inclineDumbbellPressUsesPerHand() {
    let exercise = makeTestExercise(
        id: "incline_dumbbell_press",
        primaryMuscles: [.chest],
        pattern: .horizontalPush,
        equipment: [.dumbbell, .bench]
    )
    XCTAssertEqual(
        ExerciseMetadataResolver.resolvedWeightDisplaySemantics(for: exercise),
        .perHand
    )
}

func testSeatedDumbbellPressUsesPerHand() {
    let exercise = makeTestExercise(
        id: "seated_dumbbell_press",
        primaryMuscles: [.shoulders],
        pattern: .verticalPush,
        equipment: [.dumbbell, .bench]
    )
    XCTAssertEqual(
        ExerciseMetadataResolver.resolvedWeightDisplaySemantics(for: exercise),
        .perHand
    )
}

func testGobletSquatUsesTotalDespiteDumbbellEquipment() {
    let exercise = makeTestExercise(
        id: "goblet_squat",
        primaryMuscles: [.quads],
        pattern: .squat,
        equipment: [.dumbbell, .kettlebell]
    )
    XCTAssertEqual(
        ExerciseMetadataResolver.resolvedWeightDisplaySemantics(for: exercise),
        .total
    )
}

func testBarbellHorizontalPushUsesTotal() {
    let exercise = makeTestExercise(
        id: "bench_press",
        primaryMuscles: [.chest],
        pattern: .horizontalPush,
        equipment: [.barbell, .bench]
    )
    XCTAssertEqual(
        ExerciseMetadataResolver.resolvedWeightDisplaySemantics(for: exercise),
        .total
    )
}

func testExplicitWeightDisplaySemanticsWinsOverHeuristic() {
    var exercise = makeTestExercise(
        id: "custom_db_press",
        primaryMuscles: [.chest],
        pattern: .horizontalPush,
        equipment: [.dumbbell]
    )
    exercise.weightDisplaySemantics = .total
    XCTAssertEqual(
        ExerciseMetadataResolver.resolvedWeightDisplaySemantics(for: exercise),
        .total
    )
}
```

Keep existing `testFarmersCarryUsesPerHandAndDistanceOrTime` unchanged (still must pass).

- [ ] **Step 2: Run tests to verify incline fails**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/ExerciseMetadataResolverTests/testRegression_inclineDumbbellPressUsesPerHand \
  test
```

Expected: FAIL — incline resolves `.total` today.

- [ ] **Step 3: Implement hybrid resolver**

Replace `resolvedWeightDisplaySemantics` and add `totalWeightExerciseIds` in `HotBod/Domain/Models/ExerciseMetadataResolver.swift`:

```swift
private static let totalWeightExerciseIds: Set<String> = [
    "goblet_squat"
]

// Keep existing perHandExerciseIds unchanged.

static func resolvedWeightDisplaySemantics(for exercise: Exercise) -> WeightDisplaySemantics {
    if let explicit = exercise.weightDisplaySemantics {
        return explicit
    }
    if totalWeightExerciseIds.contains(exercise.id) {
        return .total
    }
    if perHandExerciseIds.contains(exercise.id) {
        return .perHand
    }
    if exercise.equipment.contains(.dumbbell) || exercise.equipment.contains(.kettlebell) {
        switch exercise.movementPattern {
        case .horizontalPush, .verticalPush, .horizontalPull, .verticalPull,
             .lunge, .carry, .isolation:
            return .perHand
        default:
            break
        }
    }
    return .total
}
```

- [ ] **Step 4: Run resolver tests**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/ExerciseMetadataResolverTests \
  test
```

Expected: PASS (including farmers carry + new cases).

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Models/ExerciseMetadataResolver.swift \
  HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift
git commit -m "$(cat <<'EOF'
fix: classify bilateral DB presses as per-arm load

EOF
)"
```

---

### Task 3: Session TARGET + best-set use `compactLoadUnit`

**Files:**
- Modify: `HotBod/Features/WorkoutSession/WorkoutSessionView+Metrics.swift`
- Modify: `HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift` (optional pure helper tests if extracted; otherwise rely on Task 1 units + manual session check)

**Interfaces:**
- Consumes: `WeightDisplaySemantics.compactLoadUnit`
- Produces: TARGET strings like `"10kg per arm × 5–8"`; best set like `"10kg per arm × 5"`

- [ ] **Step 1: Write failing formatter tests for load unit composition**

Add to `ExerciseMetadataResolverTests` (keeps Domain-layer coverage without UI harness):

```swift
func testCompactLoadUnitFormatsPerArmTargetFragment() {
    let semantics = WeightDisplaySemantics.perHand
    let fragment = "\(Int(10.0))\(semantics.compactLoadUnit) × "
    XCTAssertEqual(fragment, "10kg per arm × ")
}
```

- [ ] **Step 2: Run to verify PASS once Task 1 landed** (documents expected composition)

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/ExerciseMetadataResolverTests/testCompactLoadUnitFormatsPerArmTargetFragment \
  test
```

Expected: PASS after Task 1.

- [ ] **Step 3: Wire Metrics to `compactLoadUnit`**

In `HotBod/Features/WorkoutSession/WorkoutSessionView+Metrics.swift`:

1. In `targetText`, replace:
```swift
let unit = weightSemantics == .perHand ? "kg each" : "kg"
```
with:
```swift
let unit = weightSemantics.compactLoadUnit
```

2. In `weightSuffix`, replace the same ternary with:
```swift
let unit = semantics.compactLoadUnit
```

3. In `exerciseCompleteSummary`, replace:
```swift
bestDescription = "\(Int(weight))kg × \(best.reps)"
```
with:
```swift
bestDescription = "\(Int(weight))\(meta.resolvedWeightDisplaySemantics.compactLoadUnit) × \(best.reps)"
```

- [ ] **Step 4: Build**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/WorkoutSession/WorkoutSessionView+Metrics.swift \
  HotBod/Tests/UnitTests/WorkoutFeedbackDomainTests.swift
git commit -m "$(cat <<'EOF'
feat: show kg per arm in session targets and best set

EOF
)"
```

---

### Task 4: Preview formatter + settings copy

**Files:**
- Modify: `HotBod/Features/WorkoutSession/WorkoutPreviewViews.swift`
- Modify: `HotBod/Features/Settings/SettingsView+SessionStructure.swift`
- Modify: `HotBod/Tests/UnitTests/Phase2AlgorithmsTests.swift` (`WorkoutPreviewSetFormatterTests`)
- Optional comment-only: `HotBod/Resources/Localizable.xcstrings` if a catalog comment still says “kg each”

**Interfaces:**
- Produces: `WorkoutPreviewSetFormatter.loadLabel(for:loadMode:semantics:) -> String`
- Consumes: `exercise?.resolvedWeightDisplaySemantics ?? .total`

- [ ] **Step 1: Write failing preview test**

Add to `WorkoutPreviewSetFormatterTests` in `HotBod/Tests/UnitTests/Phase2AlgorithmsTests.swift`:

```swift
func testLoadLabelUsesPerArmUnitForDumbbellPress() {
    let set = PlannedSet(targetRepsMin: 8, targetRepsMax: 10, targetWeightKg: 15)
    let exercise = makeStubExercise(
        id: "incline_dumbbell_press",
        muscles: [.chest],
        pattern: .horizontalPush,
        equipment: [.dumbbell, .bench]
    )

    XCTAssertEqual(
        WorkoutPreviewSetFormatter.loadLabel(
            for: set,
            loadMode: exercise.resolvedLoadTrackingMode,
            semantics: exercise.resolvedWeightDisplaySemantics
        ),
        "15kg per arm"
    )
}

func testSummaryLineUsesPerArmUnitForWarmup() {
    let set = PlannedSet(targetRepsMin: 5, targetRepsMax: 8, targetWeightKg: 10, isWarmup: true)
    let exercise = makeStubExercise(
        id: "incline_dumbbell_press",
        muscles: [.chest],
        pattern: .horizontalPush,
        equipment: [.dumbbell, .bench]
    )

    XCTAssertEqual(
        WorkoutPreviewSetFormatter.summaryLine(for: set, exercise: exercise),
        "Warm-up · 10kg per arm × 5–8"
    )
}
```

Update existing `testLoadLabelUsesRoundedWeight` call site to pass `semantics: .total` (or `exercise.resolvedWeightDisplaySemantics`).

- [ ] **Step 2: Run to verify fail on missing `semantics` parameter / wrong string**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/WorkoutPreviewSetFormatterTests \
  test
```

Expected: compile fail or assertion fail until Step 3.

- [ ] **Step 3: Implement preview + settings**

Update `WorkoutPreviewSetFormatter` in `WorkoutPreviewViews.swift`:

```swift
static func loadLabel(
    for set: PlannedSet,
    loadMode: LoadTrackingMode,
    semantics: WeightDisplaySemantics = .total
) -> String {
    guard loadMode != .none else { return "BW" }
    if let weight = set.targetWeightKg {
        return "\(Int(weight.rounded()))\(semantics.compactLoadUnit)"
    }
    return loadMode == .optional ? "—" : "BW"
}

static func summaryLine(for set: PlannedSet, exercise: Exercise?) -> String {
    let loadMode = exercise?.resolvedLoadTrackingMode ?? .supported
    let semantics = exercise?.resolvedWeightDisplaySemantics ?? .total
    let reps = repsLabel(for: set)
    let load = loadLabel(for: set, loadMode: loadMode, semantics: semantics)
    if loadMode == .none {
        return set.isWarmup ? "Warm-up · \(reps) reps" : "\(reps) reps"
    }
    return set.isWarmup ? "Warm-up · \(load) × \(reps)" : "\(load) × \(reps)"
}
```

In `WorkoutPreviewExerciseDetailSheet.setRow`, pass semantics:

```swift
Text(
    WorkoutPreviewSetFormatter.loadLabel(
        for: set,
        loadMode: loadMode,
        semantics: exercise?.resolvedWeightDisplaySemantics ?? .total
    )
)
```

In `SettingsView+SessionStructure.swift`, replace the max-load label line:

```swift
Text(
    "Max \(equipment == .dumbbell ? "dumbbell (\(WeightDisplaySemantics.perHand.settingsWeightLabel))" : "\(equipment.displayName.lowercased()) (kg)")"
)
```

If `Localizable.xcstrings` has comment `"Max dumbbell (kg each)"`, update the comment to `"Max dumbbell (kg per arm)"` only — do not invent new keys unless already present.

- [ ] **Step 4: Run preview tests + build**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/WorkoutPreviewSetFormatterTests \
  -only-testing:HotBodTests/ExerciseMetadataResolverTests \
  test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/WorkoutSession/WorkoutPreviewViews.swift \
  HotBod/Features/Settings/SettingsView+SessionStructure.swift \
  HotBod/Tests/UnitTests/Phase2AlgorithmsTests.swift \
  HotBod/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
feat: surface per-arm load units in preview and settings

EOF
)"
```

---

### Task 5: Verification

**Files:** none (verification only)

- [ ] **Step 1: Run focused unit suite**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/ExerciseMetadataResolverTests \
  -only-testing:HotBodTests/WorkoutPreviewSetFormatterTests \
  test
```

Expected: all PASS.

- [ ] **Step 2: Build app**

```bash
xcodebuild -project HotBod.xcodeproj -scheme HotBod \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Manual smoke (Simulator)**

1. Start a workout containing Incline Dumbbell Press.
2. Confirm weight column **KG / ARM**.
3. Confirm TARGET like `Warm-up · 10kg per arm × 5–8`.
4. Confirm a barbell move still shows **KG** / `…kg × …`.

- [ ] **Step 4: No commit** unless verification fixes were required; if fixes landed, commit with:

```bash
git commit -m "$(cat <<'EOF'
test: verify per-arm weight display coverage

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Copy → KG / ARM, kg per arm, settings | Task 1, 4 |
| Hybrid resolver order + goblet force-total | Task 2 |
| Incline / seated DB press → perHand | Task 2 |
| Session TARGET / column | Task 1–3 (column via `sessionWeightLabel`) |
| Best set + preview | Task 3, 4 |
| No volume doubling / no Codable rename | Global constraints |
| Unit tests | Tasks 1–4 |

## Self-review notes

- No TBD placeholders.
- `compactLoadUnit` is the single source for `kg` vs `kg per arm` fragments.
- Preview `loadLabel` gains `semantics` with default `.total` so barbell call sites stay safe.
- `makeTestExercise` defaults include dumbbell — barbell-total tests must pass `equipment: [.barbell, …]` only.

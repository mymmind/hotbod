# Physique Trend Bias Adapt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After reassess with history ≥ 2, soft-boost persisted `trainingBias` from since-last trends and show an Updated because block on Physique — without rewriting assessor priorities.

**Architecture:** Add optional `PhysiqueTrendAdaptation` on `PhysiqueAssessment`. Pure `PhysiqueTrendBiasAdapter` reorders preferred groups from current priorities using appeared / moved-up / Vision-wider signals. `assessPhysique` loads previous before save, diffs with photo ratios, adapts, then `saveActive`. Report content renders Updated because when `trendAdaptation != nil`.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XcodeGen (`xcodegen generate` after new HotBod/ files), `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-08-10-physique-trend-bias-adapt-design.md`

## Global Constraints

- iOS 17+.
- Local-first; pure adapter — no new cloud hop.
- Newest assessment remains active; avoided/injury still win in `makeWorkoutGenerationInput`.
- Prefer: “emphasized,” “moved up,” “visual trend,” “updated because.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims, inventing focus the assessor did not name.
- Soft bias only — do not hard-lock programs or rewrite priority lists.
- After new Swift files under `HotBod/`, run `xcodegen generate`.
- Simulator: use `id=EB7BE0BD-179B-4A37-9202-69D87FC47B75` if `iPhone 16 Pro` is ambiguous.
- Regression tests use `testRegression_` prefix where applicable.
- Do not alter unrelated uncommitted local changes (e.g. unrelated `Localizable.xcstrings` / pbxproj noise).

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Models/PhysiqueTrendAdaptation.swift` | Adaptation payload type |
| `HotBod/Domain/Models/PhysiqueAssessment.swift` | Optional `trendAdaptation` + decode default |
| `HotBod/Domain/Physique/PhysiqueTrendBiasAdapter.swift` | Pure boost engine |
| `HotBod/App/AppEnvironment+Physique.swift` | Adapt after assess, before save |
| `HotBod/Features/Physique/PhysiqueAssessmentReportContent.swift` | Updated because UI |
| `HotBod/App/UITestConfiguration.swift` | Seed `trendAdaptation` on newer assessment |
| `HotBod/Tests/UnitTests/PhysiqueTrendBiasAdapterTests.swift` | Adapter unit tests |
| `HotBod/Tests/UnitTests/PhysiqueArchetypeTests.swift` or decode test colocated | Decode missing field |
| `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift` | Integration regression |
| `HotBod/Tests/UITests/PhysiqueHistoryUITests.swift` | Updated because smoke |
| `HotBod/Tests/Support/FixtureBuilders.swift` | Optional `trendAdaptation` default nil |

---

### Task 1: `PhysiqueTrendAdaptation` on assessment + decode

**Files:**
- Create: `HotBod/Domain/Models/PhysiqueTrendAdaptation.swift`
- Modify: `HotBod/Domain/Models/PhysiqueAssessment.swift`
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift` (default `trendAdaptation: nil` on init call sites that use memberwise — assessment init gains optional param)
- Create or extend: `HotBod/Tests/UnitTests/PhysiqueTrendAdaptationDecodeTests.swift` (or add to `PhysiqueArchetypeTests` / `PhysiqueDomainTests`)

**Interfaces:**
- Produces:
  ```swift
  struct PhysiqueTrendAdaptation: Codable, Hashable {
      var previousAssessmentId: UUID
      var reasons: [String]
  }

  // PhysiqueAssessment gains:
  var trendAdaptation: PhysiqueTrendAdaptation? // default nil

  init(..., physiqueDirections: [PhysiqueArchetypeMatch] = [],
       trendAdaptation: PhysiqueTrendAdaptation? = nil)

  // Codable: decodeIfPresent → nil when missing
  ```

- [ ] **Step 1: Write failing decode test**

```swift
func testPhysiqueAssessmentDecodesMissingTrendAdaptationAsNil() throws {
    var assessment = FixtureBuilders.makePhysiqueAssessment()
    assessment.trendAdaptation = nil
    let data = try JSONEncoder().encode(assessment)
    // Strip key if encoder omits nil — or decode a hand-built JSON without trendAdaptation
    var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    object.removeValue(forKey: "trendAdaptation")
    let stripped = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(PhysiqueAssessment.self, from: stripped)
    XCTAssertNil(decoded.trendAdaptation)
}

func testPhysiqueAssessmentRoundTripsTrendAdaptation() throws {
    var assessment = FixtureBuilders.makePhysiqueAssessment()
    let previousId = UUID()
    assessment.trendAdaptation = PhysiqueTrendAdaptation(
        previousAssessmentId: previousId,
        reasons: ["Lats emphasized — priority appeared since last."]
    )
    let data = try JSONEncoder().encode(assessment)
    let decoded = try JSONDecoder().decode(PhysiqueAssessment.self, from: data)
    XCTAssertEqual(decoded.trendAdaptation?.previousAssessmentId, previousId)
    XCTAssertEqual(decoded.trendAdaptation?.reasons.count, 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueTrendAdaptationDecodeTests test
```

Expected: FAIL (type / property missing)

- [ ] **Step 3: Implement type + assessment field**

Add `PhysiqueTrendAdaptation.swift`. Extend `PhysiqueAssessment` init, stored property, `CodingKeys`, and `decodeIfPresent`. Synthesized `encode(to:)` is fine if the type is Codable with the new property; if custom encode is needed, encode `trendAdaptation` with `encodeIfPresent`.

Update all call sites that construct `PhysiqueAssessment` — default param `= nil` should cover most; UITest seed and Offline/Sanitizer constructors need compile check.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueTrendAdaptationDecodeTests test
```

Expected: PASS; full app target compiles.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Models/PhysiqueTrendAdaptation.swift \
  HotBod/Domain/Models/PhysiqueAssessment.swift \
  HotBod/Tests HotBod.xcodeproj/project.pbxproj
git commit -m "feat: add physique trendAdaptation field"
```

---

### Task 2: `PhysiqueTrendBiasAdapter` + unit tests

**Files:**
- Create: `HotBod/Domain/Physique/PhysiqueTrendBiasAdapter.swift`
- Create: `HotBod/Tests/UnitTests/PhysiqueTrendBiasAdapterTests.swift`

**Interfaces:**
- Consumes: `PhysiqueAssessment`, `PhysiqueAssessmentDiff`, `PhysiqueTrainingBiasMerger.preferredGroups`, `PhysiqueFocusMuscle.muscleGroups` / `displayName`
- Produces:
  ```swift
  struct PhysiqueTrendAdaptResult: Hashable {
      var assessment: PhysiqueAssessment
      var didAdapt: Bool
      var reasons: [String]
  }

  enum PhysiqueTrendBiasAdapter {
      static let maxReasons = 3

      static func adapt(
          current: PhysiqueAssessment,
          previous: PhysiqueAssessment,
          diff: PhysiqueAssessmentDiff
      ) -> PhysiqueTrendAdaptResult
  }
  ```

**Algorithm (implement exactly):**

1. `baseGroups = PhysiqueTrainingBiasMerger.preferredGroups(from: current.developmentPriorities.map(\.muscle))`
2. Collect boosts into ordered `[(MuscleGroup, reason)]` / parallel arrays; stop when `reasons.count == 3`:
   - **Appeared:** for each muscle in `diff.priorityChanges.added` (order preserved), append each of `muscle.muscleGroups` not already in boost set; add reason `"{displayName} emphasized — priority appeared since last."` (one reason per muscle, even if multiple groups).
   - **Moved up:** `previousMuscles` / `currentMuscles` from each assessment’s `developmentPriorities.map(\.muscle)`. For each muscle in `currentMuscles`, if also in previous and `currentIndex < previousIndex`, boost + reason `"{displayName} moved up in focus order."`
   - **Vision wider:** if any `diff.visionTrends` contains `"wider"` (case-insensitive), find first current priority whose `muscleGroups` contains `.shoulders`; if found, boost `.shoulders` once + reason `"{displayName} emphasized — visual trend wider."`
3. If no reasons → return `PhysiqueTrendAdaptResult(assessment: current, didAdapt: false, reasons: [])` (do not clear fields on a struct copy unless `current.trendAdaptation` was somehow set — fresh assess output should already be nil).
4. If reasons non-empty:
   - `boostGroups` = unique groups in boost encounter order
   - `reordered = boostGroups + baseGroups.filter { !boostSet.contains($0) }`
   - Mutate copy of `current`: set `trainingBias`, set `trendAdaptation = PhysiqueTrendAdaptation(previousAssessmentId: previous.id, reasons: reasons)`
   - Assert priorities array identity (same muscles/order)

Helper to build a diff for tests:

```swift
let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
// or construct PhysiqueAssessmentDiff manually for Vision-only cases
```

For Vision-only tests, either pass ratios into `PhysiqueAssessmentDiffEngine.diff` or construct:

```swift
PhysiqueAssessmentDiff(
  previousId: previous.id, currentId: current.id,
  previousDate: previous.createdAt, currentDate: current.createdAt,
  buildChanges: [], 
  priorityChanges: PhysiquePriorityChanges(added: [], removed: [], reordered: false),
  directionChanges: PhysiqueDirectionChanges(added: [], removed: []),
  visionTrends: ["Visual trend: shoulder-to-waist ratio slightly wider (3.0%)."],
  summaryLines: ["No meaningful change since last assessment."],
  hasMeaningfulChange: false
)
```

- [ ] **Step 1: Write failing tests**

```swift
final class PhysiqueTrendBiasAdapterTests: XCTestCase {
    func testAppearedPriorityBoostsBiasAndSetsAdaptation() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        previous.developmentPriorities = [
            .init(muscle: .lats, reason: "a"),
            .init(muscle: .upperChest, reason: "b")
        ]
        var current = FixtureBuilders.makePhysiqueAssessment()
        current.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "c"),
            .init(muscle: .lats, reason: "a")
        ]
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertTrue(result.didAdapt)
        XCTAssertEqual(result.assessment.developmentPriorities.map(\.muscle), current.developmentPriorities.map(\.muscle))
        XCTAssertEqual(result.assessment.trainingBias.preferredMuscleGroups.first, .shoulders)
        XCTAssertTrue(result.reasons.contains { $0.contains("Lateral Delts") && $0.contains("appeared") })
        XCTAssertEqual(result.assessment.trendAdaptation?.previousAssessmentId, previous.id)
    }

    func testMovedUpBoostsBias() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        previous.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "a"),
            .init(muscle: .lats, reason: "b")
        ]
        var current = FixtureBuilders.makePhysiqueAssessment()
        current.developmentPriorities = [
            .init(muscle: .lats, reason: "b"),
            .init(muscle: .lateralDelts, reason: "a")
        ]
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertTrue(result.didAdapt)
        XCTAssertTrue(result.reasons.contains { $0.contains("Lats") && $0.contains("moved up") })
        XCTAssertEqual(result.assessment.trainingBias.preferredMuscleGroups.first, .back)
    }

    func testVisionWiderBoostsShouldersWhenPriorityMaps() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        var current = FixtureBuilders.makePhysiqueAssessment()
        current.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "caps"),
            .init(muscle: .lats, reason: "width")
        ]
        let diff = PhysiqueAssessmentDiff(
            previousId: previous.id,
            currentId: current.id,
            previousDate: previous.createdAt,
            currentDate: current.createdAt,
            buildChanges: [],
            priorityChanges: PhysiquePriorityChanges(added: [], removed: [], reordered: false),
            directionChanges: PhysiqueDirectionChanges(added: [], removed: []),
            visionTrends: ["Visual trend: shoulder-to-waist ratio slightly wider (3.0%)."],
            summaryLines: ["No meaningful change since last assessment."],
            hasMeaningfulChange: false
        )
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertTrue(result.didAdapt)
        XCTAssertEqual(result.assessment.trainingBias.preferredMuscleGroups.first, .shoulders)
        XCTAssertTrue(result.reasons.contains { $0.contains("wider") })
    }

    func testVisionWiderWithoutShoulderPriorityDoesNotBoostFromVision() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        var current = FixtureBuilders.makePhysiqueAssessment()
        current.developmentPriorities = [
            .init(muscle: .quads, reason: "legs"),
            .init(muscle: .glutes, reason: "hips")
        ]
        // identical priorities → no appeared/moved-up
        previous.developmentPriorities = current.developmentPriorities
        let diff = PhysiqueAssessmentDiff(
            previousId: previous.id,
            currentId: current.id,
            previousDate: previous.createdAt,
            currentDate: current.createdAt,
            buildChanges: [],
            priorityChanges: PhysiquePriorityChanges(added: [], removed: [], reordered: false),
            directionChanges: PhysiqueDirectionChanges(added: [], removed: []),
            visionTrends: ["Visual trend: shoulder-to-waist ratio slightly wider (3.0%)."],
            summaryLines: ["No meaningful change since last assessment."],
            hasMeaningfulChange: false
        )
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertFalse(result.didAdapt)
        XCTAssertNil(result.assessment.trendAdaptation)
    }

    func testNoSignalsDoesNotAdapt() {
        let previous = FixtureBuilders.makePhysiqueAssessment()
        var current = previous
        current.id = UUID()
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertFalse(result.didAdapt)
        XCTAssertNil(result.assessment.trendAdaptation)
        XCTAssertEqual(result.assessment.trainingBias, current.trainingBias)
    }

    func testReasonsCapAtThree() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        previous.developmentPriorities = [
            .init(muscle: .calves, reason: "z")
        ]
        var current = FixtureBuilders.makePhysiqueAssessment()
        current.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "a"),
            .init(muscle: .lats, reason: "b"),
            .init(muscle: .upperChest, reason: "c"),
            .init(muscle: .abs, reason: "d")
        ]
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        let result = PhysiqueTrendBiasAdapter.adapt(current: current, previous: previous, diff: diff)
        XCTAssertTrue(result.didAdapt)
        XCTAssertEqual(result.reasons.count, 3)
        XCTAssertEqual(result.assessment.trendAdaptation?.reasons.count, 3)
    }
}
```

Note: `PhysiqueAssessment.id` is `let` — for `testNoSignals`, use two fixtures with identical priorities/build instead of mutating `id`.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueTrendBiasAdapterTests test
```

Expected: FAIL

- [ ] **Step 3: Implement adapter**

Keep file focused. Private helpers: `collectBoosts`, `reorderGroups`. Join rationale with `" "` from reasons.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueTrendBiasAdapterTests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Physique/PhysiqueTrendBiasAdapter.swift \
  HotBod/Tests/UnitTests/PhysiqueTrendBiasAdapterTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: add physique trend bias adapter"
```

---

### Task 3: Wire adapt into assess/save path

**Files:**
- Modify: `HotBod/App/AppEnvironment+Physique.swift`
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift`

**Interfaces:**
- Consumes: `physiqueAssessmentRepository.fetchActive()` / `fetchHistory()`, `PhysiqueAssessmentDiffEngine`, `PhysiqueTrendBiasAdapter`
- Produces: `assessPhysique` returns/persists adapted assessment when previous exists

**Wiring sketch:**

```swift
func assessPhysique(photos: [BodyProgressPhoto]? = nil) async -> PhysiqueAssessment? {
    // ... existing guards + photoList ...
    do {
        let previous = try? await physiqueAssessmentRepository.fetchActive()
        var assessment = try await physiqueAssessmentService.assess(
            photos: photoList,
            profile: profile
        )
        if let previous {
            let previousRatio = photoList.first { $0.id == previous.frontPhotoId }?.analysis?.shoulderWaistRatio
            let currentRatio = photoList.first { $0.id == assessment.frontPhotoId }?.analysis?.shoulderWaistRatio
            let diff = PhysiqueAssessmentDiffEngine.diff(
                previous: previous,
                current: assessment,
                previousFrontRatio: previousRatio,
                currentFrontRatio: currentRatio
            )
            assessment = PhysiqueTrendBiasAdapter.adapt(
                current: assessment,
                previous: previous,
                diff: diff
            ).assessment
        }
        await saveActivePhysiqueAssessment(assessment)
        // status message unchanged
        return assessment
    } catch ...
}
```

**Critical:** fetch `previous` **before** `saveActive`. Service `assess` already sanitizes; do not re-sanitize after adapt.

- [ ] **Step 1: Write failing integration test**

```swift
func testRegression_trendAdaptRewritesBiasNotPriorities() async throws {
    let repos = TestRepositories.empty()
    try await repos.userProfile.saveProfile(UserProfile.empty())

    var older = FixtureBuilders.makePhysiqueAssessment(
        createdAt: Date(timeIntervalSince1970: 1)
    )
    older.developmentPriorities = [
        .init(muscle: .lats, reason: "width"),
        .init(muscle: .upperChest, reason: "shelf")
    ]
    older.trainingBias = PhysiqueTrainingBias(
        preferredMuscleGroups: [.back, .chest],
        rationale: "old"
    )
    try await repos.physiqueAssessment.saveActive(older)

    // Stub assess to return a newer assessment with appeared lateralDelts
    var newer = FixtureBuilders.makePhysiqueAssessment(
        createdAt: Date(timeIntervalSince1970: 2)
    )
    newer.developmentPriorities = [
        .init(muscle: .lateralDelts, reason: "caps"),
        .init(muscle: .lats, reason: "width")
    ]
    newer.trainingBias = PhysiqueTrainingBias(
        preferredMuscleGroups: [.shoulders, .back],
        rationale: "from assessor"
    )
    newer.trendAdaptation = nil

    let env = AppEnvironment.makeForTests(
        repos: repos,
        physiqueAssessmentService: HybridPhysiqueAssessmentService(
            // Use existing test pattern: inject a stub/mock that returns `newer`
            // Mirror AppEnvironmentPhysiqueOrchestrationTests assess stubbing.
        )
    )
    // Prefer the same stubbing style already used in AppEnvironmentPhysiqueOrchestrationTests.
    // After assessPhysique:
    // let result = await env.assessPhysique(photos: [])
    // XCTAssertEqual(result?.developmentPriorities.map(\.muscle), [.lateralDelts, .lats])
    // XCTAssertEqual(result?.trainingBias.preferredMuscleGroups.first, .shoulders)
    // XCTAssertNotNil(result?.trendAdaptation)
    // XCTAssertTrue(result?.trendAdaptation?.reasons.contains { $0.contains("appeared") } == true)
}
```

Implement the stub using the **existing** pattern in `AppEnvironmentPhysiqueOrchestrationTests` (read that file — use `Mock` / offline service override already present). If assess requires photos/gate, seed photos or call adapter path via a test-only helper — preferred: inject service that returns `newer` for any assess request.

Also keep `testRegression_trainingBiasUsesNewestAssessmentOnly` green.

If full `assessPhysique` photo gate blocks the test, add a focused unit-style env test that:

```swift
// Extract package-visible helper if needed:
func applyTrendAdaptationIfNeeded(
  assessment: PhysiqueAssessment,
  previous: PhysiqueAssessment?,
  photos: [BodyProgressPhoto]
) -> PhysiqueAssessment
```

on `AppEnvironment` (or a small `PhysiqueAssessPipeline` enum) and unit-test that. Prefer helper extraction over brittle photo seeding — **allowed by this plan**.

Recommended helper:

```swift
enum PhysiqueAssessPipeline {
    static func applyTrendAdaptation(
        assessment: PhysiqueAssessment,
        previous: PhysiqueAssessment?,
        photos: [BodyProgressPhoto]
    ) -> PhysiqueAssessment {
        guard let previous else { return assessment }
        let previousRatio = photos.first { $0.id == previous.frontPhotoId }?.analysis?.shoulderWaistRatio
        let currentRatio = photos.first { $0.id == assessment.frontPhotoId }?.analysis?.shoulderWaistRatio
        let diff = PhysiqueAssessmentDiffEngine.diff(
            previous: previous,
            current: assessment,
            previousFrontRatio: previousRatio,
            currentFrontRatio: currentRatio
        )
        return PhysiqueTrendBiasAdapter.adapt(
            current: assessment,
            previous: previous,
            diff: diff
        ).assessment
    }
}
```

Then `assessPhysique` becomes: assess → `applyTrendAdaptation(..., previous: fetchActive(), photos:)` → save.

Integration test can call `PhysiqueAssessPipeline.applyTrendAdaptation` + `saveActive` + load, **or** full `assessPhysique` if stub allows.

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testRegression_trendAdaptRewritesBiasNotPriorities \
  test
```

Expected: FAIL

- [ ] **Step 3: Implement pipeline helper + wire `assessPhysique`**

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testRegression_trendAdaptRewritesBiasNotPriorities \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testRegression_trainingBiasUsesNewestAssessmentOnly \
  -only-testing:HotBodTests/PhysiqueTrendBiasAdapterTests \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/App/AppEnvironment+Physique.swift \
  HotBod/Domain/Physique/PhysiqueAssessPipeline.swift \
  HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: adapt training bias from physique trends on reassess"
```

---

### Task 4: Updated because UI + seed + UITest

**Files:**
- Modify: `HotBod/Features/Physique/PhysiqueAssessmentReportContent.swift`
- Modify: `HotBod/App/UITestConfiguration.swift` — set `trendAdaptation` on newer seed assessment
- Modify: `HotBod/Tests/UITests/PhysiqueHistoryUITests.swift` (or new `PhysiqueTrendAdaptUITests`)

**Interfaces:**
- Consumes: `assessment.trendAdaptation`
- UI: after Development Priorities, before Directions (or before Why today’s training — **required: after priorities, before why today**)

```swift
if let adaptation = assessment.trendAdaptation, !adaptation.reasons.isEmpty {
    updatedBecauseCard(adaptation)
}

private func updatedBecauseCard(_ adaptation: PhysiqueTrendAdaptation) -> some View {
    ForgeCard {
        VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
            ForgeSectionHeader(title: "Updated because", subtitle: nil)
            ForEach(adaptation.reasons, id: \.self) { reason in
                Text(reason)
                    .font(ForgeTypography.body)
                    .foregroundStyle(ForgeColors.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    .accessibilityIdentifier("physique.updatedBecause")
}
```

**Seed change:** After building `newer` in `seedPhysiqueHistoryIfNeeded`, either:

1. Set `trendAdaptation` explicitly (simplest for UI), **or**
2. Run `PhysiqueAssessPipeline.applyTrendAdaptation(assessment: newer, previous: older, photos: [])` before second save

Prefer (2) so seed matches production path. Older priorities `[.lats, .upperChest]` vs newer `[.lateralDelts, .lats]` → appeared lateralDelts → adapt applies without Vision.

```swift
let adapted = PhysiqueAssessPipeline.applyTrendAdaptation(
    assessment: newer,
    previous: older,
    photos: []
)
await environment.saveActivePhysiqueAssessment(older)
await environment.saveActivePhysiqueAssessment(adapted)
```

- [ ] **Step 1: Write failing UI test**

```swift
func testUpdatedBecauseVisibleWhenSeededAdaptApplies() {
    // seedPhysiqueHistory already true in PhysiqueHistoryUITests setUp
    XCTAssertTrue(
        app.otherElements["physique.updatedBecause"].waitForExistence(timeout: 10)
        || app.descendants(matching: .any)["physique.updatedBecause"].waitForExistence(timeout: 10)
    )
    XCTAssertTrue(app.staticTexts["UPDATED BECAUSE"].exists || app.staticTexts["Updated because"].exists)
}
```

Add to `PhysiqueHistoryUITests` (uses `-SeedPhysiqueHistory`).

Optional negative test can stay out of scope if seed always adapts — or add a separate launch without seed (empty) and assert identifier absent (already true on empty state).

- [ ] **Step 2: Run UI test to verify it fails**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodUITests/PhysiqueHistoryUITests/testUpdatedBecauseVisibleWhenSeededAdaptApplies \
  test
```

Expected: FAIL

- [ ] **Step 3: Implement UI + seed adapt**

- [ ] **Step 4: Run UI + adapter smoke**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodUITests/PhysiqueHistoryUITests \
  -only-testing:HotBodTests/PhysiqueTrendBiasAdapterTests \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/Physique/PhysiqueAssessmentReportContent.swift \
  HotBod/App/UITestConfiguration.swift \
  HotBod/Tests/UITests/PhysiqueHistoryUITests.swift
git commit -m "feat: show Updated because for physique trend bias"
```

---

## Self-Review Checklist

| Spec requirement | Task |
|------------------|------|
| `PhysiqueTrendAdaptation` + decode nil | Task 1 |
| Adapter appeared / moved-up / wider rules + cap 3 | Task 2 |
| Priorities unchanged | Task 2 tests |
| Adapt after assess before save; previous fetched first | Task 3 |
| Photo ratios for Vision | Task 3 pipeline |
| Updated because UI + a11y | Task 4 |
| Seed path triggers adapt | Task 4 |
| Integration regression | Task 3 |
| No Today / confirm / cadence | Out of scope |

**Placeholder scan:** Task 3 stubbing note points implementer at existing orchestration patterns — concrete helper `PhysiqueAssessPipeline.applyTrendAdaptation` is specified to avoid ambiguity.  
**Type consistency:** `PhysiqueTrendAdaptation`, `PhysiqueTrendAdaptResult`, `PhysiqueTrendBiasAdapter.adapt`, `PhysiqueAssessPipeline.applyTrendAdaptation` aligned across tasks.

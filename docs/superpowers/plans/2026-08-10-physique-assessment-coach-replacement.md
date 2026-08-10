# Physique Assessment Coach Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Coach chat tab with a Physique Focus surface that runs hybrid photo assessment, ranks development priorities, explains why today’s training, and soft-biases workout generation.

**Architecture:** Keep Progress as the photo library. Add `PhysiqueAssessment` domain + local repo. Orchestrate Vision metrics → cloud `physique-assess` or offline heuristics. Merge `trainingBias.preferredMuscleGroups` in `makeWorkoutGenerationInput`. Replace `CoachView` with `PhysiqueView`; rename the tab to Physique. Leave the chat `coach` edge function dormant.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XcodeGen (`xcodegen generate` after new Swift files under `HotBod/`), Deno tests for the edge function, `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-08-10-physique-assessment-coach-replacement-design.md`

## Global Constraints

- iOS 17+.
- Local-first; offline assessment must work without Supabase.
- No exact body-fat %; no genetic-destiny / medical claims.
- Somatotype language is descriptive shorthand only.
- Assessment bias must not bypass workout validation; avoided muscles / limitations win.
- Front + back required for full assessment; side optional (raises confidence).
- Soft bias only — no new split/program engine.
- No celebrity archetypes or after-image generation in this plan.
- Do not delete the Supabase `coach` function; stop calling it from the Physique tab.
- After creating new Swift files under `HotBod/`, run `xcodegen generate`.
- Regression tests use the `testRegression_` prefix.
- Final verification uses the `PR` configuration in `HotBod.xctestplan`.
- Do not alter unrelated uncommitted changes.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Enums/DomainEnums.swift` | `PhysiqueFocusMuscle`, `PhysiqueConfidence`, `PhysiqueAssessmentSource`, qualitative enums |
| `HotBod/Domain/Models/PhysiqueAssessment.swift` | `PhysiqueAssessment` and nested Codable structs |
| `HotBod/Domain/Physique/PhysiquePhotoGate.swift` | Front/back/side selection + quality gate |
| `HotBod/Domain/Physique/PhysiqueTrainingBiasMerger.swift` | Merge assessment bias into preferred muscles |
| `HotBod/Domain/Physique/PhysiqueFocusMuscle+MuscleGroup.swift` | Map fine focus muscles → `MuscleGroup` |
| `HotBod/Data/Repositories/RepositoryProtocols.swift` | `PhysiqueAssessmentRepository`, `PhysiqueAssessmentService` |
| `HotBod/Data/Local/LocalPhysiqueAssessmentRepository.swift` | Persist active assessment JSON |
| `HotBod/Tests/Support/InMemoryRepositories.swift` | In-memory physique repo + `TestRepositories` field |
| `HotBod/App/AppEnvironmentRepositories.swift` | Wire physique repo (local-only; not required in cloud sync v1) |
| `HotBod/App/AppEnvironment.swift` | Hold service + `activePhysiqueAssessment` |
| `HotBod/App/AppEnvironment+Physique.swift` | Assess / load / stale helpers |
| `HotBod/App/AppEnvironment+Workout.swift` | Call bias merger in `makeWorkoutGenerationInput` |
| `HotBod/Services/Physique/OfflinePhysiqueAssessmentService.swift` | Heuristic assessment |
| `HotBod/Services/Physique/RemotePhysiqueAssessmentService.swift` | Edge invoke + map/fallback |
| `HotBod/Services/Physique/HybridPhysiqueAssessmentService.swift` | Orchestrator implementing `PhysiqueAssessmentService` |
| `HotBod/Features/Physique/PhysiqueView.swift` | Tab UI (replaces Coach chat) |
| `HotBod/Features/ProteinTracker/CoachView.swift` | Delete or reduce to thin wrapper deprecated — prefer delete after call sites moved |
| `HotBod/App/AppRouter.swift` | Rename tab `coach` → `physique` |
| `HotBod/Features/Today/MainTabView.swift` | Host `PhysiqueView` |
| `HotBod/Features/Today/TodayView.swift` | Focus bias one-liner; replace Ask Coach |
| `HotBod/App/HotBodApp.swift` | Route `.coach` → Physique or rename route |
| `HotBod/App/UITestConfiguration.swift` | Launch tab `physique` |
| `supabase/functions/physique-assess/index.ts` | Cloud assessment handler |
| `supabase/functions/physique-assess/index.test.ts` | Deno tests |
| `supabase/functions/_shared/physiqueSchemas.ts` | Request/response JSON schema |
| `HotBod/Tests/UnitTests/PhysiqueDomainTests.swift` | Gate, merge, offline, mapping |
| `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift` | Assess + generation bias integration |
| `HotBod/Tests/UITests/PhysiqueUITests.swift` | Replace `CoachUITests` |
| `HotBod/Tests/UITests/BaseUITestCase.swift` | Tab order / root wait |

---

### Task 1: Domain model + focus→muscle mapping (TDD)

**Files:**
- Create: `HotBod/Domain/Models/PhysiqueAssessment.swift`
- Modify: `HotBod/Domain/Enums/DomainEnums.swift`
- Create: `HotBod/Domain/Physique/PhysiqueFocusMuscle+MuscleGroup.swift`
- Create: `HotBod/Tests/UnitTests/PhysiqueDomainTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum PhysiqueAssessmentSource: String, Codable { case cloud, onDevice }
  enum PhysiqueObservationConfidence: String, Codable { case high, medium, low, uncertain }

  enum PhysiqueFocusMuscle: String, Codable, CaseIterable, Identifiable {
      case lateralDelts, rearDelts, lats, upperChest, traps, chest, shoulders
      case biceps, triceps, abs, glutes, quads, hamstrings, calves
      var id: String { rawValue }
      var displayName: String { /* Title Case from rawValue */ }
      var muscleGroups: [MuscleGroup] { /* mapping */ }
  }

  struct PhysiqueAssessment: Identifiable, Codable, Hashable {
      let id: UUID
      var createdAt: Date
      var frontPhotoId: UUID
      var backPhotoId: UUID
      var sidePhotoId: UUID?
      var photoQuality: PhysiquePhotoQuality
      var physique: PhysiqueBuildSummary
      var muscleEntries: [PhysiqueMuscleEntry]
      var developmentPriorities: [PhysiqueDevelopmentPriority]
      var trainingBias: PhysiqueTrainingBias
      var limitations: [String]
      var confidenceBands: PhysiqueConfidenceBands
      var source: PhysiqueAssessmentSource
      var whyTodaySummary: String
  }

  struct PhysiqueTrainingBias: Codable, Hashable {
      var preferredMuscleGroups: [MuscleGroup]
      var rationale: String
  }

  // PhysiqueFocusMuscle.muscleGroups examples:
  // lateralDelts/rearDelts → [.shoulders]
  // lats → [.back]
  // upperChest → [.chest]
  // biceps/triceps stay themselves
  ```

- [ ] **Step 1: Write failing tests**

```swift
final class PhysiqueFocusMuscleMappingTests: XCTestCase {
    func testLateralDeltsMapToShoulders() {
        XCTAssertEqual(PhysiqueFocusMuscle.lateralDelts.muscleGroups, [.shoulders])
    }

    func testLatsMapToBack() {
        XCTAssertEqual(PhysiqueFocusMuscle.lats.muscleGroups, [.back])
    }

    func testUpperChestMapsToChest() {
        XCTAssertEqual(PhysiqueFocusMuscle.upperChest.muscleGroups, [.chest])
    }

    func testPhysiqueAssessmentRoundTripsCodable() throws {
        let assessment = FixtureBuilders.makePhysiqueAssessment()
        let data = try JSONEncoder().encode(assessment)
        let decoded = try JSONDecoder().decode(PhysiqueAssessment.self, from: data)
        XCTAssertEqual(decoded.id, assessment.id)
        XCTAssertEqual(decoded.trainingBias.preferredMuscleGroups, [.shoulders, .back, .chest])
        XCTAssertFalse(decoded.limitations.contains { $0.localizedCaseInsensitiveContains("body fat %") })
    }
}
```

Add `FixtureBuilders.makePhysiqueAssessment()` returning a minimal valid assessment with priorities `[lateralDelts, lats, upperChest]` and bias `[.shoulders, .back, .chest]`.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/PhysiqueFocusMuscleMappingTests test
```

Expected: FAIL — types missing.

- [ ] **Step 3: Implement enums + model + mapping**

Put fine-grained focus muscles and assessment structs in the files above. `PhysiqueBuildSummary` fields (all `String` or small enums): `overallArchetype`, `frameSize`, `shoulderToWaist`, `waist`, `torso`, `muscularity`, `leanness`. Nested types: `PhysiquePhotoQuality`, `PhysiqueMuscleEntry`, `PhysiqueDevelopmentPriority`, `PhysiqueConfidenceBands`.

Implement `muscleGroups` mapping exactly as in Interfaces. Build `trainingBias.preferredMuscleGroups` in later tasks by flattening priorities through this mapping and uniquing while preserving order.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/PhysiqueFocusMuscleMappingTests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Enums/DomainEnums.swift HotBod/Domain/Models/PhysiqueAssessment.swift \
  HotBod/Domain/Physique/PhysiqueFocusMuscle+MuscleGroup.swift \
  HotBod/Tests/UnitTests/PhysiqueDomainTests.swift HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod.xcodeproj/project.pbxproj project.yml
git commit -m "feat: add physique assessment domain model"
```

---

### Task 2: Photo gate + training bias merger (TDD)

**Files:**
- Create: `HotBod/Domain/Physique/PhysiquePhotoGate.swift`
- Create: `HotBod/Domain/Physique/PhysiqueTrainingBiasMerger.swift`
- Modify: `HotBod/Tests/UnitTests/PhysiqueDomainTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum PhysiquePhotoAngle: String, Codable { case front, side, back }

  struct PhysiquePhotoSelection: Equatable {
      var front: BodyProgressPhoto
      var back: BodyProgressPhoto
      var side: BodyProgressPhoto?
  }

  enum PhysiquePhotoGateResult: Equatable {
      case ready(PhysiquePhotoSelection)
      case missingAngles([PhysiquePhotoAngle])
      case qualityFailed([(angle: PhysiquePhotoAngle, reason: String)])
  }

  enum PhysiquePhotoGate {
      static func evaluate(
          photos: [BodyProgressPhoto],
          minimumPoseConfidence: Double = BodyPhotoVisionMetrics.minimumPoseConfidence,
          minimumFramingScore: Double = BodyPhotoVisionMetrics.minimumFramingScore
      ) -> PhysiquePhotoGateResult

      static func hasSide(_ selection: PhysiquePhotoSelection) -> Bool
      static func isStale(active: PhysiqueAssessment, photos: [BodyProgressPhoto]) -> Bool
  }

  enum PhysiqueTrainingBiasMerger {
      static func mergePreferredMuscleGroups(
          profilePreferred: [MuscleGroup],
          assessmentBias: [MuscleGroup],
          avoided: [MuscleGroup]
      ) -> [MuscleGroup]

      static func preferredGroups(from priorities: [PhysiqueFocusMuscle]) -> [MuscleGroup]
  }
  ```

Rules:
- Front = latest of `.frontRelaxed` / `.frontFlexed`; back = latest back*; side = latest side*.
- Missing front or back → `.missingAngles`.
- If a selected photo has analysis and fails pose/framing thresholds → `.qualityFailed` with reason `"Pose confidence too low"` or `"Framing score too low"`. Photos with `analysis == nil` are allowed through the gate (analyzer will run later); do not fail quality on nil analysis.
- `isStale`: true when library’s latest front or back `date` is newer than `active.createdAt` (or newer than the photo ids’ dates used in the assessment — prefer comparing latest front/back dates to `active.createdAt`).
- Merger: assessment bias first, then profile preferred, drop any in `avoided`, unique preserving order.
- `preferredGroups(from:)` flattens `muscleGroups` in priority order, unique.

- [ ] **Step 1: Write failing tests**

```swift
final class PhysiquePhotoGateTests: XCTestCase {
    func testRequiresFrontAndBack() {
        let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed)
        let result = PhysiquePhotoGate.evaluate(photos: [front])
        guard case .missingAngles(let missing) = result else {
            return XCTFail("expected missingAngles")
        }
        XCTAssertTrue(missing.contains(.back))
    }

    func testSideOptionalWhenFrontAndBackPresent() {
        let photos = [
            FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed),
            FixtureBuilders.makeBodyPhoto(pose: .backRelaxed)
        ]
        guard case .ready(let selection) = PhysiquePhotoGate.evaluate(photos: photos) else {
            return XCTFail("expected ready")
        }
        XCTAssertNil(selection.side)
    }

    func testQualityFailureOnLowPoseConfidence() {
        var front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed)
        front.analysis?.poseConfidence = 0.1
        let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed)
        let result = PhysiquePhotoGate.evaluate(photos: [front, back])
        guard case .qualityFailed(let failures) = result else {
            return XCTFail("expected qualityFailed")
        }
        XCTAssertEqual(failures.first?.angle, .front)
    }
}

final class PhysiqueTrainingBiasMergerTests: XCTestCase {
    func testAssessmentBiasPrecedesProfileAndDropsAvoided() {
        let merged = PhysiqueTrainingBiasMerger.mergePreferredMuscleGroups(
            profilePreferred: [.quads, .chest],
            assessmentBias: [.shoulders, .back, .chest],
            avoided: [.chest]
        )
        XCTAssertEqual(merged, [.shoulders, .back, .quads])
    }

    func testPrioritiesFlattenToMuscleGroups() {
        let groups = PhysiqueTrainingBiasMerger.preferredGroups(
            from: [.lateralDelts, .lats, .upperChest, .rearDelts]
        )
        XCTAssertEqual(groups, [.shoulders, .back, .chest])
    }
}
```

Add `FixtureBuilders.makeBodyPhoto(pose:analysis:date:)` helper.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/PhysiquePhotoGateTests \
  -only-testing:HotBodTests/PhysiqueTrainingBiasMergerTests test
```

Expected: FAIL — types missing.

- [ ] **Step 3: Implement gate + merger**

Implement pure static helpers with no UIKit / network dependencies.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/PhysiquePhotoGateTests \
  -only-testing:HotBodTests/PhysiqueTrainingBiasMergerTests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Physique/PhysiquePhotoGate.swift \
  HotBod/Domain/Physique/PhysiqueTrainingBiasMerger.swift \
  HotBod/Tests/UnitTests/PhysiqueDomainTests.swift HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: add physique photo gate and training bias merger"
```

---

### Task 3: Local persistence + AppEnvironment wiring for active assessment

**Files:**
- Modify: `HotBod/Data/Repositories/RepositoryProtocols.swift`
- Create: `HotBod/Data/Local/LocalPhysiqueAssessmentRepository.swift`
- Modify: `HotBod/Tests/Support/InMemoryRepositories.swift`
- Modify: `HotBod/App/AppEnvironmentRepositories.swift`
- Modify: `HotBod/App/AppEnvironment.swift`
- Create: `HotBod/App/AppEnvironment+Physique.swift`
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift` (`makeForTests`)
- Modify: `HotBod/Tests/UnitTests/RepositoryDomainTests.swift` (or PhysiqueDomainTests)
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift`

**Interfaces:**
- Produces:
  ```swift
  protocol PhysiqueAssessmentRepository: Sendable {
      func fetchActive() async throws -> PhysiqueAssessment?
      func saveActive(_ assessment: PhysiqueAssessment) async throws
      func clearActive() async throws
  }

  // AppEnvironment
  var activePhysiqueAssessment: PhysiqueAssessment?
  var physiqueAssessmentRepository: any PhysiqueAssessmentRepository { repositories.physiqueAssessment }

  func loadActivePhysiqueAssessment() async
  func saveActivePhysiqueAssessment(_ assessment: PhysiqueAssessment) async
  ```

Do **not** add physique assessment to `SyncLocalStores` in v1 (local-only).

- [ ] **Step 1: Write failing tests**

```swift
func testLocalPhysiqueAssessmentRepositoryPersistsActive() async throws {
    let repo = LocalPhysiqueAssessmentRepository(key: "physique_assessment_test_\(UUID().uuidString).json")
    let assessment = FixtureBuilders.makePhysiqueAssessment()
    try await repo.saveActive(assessment)
    let loaded = try await repo.fetchActive()
    XCTAssertEqual(loaded?.id, assessment.id)
}

func testLoadActivePhysiqueAssessmentPopulatesEnvironment() async throws {
    let repos = TestRepositories.empty()
    let assessment = FixtureBuilders.makePhysiqueAssessment()
    try await repos.physiqueAssessment.saveActive(assessment)
    let env = AppEnvironment.makeForTests(repos: repos)
    await env.loadActivePhysiqueAssessment()
    XCTAssertEqual(env.activePhysiqueAssessment?.id, assessment.id)
}
```

Extend `TestRepositories` with `physiqueAssessment: InMemoryPhysiqueAssessmentRepository`.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/LocalPhysiqueAssessmentRepositoryTests \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testLoadActivePhysiqueAssessmentPopulatesEnvironment \
  test
```

Expected: FAIL

- [ ] **Step 3: Implement repository + environment hooks**

`LocalPhysiqueAssessmentRepository` mirrors `LocalCoachRepository` with PersistenceHelper and a default key `physique_assessment.json`. Optional `key` init for tests. Wire through `AppEnvironmentRepositories` and both `AppEnvironment` inits / `makeForTests`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/LocalPhysiqueAssessmentRepositoryTests \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testLoadActivePhysiqueAssessmentPopulatesEnvironment \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Data/Repositories/RepositoryProtocols.swift \
  HotBod/Data/Local/LocalPhysiqueAssessmentRepository.swift \
  HotBod/Tests/Support/InMemoryRepositories.swift \
  HotBod/App/AppEnvironmentRepositories.swift HotBod/App/AppEnvironment.swift \
  HotBod/App/AppEnvironment+Physique.swift HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod/Tests/UnitTests/RepositoryDomainTests.swift \
  HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: persist active physique assessment"
```

---

### Task 4: Merge bias into workout generation (TDD)

**Files:**
- Modify: `HotBod/App/AppEnvironment+Workout.swift`
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift`

**Interfaces:**
- Consumes: `PhysiqueTrainingBiasMerger`, `activePhysiqueAssessment`
- Changes: `makeWorkoutGenerationInput` preferred muscle line becomes merger output

```swift
let preferred = PhysiqueTrainingBiasMerger.mergePreferredMuscleGroups(
    profilePreferred: profile.preferredMuscleGroups ?? [],
    assessmentBias: activePhysiqueAssessment?.trainingBias.preferredMuscleGroups ?? [],
    avoided: profile.avoidedMuscleGroups ?? []
)
// WorkoutGenerationInput.preferredMuscleGroups: preferred
```

Ensure `loadActivePhysiqueAssessment()` has been called during bootstrap (add call in `bootstrap()` after profile load if not already loaded).

- [ ] **Step 1: Write failing test**

```swift
func testMakeWorkoutGenerationInputMergesPhysiqueBiasAheadOfProfilePreferred() async throws {
    let repos = TestRepositories.empty()
    var profile = UserProfile.empty()
    profile.preferredMuscleGroups = [.quads]
    profile.avoidedMuscleGroups = [.chest]
    try await repos.userProfile.saveProfile(profile)

    var assessment = FixtureBuilders.makePhysiqueAssessment()
    assessment.trainingBias = PhysiqueTrainingBias(
        preferredMuscleGroups: [.shoulders, .back, .chest],
        rationale: "V-taper focus"
    )
    try await repos.physiqueAssessment.saveActive(assessment)

    let env = AppEnvironment.makeForTests(repos: repos)
    env.userProfile = profile
    await env.loadActivePhysiqueAssessment()

    let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
    XCTAssertEqual(input.preferredMuscleGroups, [.shoulders, .back, .quads])
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testMakeWorkoutGenerationInputMergesPhysiqueBiasAheadOfProfilePreferred \
  test
```

Expected: FAIL — preferred still profile-only.

- [ ] **Step 3: Implement merge in `makeWorkoutGenerationInput` + bootstrap load**

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testMakeWorkoutGenerationInputMergesPhysiqueBiasAheadOfProfilePreferred \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/App/AppEnvironment+Workout.swift HotBod/App/AppEnvironment.swift \
  HotBod/App/AppEnvironment+Physique.swift \
  HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift
git commit -m "feat: soft-bias workout generation from physique assessment"
```

---

### Task 5: Offline assessment service (TDD)

**Files:**
- Modify: `HotBod/Data/Repositories/RepositoryProtocols.swift` (add `PhysiqueAssessmentService`)
- Create: `HotBod/Services/Physique/OfflinePhysiqueAssessmentService.swift`
- Modify: `HotBod/Tests/UnitTests/PhysiqueDomainTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct PhysiqueAssessmentRequest: Sendable {
      var selection: PhysiquePhotoSelection
      var frontMetrics: BodyPhotoAnalysis
      var backMetrics: BodyPhotoAnalysis
      var sideMetrics: BodyPhotoAnalysis?
      var profile: UserProfile
  }

  protocol PhysiqueAssessmentServing: Sendable {
      func assess(_ request: PhysiqueAssessmentRequest) async throws -> PhysiqueAssessment
  }

  struct OfflinePhysiqueAssessmentService: PhysiqueAssessmentServing {
      func assess(_ request: PhysiqueAssessmentRequest) async throws -> PhysiqueAssessment
  }
  ```

Heuristic rules (deterministic):
- `source = .onDevice`
- `overallArchetype` descriptive from ratio bands, e.g. ratio ≥ 1.3 → `"Athletic build with favorable shoulder-to-waist contrast"` (never “You are a mesomorph”).
- Default priority order when front+back present: `[.lateralDelts, .lats, .upperChest, .rearDelts]` if side missing mark rearDelts confidence `.uncertain` and omit from hard ranking (use traps instead).
- Build `trainingBias.preferredMuscleGroups` via `PhysiqueTrainingBiasMerger.preferredGroups`.
- `whyTodaySummary` = short string listing top 3 mapped groups.
- `limitations` must include a visual-only disclaimer; must **not** include exact body-fat percentage claims.
- If side present, raise `photoQuality.overallConfidence` (e.g. 0.7 → 0.82).

- [ ] **Step 1: Write failing tests**

```swift
final class OfflinePhysiqueAssessmentTests: XCTestCase {
    func testProducesOnDeviceSourceAndBiasWithoutBodyFatPercent() async throws {
        let service = OfflinePhysiqueAssessmentService()
        let request = FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: false)
        let result = try await service.assess(request)
        XCTAssertEqual(result.source, .onDevice)
        XCTAssertFalse(result.trainingBias.preferredMuscleGroups.isEmpty)
        XCTAssertFalse(result.whyTodaySummary.isEmpty)
        let joined = (result.limitations + [result.physique.overallArchetype, result.whyTodaySummary]).joined(separator: " ")
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("body fat %"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("genetically"))
    }

    func testSidePhotoRaisesConfidence() async throws {
        let service = OfflinePhysiqueAssessmentService()
        let without = try await service.assess(FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: false))
        let with = try await service.assess(FixtureBuilders.makePhysiqueAssessmentRequest(includeSide: true))
        XCTAssertGreaterThan(with.photoQuality.overallConfidence, without.photoQuality.overallConfidence)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/OfflinePhysiqueAssessmentTests test
```

Expected: FAIL

- [ ] **Step 3: Implement offline service**

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/OfflinePhysiqueAssessmentTests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Data/Repositories/RepositoryProtocols.swift \
  HotBod/Services/Physique/OfflinePhysiqueAssessmentService.swift \
  HotBod/Tests/UnitTests/PhysiqueDomainTests.swift HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: add offline physique assessment heuristics"
```

---

### Task 6: Hybrid orchestrator + AppEnvironment.assessPhysique (TDD)

**Files:**
- Create: `HotBod/Services/Physique/HybridPhysiqueAssessmentService.swift`
- Create: `HotBod/Services/Physique/RemotePhysiqueAssessmentService.swift` (stub: always throws / unavailable until Task 9)
- Modify: `HotBod/App/AppEnvironment.swift` (inject `physiqueAssessmentService`)
- Modify: `HotBod/App/AppEnvironment+Physique.swift`
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift`
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum PhysiqueAssessmentError: Error, Equatable {
      case missingAngles([PhysiquePhotoAngle])
      case qualityFailed([(PhysiquePhotoAngle, String)])
      case notOnboarded
  }

  // HybridPhysiqueAssessmentService
  // init(remote: PhysiqueAssessmentServing, offline: PhysiqueAssessmentServing, analyzer: BodyPhotoAnalyzer)
  // assess(photos:profile:) async throws -> PhysiqueAssessment
  // 1) gate photos
  // 2) ensure metrics via analyzer for each selected photo lacking analysis
  // 3) try remote; on any error use offline

  // AppEnvironment
  func assessPhysique(photos: [BodyProgressPhoto]? = nil) async -> PhysiqueAssessment?
  func hasStalePhysiquePhotos(photos: [BodyProgressPhoto]? = nil) async -> Bool
  ```

Remote stub for this task:

```swift
struct UnavailablePhysiqueAssessmentService: PhysiqueAssessmentServing {
    func assess(_ request: PhysiqueAssessmentRequest) async throws -> PhysiqueAssessment {
        throw URLError(.notConnectedToInternet)
    }
}
```

`assessPhysique` flow:
1. Require onboarded profile.
2. Fetch photos if nil.
3. Call hybrid service.
4. On gate errors, set a short `physiqueStatusMessage` (new optional `String?` on env) and return nil.
5. On success, `saveActivePhysiqueAssessment`, clear status / set “Using on-device estimate.” when `source == .onDevice`.

- [ ] **Step 1: Write failing tests**

```swift
func testAssessPhysiquePersistsOnDeviceWhenRemoteUnavailable() async throws {
    let repos = TestRepositories.empty()
    var profile = UserProfile.empty()
    profile.photoTrackingEnabled = true
    try await repos.userProfile.saveProfile(profile)
    try await repos.userProfile.setOnboardingComplete(true)

    let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, userId: profile.id)
    let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed, userId: profile.id)
    try await repos.bodyProgress.savePhoto(front)
    try await repos.bodyProgress.savePhoto(back)

    let env = AppEnvironment.makeForTests(
        repos: repos,
        physiqueAssessmentService: HybridPhysiqueAssessmentService(
            remote: UnavailablePhysiqueAssessmentService(),
            offline: OfflinePhysiqueAssessmentService(),
            analyzer: MockBodyPhotoAnalyzer()
        )
    )
    env.userProfile = profile
    env.hasCompletedOnboarding = true

    let result = await env.assessPhysique(photos: [front, back])
    XCTAssertEqual(result?.source, .onDevice)
    XCTAssertEqual(env.activePhysiqueAssessment?.id, result?.id)
}

func testAssessPhysiqueBlockedWithoutBackPhoto() async throws {
    let repos = TestRepositories.empty()
    let profile = UserProfile.empty()
    let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, userId: profile.id)
    try await repos.bodyProgress.savePhoto(front)
    let env = AppEnvironment.makeForTests(repos: repos)
    env.userProfile = profile
    env.hasCompletedOnboarding = true
    let result = await env.assessPhysique(photos: [front])
    XCTAssertNil(result)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testAssessPhysiquePersistsOnDeviceWhenRemoteUnavailable \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testAssessPhysiqueBlockedWithoutBackPhoto \
  test
```

Expected: FAIL

- [ ] **Step 3: Implement hybrid + env API; default production service = hybrid(remote stub or BackendServices factory returning unavailable until Task 9)**

Extend `makeForTests` with `physiqueAssessmentService:` parameter defaulting to hybrid(unavailable remote, offline, mock analyzer).

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testAssessPhysiquePersistsOnDeviceWhenRemoteUnavailable \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testAssessPhysiqueBlockedWithoutBackPhoto \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Services/Physique HotBod/App/AppEnvironment.swift \
  HotBod/App/AppEnvironment+Physique.swift HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift \
  HotBod/Data/Remote/BackendServices.swift HotBod.xcodeproj/project.pbxproj
git commit -m "feat: orchestrate hybrid physique assessment"
```

---

### Task 7: Physique tab UI replacing Coach chat

**Files:**
- Create: `HotBod/Features/Physique/PhysiqueView.swift`
- Modify: `HotBod/App/AppRouter.swift` (rename `MainTab.coach` → `.physique`, title `"Physique"`, icon `figure.stand` or `camera.metering.center.weighted`)
- Modify: `HotBod/Features/Today/MainTabView.swift`
- Modify: `HotBod/App/HotBodApp.swift`
- Modify: `HotBod/Features/Today/TodayView.swift` (remove chat push to CoachView; temporary link to Physique tab OK)
- Modify: `HotBod/App/UITestConfiguration.swift` (`"coach"` launch arg → `"physique"`; keep `"coach"` as alias mapping to `.physique` for one release if cheap)
- Delete or stop compiling chat UI from `CoachView.swift` once unused
- Modify: `HotBod/Tests/UITests/BaseUITestCase.swift` tab order

**Interfaces:**
- `PhysiqueView` states: empty / needs retake / assessing / report
- Accessibility: `physique.root`, `physique.reassess`, `physique.empty`, priority rows `physique.priority.<rawValue>`
- Eyebrow: `Online` if `source == .cloud` else `On-device estimate`
- Subtitle: `"Photo assessment and training focus."`
- Reuse `BodyPhotoAddPhotoModifier` / Progress import patterns for add-photo CTAs (front/back/side)
- On appear: `loadActivePhysiqueAssessment()`; if ready photos and no active assessment, offer primary **Assess**
- Stale banner when `hasStalePhysiquePhotos()`

Copy (exact):
- Empty: `"Add front and back photos to get a focus plan."`
- Missing back: `"Add a back photo to unlock a full assessment."`
- Side CTA: `"Add side for higher confidence"`
- Why section title: `"Why today’s training"`
- No chat input, no suggestion chips, no Apply workout card

- [ ] **Step 1: Write failing UI test shell**

Create `HotBod/Tests/UITests/PhysiqueUITests.swift`:

```swift
final class PhysiqueUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "physique"
    try super.setUpWithError()
  }

  func testPhysiqueTabEmptyState() {
    XCTAssertTrue(app.otherElements["physique.root"].waitForExistence(timeout: 10)
      || app.staticTexts["Physique"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      app.staticTexts["Add front and back photos to get a focus plan."].waitForExistence(timeout: 8)
    )
    XCTAssertFalse(app.staticTexts["Ask your coach"].exists)
  }
}
```

- [ ] **Step 2: Run UI test to verify it fails**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodUITests/PhysiqueUITests/testPhysiqueTabEmptyState test
```

Expected: FAIL

- [ ] **Step 3: Implement PhysiqueView + tab rename; remove Coach chat from tab**

Update all `MainTab` / launch-tab references. Replace Today’s `"Ask Coach"` button with `"Physique focus"` that sets `router.selectedTab = .physique` (no chat push). Remove `navigationDestination` to `CoachView` if present.

Keep `AppRoute.coach` as `.physique` rename **or** map `.coach` overlay to `PhysiqueView` for compatibility — prefer rename route case to `physique` and update `HotBodApp`.

- [ ] **Step 4: Run UI test to verify it passes**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodUITests/PhysiqueUITests/testPhysiqueTabEmptyState test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/Physique HotBod/App/AppRouter.swift HotBod/Features/Today/MainTabView.swift \
  HotBod/App/HotBodApp.swift HotBod/Features/Today/TodayView.swift \
  HotBod/App/UITestConfiguration.swift HotBod/Tests/UITests \
  HotBod/Features/ProteinTracker/CoachView.swift HotBod.xcodeproj/project.pbxproj
git commit -m "feat: replace Coach tab with Physique assessment UI"
```

---

### Task 8: Today focus one-liner + report “why today”

**Files:**
- Modify: `HotBod/Features/Today/TodayView.swift`
- Modify: `HotBod/Features/Physique/PhysiqueView.swift`
- Modify: `HotBod/Tests/UITests/PhysiqueUITests.swift`
- Modify: `HotBod/Tests/UITests/Pages/TodayPage.swift`

**Interfaces:**
- Today shows when `activePhysiqueAssessment != nil`:
  - Accessibility id `today.physiqueFocus`
  - Text: `"Focus bias: "` + top 3 `developmentPriorities` display names joined by `", "`
  - Tap → `selectedTab = .physique`
- Physique report section binds `assessment.whyTodaySummary` (3–5 lines max; truncate in view if longer)
- Update `TodayPage.askCoachButton` → `physiqueFocusButton` labeled `"Physique focus"` or the focus bias control

- [ ] **Step 1: Write failing unit/UI assertions**

Add unit test for a small pure formatter if extracted:

```swift
enum PhysiqueFocusCopy {
    static func todayBiasLine(from assessment: PhysiqueAssessment, limit: Int = 3) -> String {
        let names = assessment.developmentPriorities.prefix(limit).map(\.muscle.displayName)
        return "Focus bias: " + names.joined(separator: ", ")
    }
}
```

```swift
func testTodayBiasLineListsTopPriorities() {
    let assessment = FixtureBuilders.makePhysiqueAssessment()
    let line = PhysiqueFocusCopy.todayBiasLine(from: assessment)
    XCTAssertTrue(line.hasPrefix("Focus bias:"))
    XCTAssertTrue(line.contains("Lateral Delts") || line.contains("Lateral delts") || line.localizedCaseInsensitiveContains("lateral"))
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/PhysiqueFocusCopyTests test
```

Expected: FAIL

- [ ] **Step 3: Implement copy helper + Today/Physique UI wiring**

Seed UITest mock path: when `-MockAI` (already used), `assessPhysique` offline path should work once photos exist — for Today line, integration test with `makeForTests` is enough; UI test optional if photo seeding in UI tests is hard — then cover Today line with unit + orchestration only and UI for Physique empty/report with injected state if available.

If UI tests cannot seed photos easily, add:

```swift
func testRegression_coachChatEntryPointsRemovedFromPhysiqueTab() {
    // on physique tab
    XCTAssertFalse(app.textFields["coach.input"].exists)
    XCTAssertFalse(app.staticTexts["Ask your coach"].exists)
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/PhysiqueFocusCopyTests \
  -only-testing:HotBodUITests/PhysiqueUITests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/Today/TodayView.swift HotBod/Features/Physique/PhysiqueView.swift \
  HotBod/Domain/Physique/PhysiqueFocusCopy.swift HotBod/Tests \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: surface physique focus rationale on Today"
```

---

### Task 9: Cloud `physique-assess` edge + remote client

**Files:**
- Create: `supabase/functions/_shared/physiqueSchemas.ts`
- Create: `supabase/functions/physique-assess/index.ts`
- Create: `supabase/functions/physique-assess/index.test.ts`
- Modify: `HotBod/Services/Physique/RemotePhysiqueAssessmentService.swift`
- Modify: `HotBod/Data/Remote/BackendServices.swift`
- Modify: `HotBod/Tests/UnitTests/PhysiqueDomainTests.swift` (mapper / sanitize tests)

**Interfaces:**
- Edge request body:
  ```ts
  {
    metrics: { front: BodyPhotoAnalysisLike, back: BodyPhotoAnalysisLike, side?: ... },
    anglesAvailable: ("front"|"side"|"back")[],
    profile: { goal, experienceLevel, limitations },
    // images optional base64 thumbnails — v1 may omit images and use metrics-only to reduce payload
  }
  ```
- Edge response: JSON matching Swift `PhysiqueAssessment` fields needed for mapping (or a lean DTO `RemotePhysiqueAssessmentPayload` mapped client-side).
- Auth + `OPENAI_API_KEY` gates mirror `coach/index.ts`.
- System prompt must forbid exact body-fat %, medical diagnosis, genetic destiny claims; require confidence fields; require structured JSON schema (`strict: true`).
- Client `RemotePhysiqueAssessmentService`:
  - If `!auth.isAvailable || currentUserId() == nil` → throw (hybrid falls back).
  - Invoke `"physique-assess"`.
  - Sanitize: drop unknown `PhysiqueFocusMuscle` raw values; demote/remove `.uncertain` from hard priority list; rebuild `trainingBias` via merger from remaining priorities.
  - Never log photo bytes or full response body.

- [ ] **Step 1: Write failing Deno + Swift sanitize tests**

Deno (auth/key), Swift:

```swift
func testRemotePayloadMapperDropsUnknownMusclesAndUncertainPriorities() {
    let payloadPriorities = ["lateralDelts", "not_a_muscle", "rearDelts"]
    let confidences = ["high", "high", "uncertain"]
    let muscles = PhysiqueAssessmentSanitizer.priorities(
        rawIds: payloadPriorities,
        confidences: confidences
    )
    XCTAssertEqual(muscles, [.lateralDelts])
}
```

- [ ] **Step 2: Run Deno tests / Swift tests to verify failure**

```bash
cd supabase/functions && deno test physique-assess/index.test.ts
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/PhysiqueAssessmentSanitizerTests test
```

Expected: FAIL until implemented.

- [ ] **Step 3: Implement schema, handler, sanitizer, remote service, BackendServices.makePhysiqueAssessmentService**

Wire production `AppEnvironment` default hybrid to use remote when Supabase configured (same pattern as `makeAIWorkoutService`).

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd supabase/functions && deno test physique-assess/index.test.ts
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HotBodTests/PhysiqueAssessmentSanitizerTests \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testAssessPhysiquePersistsOnDeviceWhenRemoteUnavailable \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/_shared/physiqueSchemas.ts supabase/functions/physique-assess \
  HotBod/Services/Physique HotBod/Data/Remote/BackendServices.swift \
  HotBod/Tests/UnitTests/PhysiqueDomainTests.swift HotBod.xcodeproj/project.pbxproj
git commit -m "feat: add cloud physique-assess edge function and client"
```

---

### Task 10: Retire Coach UI tests + PR verification

**Files:**
- Delete: `HotBod/Tests/UITests/CoachUITests.swift` (replaced by PhysiqueUITests)
- Modify: `HotBod.xctestplan` if it references CoachUITests by name
- Modify: `HotBod/Tests/UITests/Pages/TodayPage.swift`
- Modify: README Phase 4 blurb only if it claims Coach chat is the primary AI surface (short note: Physique assessment is primary; chat coach dormant)

**Interfaces:**
- `testRegression_coachChatEntryPointsRemovedFromPhysiqueTab` must remain
- No remaining production call sites that present chat `CoachView` as a tab

- [ ] **Step 1: Grep for dead chat UI entry points**

```bash
rg -n "Ask your coach|coach.input|CoachView|Ask Coach" HotBod --glob '*.swift'
```

Expected: only dormant services / subscription product strings (optional cleanup) or none in Features/.

- [ ] **Step 2: Fix any remaining Feature-layer chat entry points**

- [ ] **Step 3: Run PR test plan**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -testPlan HotBod -only-testing:HotBodTests -only-testing:HotBodUITests/PhysiqueUITests \
  test
```

If `-testPlan` configuration name differs, use the repo’s documented PR configuration from `HotBod.xctestplan`.

Also:

```bash
cd supabase/functions && deno test physique-assess/index.test.ts
```

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add HotBod/Tests HotBod.xctestplan README.md HotBod/Features HotBod.xcodeproj/project.pbxproj
git commit -m "test: migrate Coach UI coverage to Physique assessment"
```

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| Replace Coach tab with Physique Focus | 7 |
| Front+back required, side optional | 2, 5, 6 |
| Hybrid Vision + cloud / offline | 5, 6, 9 |
| Structured assessment + priorities | 1, 5, 9 |
| Why today’s training UI | 7, 8 |
| Soft bias into generator | 2, 4 |
| Avoided muscles win | 2, 4 |
| No BF% / genetic destiny | 5, 9 |
| Stale photos banner | 2, 7 |
| Today one-liner | 8 |
| Persist active assessment | 3 |
| Edge function + Deno tests | 9 |
| UI/integration/unit tests | 1–10 |
| Leave `coach` function dormant | 7, 10 (no delete) |
| No celebs / after-images | Global non-goal |

## Type consistency notes

- Protocol name in code: `PhysiqueAssessmentServing` (avoid clashing with a concrete `PhysiqueAssessmentService` type name if both exist — hybrid type is `HybridPhysiqueAssessmentService`).
- Tab enum case: `.physique` (not `.coach`).
- Fine muscles use `PhysiqueFocusMuscle`; generator bias uses `[MuscleGroup]` only.
- Repository: `PhysiqueAssessmentRepository` with `fetchActive` / `saveActive` / `clearActive`.

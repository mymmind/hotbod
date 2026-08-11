# Physique Front-Only Assessment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow Physique assessment with a front photo only, make back optional end-to-end (client + edge), and soft-upsell back/side for better results.

**Architecture:** Change `PhysiquePhotoGate` so only front is required; optional angles that fail quality are dropped. Thread `back: BodyProgressPhoto?` / `backMetrics: BodyPhotoAnalysis?` / `backPhotoId: UUID?` through selection, request, assessment, hybrid/offline/remote, and `physiqueSchemas` validation. Physique UI replaces hard-gate copy with helpers + `physique.anglesUpsell` on the active report.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XcodeGen, Deno (`supabase/functions`), `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-08-11-physique-front-only-assessment-design.md`

## Global Constraints

- iOS 17+.
- Prefer: “fuller read,” “better results,” “add back and side.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims, inventing back metrics when absent.
- Optional angles that fail quality are omitted, not fatal.
- Edge must accept front-only; if `"back"` is in `anglesAvailable`, back metrics remain required.
- After new Swift files under `HotBod/`, run `xcodegen generate`; if `objectVersion` / `DEVELOPMENT_TEAM` churn, restore baselines and add refs manually.
- Simulator: `id=EB7BE0BD-179B-4A37-9202-69D87FC47B75` if needed.
- Regression tests use `testRegression_` where applicable.
- Do not alter unrelated uncommitted local changes (e.g. stray plan checkbox churn / Localizable noise).

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Physique/PhysiquePhotoGate.swift` | Front-only ready; optional back/side; stale rules |
| `HotBod/Domain/Models/PhysiqueAssessment.swift` | `backPhotoId: UUID?` |
| `HotBod/Data/Repositories/RepositoryProtocols.swift` | `backMetrics` optional on request |
| `HotBod/Services/Physique/HybridPhysiqueAssessmentService.swift` | Optional back analysis path |
| `HotBod/Services/Physique/OfflinePhysiqueAssessmentService.swift` | Front-only confidence + limitations |
| `HotBod/Services/Physique/RemotePhysiqueAssessmentService.swift` | Optional back payload / angles |
| `HotBod/Domain/Physique/PhysiqueAssessmentSanitizer.swift` | Nil-safe `backPhotoId` |
| `supabase/functions/_shared/physiqueSchemas.ts` | Front-only validation |
| `supabase/functions/physique-assess/index.test.ts` | Deno coverage |
| `HotBod/Features/Physique/PhysiqueView.swift` | Copy + upsell |
| `HotBod/App/AppEnvironment+Physique.swift` | Status strings |
| `HotBod/App/UITestConfiguration.swift` | Front-only / full-angle seeds |
| `HotBod/Tests/...` | Gate, decode, offline, orchestration, UITests |
| `HotBod/Tests/Support/FixtureBuilders.swift` | Optional back fixtures |

---

### Task 1: Gate + optional `backPhotoId` model

**Files:**
- Modify: `HotBod/Domain/Physique/PhysiquePhotoGate.swift`
- Modify: `HotBod/Domain/Models/PhysiqueAssessment.swift`
- Modify: `HotBod/Tests/UnitTests/PhysiqueDomainTests.swift` (`PhysiquePhotoGateTests` + decode)
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift` (`backPhotoId: UUID? = UUID()` default still OK)

**Interfaces:**
- Produces:
  ```swift
  struct PhysiquePhotoSelection: Equatable {
      var front: BodyProgressPhoto
      var back: BodyProgressPhoto?   // was non-optional
      var side: BodyProgressPhoto?
  }

  // PhysiqueAssessment
  var backPhotoId: UUID?  // decodeIfPresent → nil

  // PhysiquePhotoGate.evaluate:
  // - missing front only → .missingAngles([.front])
  // - front OK, no back → .ready(back: nil)
  // - back present but quality fail → omit back, still .ready if front OK
  // - front quality fail → .qualityFailed (blocks)

  // isStale: newer front OR (backPhotoId != nil && newer back)
  ```

- [ ] **Step 1: Rewrite failing gate + decode tests**

Replace `testRequiresFrontAndBack` and add:

```swift
func testFrontOnlyIsReady() {
    let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed)
    guard case .ready(let selection) = PhysiquePhotoGate.evaluate(photos: [front]) else {
        return XCTFail("expected ready")
    }
    XCTAssertEqual(selection.front.id, front.id)
    XCTAssertNil(selection.back)
    XCTAssertNil(selection.side)
}

func testMissingFrontOnly() {
    let back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed)
    let result = PhysiquePhotoGate.evaluate(photos: [back])
    guard case .missingAngles(let missing) = result else {
        return XCTFail("expected missingAngles")
    }
    XCTAssertEqual(missing, [.front])
}

func testBackQualityFailureOmitsBackButStaysReady() {
    let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed)
    var back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed)
    back.analysis?.poseConfidence = 0.1
    guard case .ready(let selection) = PhysiquePhotoGate.evaluate(photos: [front, back]) else {
        return XCTFail("expected ready")
    }
    XCTAssertNil(selection.back)
}

func testStaleIgnoresBackWhenAssessmentHasNoBackPhotoId() {
    var assessment = FixtureBuilders.makePhysiqueAssessment(backPhotoId: nil)
    assessment.createdAt = Date().addingTimeInterval(-1000)
    let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, date: assessment.createdAt.addingTimeInterval(-10))
    var back = FixtureBuilders.makeBodyPhoto(pose: .backRelaxed, date: Date())
    // Ensure makeBodyPhoto accepts date or set `.date` after
    XCTAssertFalse(PhysiquePhotoGate.isStale(active: assessment, photos: [front, back]))
}

func testPhysiqueAssessmentDecodesMissingBackPhotoIdAsNil() throws {
    var assessment = FixtureBuilders.makePhysiqueAssessment(backPhotoId: nil)
    let data = try JSONEncoder().encode(assessment)
    var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    object.removeValue(forKey: "backPhotoId")
    let stripped = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(PhysiqueAssessment.self, from: stripped)
    XCTAssertNil(decoded.backPhotoId)
}
```

Update existing tests that force-unwrap `selection.back.id` to use optional binding. Keep `testSideOptionalWhenFrontAndBackPresent` / side quality tests valid with optional back.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiquePhotoGateTests \
  -only-testing:HotBodTests/PhysiqueFocusMuscleMappingTests/testPhysiqueAssessmentDecodesMissingBackPhotoIdAsNil \
  test
```

(If decode test lives in `PhysiqueFocusMuscleMappingTests` or a new method on that class / `PhysiquePhotoGateTests`, adjust `-only-testing` accordingly.)

Expected: FAIL

- [ ] **Step 3: Implement gate + model**

`PhysiquePhotoSelection.back` → optional.

`evaluate`:
1. If no front → `.missingAngles([.front])`
2. If front quality fail → `.qualityFailed` (front only in required failures)
3. Resolve optional back: if present and quality OK keep; if quality fail omit
4. Same for side (already)
5. Return `.ready(PhysiquePhotoSelection(front:back:side:))`

`regate`: only front quality is required-failure; back quality fail → set `back = nil` and continue ready (mirror side).

`isStale`:
```swift
if let latestFront = ..., latestFront.date > active.createdAt { return true }
if let backId = active.backPhotoId,
   let latestBack = ...,
   latestBack.date > active.createdAt {
    return true
}
return false
```

`PhysiqueAssessment.backPhotoId: UUID?` — init param optional; `decodeIfPresent`; `encodeIfPresent`.

Fix all compile breakages that assume non-optional `back` / `backPhotoId` **only as needed to compile this task** — prefer leaving service compile fixes for Task 2 if the project won’t build otherwise; if Xcode won’t compile the app target, apply minimal optional chaining so Task 1 tests can run (services may still be wrong until Task 2).

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiquePhotoGateTests \
  -only-testing:HotBodTests/PhysiqueFocusMuscleMappingTests test
```

Expected: PASS for updated gate/decode tests (other mapping tests should still pass).

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Physique/PhysiquePhotoGate.swift \
  HotBod/Domain/Models/PhysiqueAssessment.swift \
  HotBod/Tests/UnitTests/PhysiqueDomainTests.swift \
  HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod.xcodeproj
git commit -m "feat: allow front-only physique photo gate"
```

---

### Task 2: Assess pipeline + edge front-only

**Files:**
- Modify: `HotBod/Data/Repositories/RepositoryProtocols.swift` (`PhysiqueAssessmentRequest.backMetrics`)
- Modify: `HotBod/Services/Physique/HybridPhysiqueAssessmentService.swift`
- Modify: `HotBod/Services/Physique/OfflinePhysiqueAssessmentService.swift`
- Modify: `HotBod/Services/Physique/RemotePhysiqueAssessmentService.swift` (`PhysiqueAssessMetricsPayload.back` optional; `anglesAvailable`)
- Modify: `HotBod/Domain/Physique/PhysiqueAssessmentSanitizer.swift`
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift` (`makePhysiqueAssessmentRequest` front-only helper)
- Modify: `HotBod/Tests/UnitTests/PhysiqueDomainTests.swift` / `OfflinePhysiqueAssessmentTests`
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift` (mock assess assigning `backPhotoId`)
- Modify: `supabase/functions/_shared/physiqueSchemas.ts`
- Modify: `supabase/functions/physique-assess/index.test.ts`

**Interfaces:**
- Consumes: optional `selection.back`
- Produces:
  ```swift
  struct PhysiqueAssessmentRequest {
      var backMetrics: BodyPhotoAnalysis?  // optional
      ...
  }

  // Hybrid PreparedMetrics.backMetrics: BodyPhotoAnalysis?
  // Offline: anglesAvailable reflects present angles; limitation when back missing
  // Remote payload back optional; angles omit "back" when nil

  // validatePhysiqueRequest:
  // - require metrics.front + angles includes "front"
  // - if angles includes "back" → require metrics.back
  // - else metrics.back optional
  ```

- [ ] **Step 1: Write failing offline + orchestration + Deno tests**

```swift
func testFrontOnlyOfflineAssessSucceedsWithNilBackPhotoId() async throws {
    let service = OfflinePhysiqueAssessmentService()
    let request = FixtureBuilders.makePhysiqueAssessmentRequest(includeBack: false, includeSide: false)
    let result = try await service.assess(request)
    XCTAssertNil(result.backPhotoId)
    XCTAssertEqual(result.photoQuality.anglesAvailable, ["front"])
    XCTAssertTrue(result.limitations.contains { $0.localizedCaseInsensitiveContains("back") })
    XCTAssertLessThan(
        result.photoQuality.overallConfidence,
        try await service.assess(FixtureBuilders.makePhysiqueAssessmentRequest(includeBack: true)).photoQuality.overallConfidence
    )
}

@MainActor
func testRegression_assessPhysiqueFrontOnlySucceeds() async {
    // env with mock assess / hybrid offline path and only a front photo in repos
    let result = await env.assessPhysique(photos: [front])
    XCTAssertNotNil(result)
    XCTAssertNil(result?.backPhotoId)
}
```

Update `FixtureBuilders.makePhysiqueAssessmentRequest` to take `includeBack: Bool = true` (and when false, `selection.back = nil`, `backMetrics = nil`).

Deno — replace missing-back-400 test:

```ts
Deno.test("handlePhysiqueAssessRequest accepts front-only metrics", async () => {
  // auth stubs like other tests; body with metrics.front only, anglesAvailable: ["front"]
  // expect 200 (or whatever success path existing happy-path test uses — mirror sampleRequest but omit back)
});

Deno.test("handlePhysiqueAssessRequest returns 400 when back listed without metrics", async () => {
  const body = sampleRequest();
  delete body.metrics.back;
  body.anglesAvailable = ["front", "back"];
  // expect 400 matching /back/i
});
```

- [ ] **Step 2: Run client tests (expect fail) + Deno**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/OfflinePhysiqueAssessmentTests \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests/testRegression_assessPhysiqueFrontOnlySucceeds \
  test

cd supabase/functions && deno test physique-assess/index.test.ts _shared/physiqueSchemas.ts 2>/dev/null || \
  deno test --allow-env --allow-net physique-assess/index.test.ts
```

Use the repo’s existing Deno invoke pattern from prior physique plans if different.

- [ ] **Step 3: Implement pipeline + edge**

Hybrid `ensureMetrics` / `regatePrepared`:
- Analyze back only if `selection.back != nil`
- `backMetrics` optional; guard only `frontMetrics`
- Persist analysis for back only when present

Offline:
- `backPhotoId: request.selection.back?.id`
- `anglesAvailable`: start `["front"]`; append `"back"` / `"side"` when metrics present
- `overallConfidence` / `lightingQuality`: average only present scores; subtract a small nudge when back missing (e.g. `* 0.92` or `-0.05`, clamped) — keep side boost behavior
- Limitations: if back missing append `"Back photo missing; posterior detail may be less reliable."` (and keep existing side missing note)

Remote:
- `PhysiqueAssessMetricsPayload.back: BodyPhotoAnalysis?`
- Build `angles` from present metrics only

Sanitizer: `backPhotoId: request.selection.back?.id`

Edge `validatePhysiqueRequest`:

```ts
if (!body.metrics?.front) {
  return "metrics.front is required.";
}
if (!Array.isArray(body.anglesAvailable) || body.anglesAvailable.length === 0) {
  return "anglesAvailable is required.";
}
if (!body.anglesAvailable.includes("front")) {
  return "anglesAvailable must include front.";
}
if (body.anglesAvailable.includes("back") && !body.metrics?.back) {
  return "metrics.back is required when anglesAvailable includes back.";
}
```

Fix TypeScript types for optional `metrics.back` if needed.

Update mock assess in orchestration tests: `result.backPhotoId = request.selection.back?.id`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/OfflinePhysiqueAssessmentTests \
  -only-testing:HotBodTests/PhysiquePhotoGateTests \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests \
  test

deno test --allow-env --allow-net supabase/functions/physique-assess/index.test.ts
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Data/Repositories/RepositoryProtocols.swift \
  HotBod/Services/Physique/HybridPhysiqueAssessmentService.swift \
  HotBod/Services/Physique/OfflinePhysiqueAssessmentService.swift \
  HotBod/Services/Physique/RemotePhysiqueAssessmentService.swift \
  HotBod/Domain/Physique/PhysiqueAssessmentSanitizer.swift \
  HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod/Tests/UnitTests/PhysiqueDomainTests.swift \
  HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift \
  supabase/functions/_shared/physiqueSchemas.ts \
  supabase/functions/physique-assess/index.test.ts
git commit -m "feat: assess physique with optional back metrics"
```

---

### Task 3: UI upsell + status copy + UITest

**Files:**
- Modify: `HotBod/Features/Physique/PhysiqueView.swift`
- Modify: `HotBod/App/AppEnvironment+Physique.swift`
- Modify: `HotBod/App/UITestConfiguration.swift`
- Modify: `HotBod/Tests/UITests/BaseUITestCase.swift`
- Create: `HotBod/Tests/UITests/PhysiqueAnglesUpsellUITests.swift` (or extend an existing Physique UITest file)

**Interfaces:**
- Consumes: gate ready front-only; `assessment.backPhotoId`; photo helpers
- Produces: a11y `physique.anglesUpsell`; launch flag `-SeedPhysiqueFrontOnly` (and reuse full history/illustration seeds for “no upsell” when back present)

- [ ] **Step 1: Write failing UITest**

```swift
final class PhysiqueAnglesUpsellUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "physique"
    seedPhysiqueFrontOnly = true  // new flag
    try super.setUpWithError()
  }

  func testAnglesUpsellVisibleForFrontOnlyAssessment() {
    XCTAssertTrue(
      app.descendants(matching: .any)["physique.anglesUpsell"].waitForExistence(timeout: 10)
    )
  }
}

final class PhysiqueAnglesUpsellHiddenUITests: BaseUITestCase {
  override func setUpWithError() throws {
    launchTab = "physique"
    seedPhysiqueHistory = true // existing seed has front+back
    try super.setUpWithError()
  }

  func testAnglesUpsellHiddenWhenBackPresent() {
    XCTAssertFalse(
      app.descendants(matching: .any)["physique.anglesUpsell"].waitForExistence(timeout: 3)
    )
  }
}
```

Seed helper: save assessment with `backPhotoId: nil`, front photo present (and optionally skip back photo files). Wire `-SeedPhysiqueFrontOnly` like other seeds in `applyDeepLinks`.

- [ ] **Step 2: Run UITest to verify fail**

```bash
xcodegen generate  # if new test file
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodUITests/PhysiqueAnglesUpsellUITests test
```

Expected: FAIL (missing identifier)

- [ ] **Step 3: Implement UI + copy**

`PhysiqueView`:
- `nil` gate → `emptySection(missingAngles: [.front])`
- `emptyMessage`: if missing front → “Add a front photo to get a focus plan.”; else unused
- `readyToAssessSection`: “Front photo ready.” + helper text “Add back and side photos for a fuller read.” + Add Back / Add Side when missing + Assess CTA
- `photoActionButtons`: show Add Front when needed; show Add Back / Add Side as optional whenever those angles missing (not only when gate lists them)
- `reportSection`: replace lone “Add side…” with unified upsell card when `!hasBackPhoto || !hasSidePhoto`:

```swift
private var anglesUpsellCard: some View {
    ForgeCard {
        VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
            Text("Add back and side photos for better results.")
                .font(ForgeTypography.body)
                .foregroundStyle(ForgeColors.muted)
            if !hasBackPhoto {
                ForgeButton(title: "Add Back Photo", style: .secondary) { presentAddPhoto(for: .back) }
            }
            if !hasSidePhoto {
                ForgeButton(title: "Add Side Photo", style: .secondary) { presentAddPhoto(for: .side) }
            }
        }
    }
    .accessibilityIdentifier("physique.anglesUpsell")
}
```

Show when assessment present and (`!hasBackPhoto || !hasSidePhoto`). Prefer checking photos in library (not only `assessment.backPhotoId`) so adding a back photo clears the upsell even before reassess — **or** key off assessment linkage: spec says “when back and/or side missing” in report — use photo library presence for CTAs (matches current side button behavior).

`AppEnvironment+Physique` status messages:
- Drop “Add a back photo to unlock…” hard gate
- `missingAngles` containing only front → front copy
- Default → “Add a front photo to get a focus plan.”

- [ ] **Step 4: Run UITests + spot unit compile**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodUITests/PhysiqueAnglesUpsellUITests \
  -only-testing:HotBodUITests/PhysiqueAnglesUpsellHiddenUITests \
  -only-testing:HotBodTests/PhysiquePhotoGateTests \
  -only-testing:HotBodTests/OfflinePhysiqueAssessmentTests \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/Physique/PhysiqueView.swift \
  HotBod/App/AppEnvironment+Physique.swift \
  HotBod/App/UITestConfiguration.swift \
  HotBod/Tests/UITests/BaseUITestCase.swift \
  HotBod/Tests/UITests/PhysiqueAnglesUpsellUITests.swift \
  HotBod.xcodeproj
git commit -m "feat: upsell optional physique angles after front-only assess"
```

---

## Spec Coverage Checklist

| Spec requirement | Task |
|------------------|------|
| Front-only gate ready | 1 |
| Optional back quality omit | 1 |
| `backPhotoId` optional + decode | 1 |
| Stale ignores unlinked back | 1 |
| Hybrid/offline/remote optional back | 2 |
| Edge front-only + back-listed requires metrics | 2 |
| Offline limited-angle limitation + confidence | 2 |
| Empty/ready helper copy | 3 |
| Report `physique.anglesUpsell` | 3 |
| Retire hard-gate back copy | 3 |
| UITest front-only vs full | 3 |

## Out of Scope

- Illustration changes
- Today tab prompts
- Completeness meter redesign
- Synthetic placeholder back metrics

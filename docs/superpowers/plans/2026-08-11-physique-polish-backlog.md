# Physique Polish Backlog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clear the parked Physique review backlog — optional-side Hybrid parity, edge prompt honesty for missing back, positive stale-with-back test, small UI/test copy fixes, and commit Localizable sync.

**Architecture:** Reuse existing `optionalAnalysis` for side the same way as back; add one hard-rule line to `buildPhysiqueSystemPrompt`; add focused unit/Deno assertions; commit string catalog; discard unrelated cadence plan working-tree churn.

**Tech Stack:** Swift 6, XCTest, Deno (`supabase/functions`), XcodeGen only if new files appear (prefer none).

**Spec:** `docs/superpowers/specs/2026-08-11-physique-polish-backlog-design.md`

## Global Constraints

- iOS 17+.
- Prefer: “fuller read,” “better results,” “reassess,” “refresh your focus.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims, inventing posterior metrics without a back angle.
- Optional angles that fail analysis are omitted, not fatal (front remains required).
- Discard unrelated cadence plan working-tree doc tweak (not product).
- Simulator: `id=EB7BE0BD-179B-4A37-9202-69D87FC47B75` if needed.
- Regression tests use `testRegression_` where applicable.
- Do not alter unrelated uncommitted noise beyond Localizable commit + discarding the cadence plan md.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Services/Physique/HybridPhysiqueAssessmentService.swift` | Side via `optionalAnalysis`; omit nil-analysis side in regate |
| `HotBod/Tests/UnitTests/PhysiqueDomainTests.swift` | Side regression + positive stale + `failSide` on analyzer |
| `HotBod/Features/Physique/PhysiqueView.swift` | `emptyMessage` default |
| `HotBod/Tests/UITests/PhysiqueAnglesUpsellUITests.swift` | Comment fix |
| `supabase/functions/_shared/physiqueSchemas.ts` | Prompt hard-rule |
| `supabase/functions/physique-assess/index.test.ts` or small schemas test | Prompt substring assert |
| `HotBod/Resources/Localizable.xcstrings` | Commit sync |
| `docs/superpowers/plans/2026-08-11-physique-reassess-cadence.md` | Discard dirty edits |

---

### Task 1: Hybrid side parity + stale test + UI copy

**Files:**
- Modify: `HotBod/Services/Physique/HybridPhysiqueAssessmentService.swift`
- Modify: `HotBod/Tests/UnitTests/PhysiqueDomainTests.swift`
- Modify: `HotBod/Features/Physique/PhysiqueView.swift`
- Modify: `HotBod/Tests/UITests/PhysiqueAnglesUpsellUITests.swift`

**Interfaces:**
- Consumes: existing `optionalAnalysis(for:in:)`
- Produces:
  ```swift
  // ensureMetrics:
  let side = await optionalAnalysis(for: selection.side, in: photos)
  // not: try await selection.side.asyncMap { try await ensureAnalysis(...) }

  // regatePrepared resolved selection:
  let side = selection.side.flatMap { $0.analysis != nil ? $0 : nil }

  // ConfigurableBodyPhotoAnalyzer gains failSide: Bool = false (mirror failBack)
  ```

- [ ] **Step 1: Write failing tests**

In `PhysiquePhotoGateTests` (or adjacent):

```swift
func testStaleTrueWhenLinkedBackPhotoIsNewer() {
    let backId = UUID()
    var assessment = FixtureBuilders.makePhysiqueAssessment(backPhotoId: backId)
    assessment.createdAt = Date().addingTimeInterval(-3600)
    let front = FixtureBuilders.makeBodyPhoto(
        pose: .frontRelaxed,
        date: assessment.createdAt.addingTimeInterval(-10)
    )
    let back = FixtureBuilders.makeBodyPhoto(
        pose: .backRelaxed,
        date: Date()
    )
    // Ensure back photo id matches assessment.backPhotoId if isStale keys off pose not id —
    // current isStale uses latest back pose date vs createdAt when backPhotoId != nil.
    XCTAssertTrue(PhysiquePhotoGate.isStale(active: assessment, photos: [front, back]))
}
```

In `HybridPhysiqueAssessmentServiceTests`:

```swift
func testRegression_unanalyzableSideDoesNotBlockAssess() async throws {
    let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, analysis: nil)
    let side = FixtureBuilders.makeBodyPhoto(pose: .sideRelaxed, analysis: nil)
    let service = HybridPhysiqueAssessmentService(
        remote: UnavailablePhysiqueAssessmentService(),
        offline: OfflinePhysiqueAssessmentService(),
        analyzer: ConfigurableBodyPhotoAnalyzer(failSide: true)
    )
    let result = try await service.assess(
        photos: [front, side],
        profile: UserProfile.empty()
    )
    XCTAssertNil(result.sidePhotoId)
    XCTAssertEqual(result.source, .onDevice)
    XCTAssertEqual(result.frontPhotoId, front.id)
}
```

Extend `ConfigurableBodyPhotoAnalyzer` with `failSide` mirroring `failBack` for side poses.

Also add a compile-time expectation: with current Hybrid, `failSide: true` + side present should throw until fixed (RED).

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/HybridPhysiqueAssessmentServiceTests/testRegression_unanalyzableSideDoesNotBlockAssess \
  -only-testing:HotBodTests/PhysiquePhotoGateTests/testStaleTrueWhenLinkedBackPhotoIsNewer \
  test
```

Expected: side regression FAIL (throws) or missing test; stale may PASS already if behavior exists — if stale already passes, keep the test as coverage lock.

- [ ] **Step 3: Implement**

`HybridPhysiqueAssessmentService.ensureMetrics`:

```swift
let front = try await ensureAnalysis(for: selection.front, in: photos)
let back = await optionalAnalysis(for: selection.back, in: photos)
let side = await optionalAnalysis(for: selection.side, in: photos)
```

`regatePrepared` resolved side:

```swift
let side = selection.side.flatMap { $0.analysis != nil ? $0 : nil }
let resolved = PhysiquePhotoSelection(front: selection.front, back: back, side: side)
```

(`back` already resolved the same way.)

`PhysiqueView.emptyMessage`:

```swift
private func emptyMessage(missingAngles: [PhysiquePhotoAngle]) -> String {
    _ = missingAngles
    return "Add a front photo to get a focus plan."
}
```

UITest comment:

```swift
seedPhysiqueHistory = true // seed stubs front+back+side so upsell can hide
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/HybridPhysiqueAssessmentServiceTests \
  -only-testing:HotBodTests/PhysiquePhotoGateTests \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Services/Physique/HybridPhysiqueAssessmentService.swift \
  HotBod/Tests/UnitTests/PhysiqueDomainTests.swift \
  HotBod/Features/Physique/PhysiqueView.swift \
  HotBod/Tests/UITests/PhysiqueAnglesUpsellUITests.swift
git commit -m "fix: omit failed optional side analysis; polish physique tests"
```

---

### Task 2: Edge prompt + Localizable + discard plan churn

**Files:**
- Modify: `supabase/functions/_shared/physiqueSchemas.ts`
- Modify: `supabase/functions/physique-assess/index.test.ts` (or add assert in existing schemas coverage)
- Modify: `HotBod/Resources/Localizable.xcstrings` (commit existing working tree)
- Discard: `docs/superpowers/plans/2026-08-11-physique-reassess-cadence.md` (`git checkout --`)

**Interfaces:**
- Produces: prompt hard-rule substring stable for tests, e.g.  
  `When anglesAvailable lacks "back", do not invent posterior or back-photo musculature metrics.`

- [ ] **Step 1: Write failing Deno assert**

```ts
Deno.test("buildPhysiqueSystemPrompt forbids inventing back metrics without back angle", () => {
  const prompt = buildPhysiqueSystemPrompt();
  assertStringIncludes(prompt, 'anglesAvailable lacks "back"');
  // or the exact bullet text chosen in Step 3
});
```

Import `buildPhysiqueSystemPrompt` from `../_shared/physiqueSchemas.ts` if not already imported in the test file.

- [ ] **Step 2: Run Deno test to verify fail**

```bash
cd supabase/functions && deno test --allow-env --allow-net physique-assess/index.test.ts
```

Expected: FAIL (substring missing)

- [ ] **Step 3: Implement prompt bullet + Localizable + discard**

In `buildPhysiqueSystemPrompt` Hard rules list, add:

```ts
'- When anglesAvailable lacks "back", do not invent posterior or back-photo musculature metrics or claim back-photo evidence.',
```

Then:

```bash
git checkout -- docs/superpowers/plans/2026-08-11-physique-reassess-cadence.md
```

Stage Localizable as-is (already contains cadence/front-only/upsell strings). Do not invent extra localization keys beyond what’s in the working tree.

- [ ] **Step 4: Run Deno + spot client suite**

```bash
cd supabase/functions && deno test --allow-env --allow-net physique-assess/index.test.ts

xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/HybridPhysiqueAssessmentServiceTests \
  -only-testing:HotBodTests/PhysiquePhotoGateTests \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/_shared/physiqueSchemas.ts \
  supabase/functions/physique-assess/index.test.ts \
  HotBod/Resources/Localizable.xcstrings
git commit -m "fix: edge prompt honesty for missing back; sync Localizable"
```

Verify cadence plan is clean (`git status` shows no modify on that file).

---

## Spec Coverage Checklist

| Spec item | Task |
|-----------|------|
| Hybrid side `optionalAnalysis` | 1 |
| Side omit in regate | 1 |
| Side regression test | 1 |
| Positive stale-with-back | 1 |
| emptyMessage default | 1 |
| UITest comment | 1 |
| Edge prompt hard-rule | 2 |
| Deno prompt assert | 2 |
| Commit Localizable | 2 |
| Discard cadence plan md | 2 |

## Out of Scope

- Cadence Settings
- Harder program coupling
- Broader app polish

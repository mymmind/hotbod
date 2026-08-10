# Physique Archetype Directions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add catalog-gated physique direction matches (generic label + optional famous reference) to the Physique assessment report without changing training bias.

**Architecture:** Ship a closed JSON catalog + loader. Offline heuristics and cloud `physique-assess` both emit ranked `PhysiqueArchetypeMatch` IDs only from that catalog. Client sanitizer drops unknowns, caps at 3, scrubs free text, and falls back to the offline matcher when cloud directions are empty. PhysiqueView renders a report-only section resolved against local catalog labels.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XcodeGen (`xcodegen generate` after new HotBod/ files), Deno tests for `physique-assess`, `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-08-10-physique-archetype-directions-design.md`

## Global Constraints

- iOS 17+.
- Closed catalog only — no invented archetype IDs or celebrity names outside the seed.
- Prefer: “physique direction,” “proportional similarity,” “reference.”
- Avoid: “you look like,” “celebrity twin,” identity/lookalike claims, exact body-fat %, genetic destiny.
- No celebrity images.
- Extend existing `physique-assess`; do not add a second edge function.
- Report-only — do not change `trainingBias` / workout generation.
- Decode missing `physiqueDirections` as `[]`.
- After new Swift files under `HotBod/`, run `xcodegen generate`.
- Simulator: use `id=EB7BE0BD-179B-4A37-9202-69D87FC47B75` if `iPhone 16 Pro` is ambiguous.
- Regression tests use `testRegression_` prefix where applicable.
- Do not alter unrelated uncommitted local changes.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Resources/PhysiqueArchetypeCatalog.json` | Curated closed catalog seed |
| `HotBod/Domain/Models/PhysiqueArchetypeCatalog.swift` | Entry + match types; assessment field |
| `HotBod/Domain/Physique/PhysiqueArchetypeCatalogLoader.swift` | Bundle load (`ExerciseCatalogLoader.resourceBundle`) |
| `HotBod/Domain/Physique/PhysiqueArchetypeMatcher.swift` | Offline deterministic matcher |
| `HotBod/Domain/Physique/PhysiqueAssessmentSanitizer.swift` | Sanitize directions; offline fill |
| `HotBod/Domain/Models/PhysiqueAssessment.swift` | Add `physiqueDirections` + decode default |
| `HotBod/Services/Physique/OfflinePhysiqueAssessmentService.swift` | Attach offline matches |
| `HotBod/Services/Physique/RemotePhysiqueAssessmentService.swift` | Send allowed IDs; decode directions |
| `supabase/functions/_shared/physiqueSchemas.ts` | Request/response/schema/prompt |
| `supabase/functions/physique-assess/index.ts` | Pass allowed catalog into prompt payload |
| `supabase/functions/physique-assess/index.test.ts` | Deno coverage |
| `HotBod/Features/Physique/PhysiqueView.swift` | Report section UI |
| `HotBod/Tests/UnitTests/PhysiqueArchetypeTests.swift` | Catalog, matcher, sanitizer, decode |
| `HotBod/Tests/Support/FixtureBuilders.swift` | Fixture directions |
| `HotBod/Tests/UITests/PhysiqueUITests.swift` | Directions section smoke (if seedable) |

---

### Task 1: Catalog seed + domain types + decode compatibility

**Files:**
- Create: `HotBod/Resources/PhysiqueArchetypeCatalog.json`
- Create: `HotBod/Domain/Models/PhysiqueArchetypeCatalog.swift` (or extend `PhysiqueAssessment.swift` if keeping models co-located — prefer dedicated file for catalog types)
- Modify: `HotBod/Domain/Models/PhysiqueAssessment.swift`
- Create: `HotBod/Domain/Physique/PhysiqueArchetypeCatalogLoader.swift`
- Create: `HotBod/Tests/UnitTests/PhysiqueArchetypeTests.swift`
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift`

**Interfaces:**
- Produces:
  ```swift
  struct PhysiqueArchetypeCatalogEntry: Codable, Hashable, Identifiable {
      var id: String
      var genericLabel: String
      var referenceLabel: String?
      var tags: [String]
      var similarityHints: [String]
  }

  struct PhysiqueArchetypeMatch: Codable, Hashable {
      var archetypeId: String
      var rank: Int
      var similarityDimension: String
      var confidence: PhysiqueObservationConfidence
  }

  // PhysiqueAssessment gains:
  var physiqueDirections: [PhysiqueArchetypeMatch] // default []

  enum PhysiqueArchetypeCatalogLoader {
      static func load(
          bundle: Bundle = ExerciseCatalogLoader.resourceBundle
      ) -> [PhysiqueArchetypeCatalogEntry]

      static func indexedById(
          _ entries: [PhysiqueArchetypeCatalogEntry] = load()
      ) -> [String: PhysiqueArchetypeCatalogEntry]
  }
  ```

**Catalog content (use these exact IDs in the JSON seed — 10 entries):**

| id | genericLabel | referenceLabel |
|----|--------------|----------------|
| `lean_fighter` | Lean fighter | Bruce Lee–style athletic build |
| `classic_athletic` | Classic athletic | Brad Pitt — Fight Club era |
| `compact_athletic` | Compact athletic | Young Jean-Claude Van Damme–style |
| `mens_physique` | Men’s physique direction | null |
| `muscular_athletic` | Muscular athletic | null |
| `lean_aesthetic` | Lean aesthetic | null |
| `v_taper_focus` | V-taper focus | null |
| `combat_athlete` | Lightweight combat-athlete | null |
| `balanced_athletic` | Balanced athletic | null |
| `upper_body_presence` | Upper-body presence | null |

Tags/hints examples (implementer fills realistic tags; must be non-empty arrays):
- `lean_fighter`: tags `lean`, `compact`, `fighter`; hints about low mass / athletic definition
- `classic_athletic`: tags `lean`, `athletic`, `v_taper`
- `mens_physique`: tags `v_taper`, `delts`, `lats`, `muscular`
- etc.

- [ ] **Step 1: Write failing tests**

```swift
final class PhysiqueArchetypeCatalogTests: XCTestCase {
    func testCatalogLoadsExpectedEntries() {
        let entries = PhysiqueArchetypeCatalogLoader.load()
        XCTAssertGreaterThanOrEqual(entries.count, 8)
        XCTAssertLessThanOrEqual(entries.count, 12)
        let ids = Set(entries.map(\.id))
        XCTAssertTrue(ids.contains("classic_athletic"))
        XCTAssertTrue(ids.contains("lean_fighter"))
        let classic = entries.first { $0.id == "classic_athletic" }
        XCTAssertEqual(classic?.genericLabel, "Classic athletic")
        XCTAssertNotNil(classic?.referenceLabel)
        let mens = entries.first { $0.id == "mens_physique" }
        XCTAssertNil(mens?.referenceLabel)
    }

    func testPhysiqueAssessmentDecodesMissingDirectionsAsEmpty() throws {
        var assessment = FixtureBuilders.makePhysiqueAssessment()
        assessment.physiqueDirections = [
            PhysiqueArchetypeMatch(
                archetypeId: "classic_athletic",
                rank: 1,
                similarityDimension: "Lean silhouette",
                confidence: .medium
            )
        ]
        let encoded = try JSONEncoder().encode(assessment)
        var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        object.removeValue(forKey: "physiqueDirections")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(PhysiqueAssessment.self, from: stripped)
        XCTAssertEqual(decoded.physiqueDirections, [])
    }
}
```

Update `FixtureBuilders.makePhysiqueAssessment()` to pass `physiqueDirections: []` (or omit via default).

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueArchetypeCatalogTests test
```

Expected: FAIL — types/loader/resource missing.

- [ ] **Step 3: Implement catalog JSON, types, loader, assessment field**

`PhysiqueAssessment` must decode missing `physiqueDirections` as `[]` (custom `init(from:)` or decode-if-present). Keep memberwise init with default `physiqueDirections: []` so existing call sites compile — update all `PhysiqueAssessment(...)` constructions that don’t use defaults.

Include the JSON under `HotBod/Resources/` so `project.yml` resources pick it up after `xcodegen generate`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueArchetypeCatalogTests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Resources/PhysiqueArchetypeCatalog.json \
  HotBod/Domain/Models/PhysiqueArchetypeCatalog.swift \
  HotBod/Domain/Models/PhysiqueAssessment.swift \
  HotBod/Domain/Physique/PhysiqueArchetypeCatalogLoader.swift \
  HotBod/Tests/UnitTests/PhysiqueArchetypeTests.swift \
  HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: add physique archetype catalog and assessment field"
```

---

### Task 2: Offline matcher + sanitizer

**Files:**
- Create: `HotBod/Domain/Physique/PhysiqueArchetypeMatcher.swift`
- Modify: `HotBod/Domain/Physique/PhysiqueAssessmentSanitizer.swift`
- Modify: `HotBod/Services/Physique/OfflinePhysiqueAssessmentService.swift`
- Modify: `HotBod/Tests/UnitTests/PhysiqueArchetypeTests.swift`
- Modify: `HotBod/Tests/UnitTests/PhysiqueDomainTests.swift` (offline assess may need direction assertions)

**Interfaces:**
- Produces:
  ```swift
  enum PhysiqueArchetypeMatcher {
      static func match(
          physique: PhysiqueBuildSummary,
          priorities: [PhysiqueDevelopmentPriority],
          catalog: [PhysiqueArchetypeCatalogEntry] = PhysiqueArchetypeCatalogLoader.load(),
          maxCount: Int = 3,
          overallConfidence: Double
      ) -> [PhysiqueArchetypeMatch]
  }

  // PhysiqueAssessmentSanitizer
  static func sanitizeDirections(
      _ raw: [RemotePhysiqueArchetypeMatchPayload]?,
      catalogIds: Set<String>,
      physique: PhysiqueBuildSummary,
      priorities: [PhysiqueDevelopmentPriority],
      overallConfidence: Double
  ) -> [PhysiqueArchetypeMatch]
  ```

**Offline matching rules (deterministic):**

Score each catalog entry by tag hits derived from assessment:

1. Build signal tags from physique + priorities:
   - If `shoulderToWaist` contains “favorable” or “strong” (case-insensitive) → add `v_taper`
   - If `leanness` contains “lean” → add `lean`
   - If priorities include `.lateralDelts` or `.lats` → add `delts` / `lats` / `v_taper`
   - If `muscularity` contains “high” or “dense” → add `muscular`
   - If `frameSize` contains “compact” OR archetype text contains “compact” → add `compact`
   - Always add `athletic` as a soft baseline tag
2. Entry score = count of overlapping tags with `entry.tags` (+1 if any `similarityHints` keyword appears in `overallArchetype`).
3. Sort by score desc, then `id` asc for stability; take top `maxCount` with score > 0.
4. If `overallConfidence < 0.55`, take only top 1.
5. `similarityDimension` = first `similarityHints` entry, scrubbed; fallback `"Proportional similarity on visible frame traits."`
6. Confidence: `.high` if score ≥ 3, `.medium` if 2, else `.low`.

**Sanitizer rules:**

1. Map raw payload rows → keep only `catalogIds.contains(archetypeId)`.
2. Scrub `similarityDimension`; drop empty after scrub.
3. Sort by incoming rank asc; unique by id (first wins); take 3; reassign rank 1…n.
4. If result empty → return `PhysiqueArchetypeMatcher.match(...)`.

Add `RemotePhysiqueArchetypeMatchPayload` in Task 3 if not added here — for Task 2, sanitizer can accept a small internal struct:

```swift
struct PhysiqueArchetypeMatchDraft: Equatable {
    var archetypeId: String
    var rank: Int
    var similarityDimension: String
    var confidenceRaw: String
}
```

and map from remote in Task 3.

- [ ] **Step 1: Write failing tests**

```swift
final class PhysiqueArchetypeMatcherTests: XCTestCase {
    func testFavorableVTaperSignalsPreferClassicOrVTaperIds() {
        let physique = PhysiqueBuildSummary(
            overallArchetype: "Athletic build with favorable shoulder-to-waist contrast",
            frameSize: "Medium",
            shoulderToWaist: "Favorable contrast",
            waist: "Relatively narrow",
            torso: "Medium",
            muscularity: "Moderate",
            leanness: "Moderately lean"
        )
        let priorities = [
            PhysiqueDevelopmentPriority(muscle: .lateralDelts, reason: "Width"),
            PhysiqueDevelopmentPriority(muscle: .lats, reason: "Taper")
        ]
        let matches = PhysiqueArchetypeMatcher.match(
            physique: physique,
            priorities: priorities,
            overallConfidence: 0.8
        )
        XCTAssertFalse(matches.isEmpty)
        XCTAssertLessThanOrEqual(matches.count, 3)
        let ids = matches.map(\.archetypeId)
        XCTAssertTrue(ids.contains("classic_athletic") || ids.contains("v_taper_focus") || ids.contains("mens_physique"))
        XCTAssertEqual(matches.map(\.rank), Array(1...matches.count))
    }

    func testLowConfidenceReturnsAtMostOneMatch() {
        let matches = PhysiqueArchetypeMatcher.match(
            physique: FixtureBuilders.makePhysiqueAssessment().physique,
            priorities: FixtureBuilders.makePhysiqueAssessment().developmentPriorities,
            overallConfidence: 0.4
        )
        XCTAssertLessThanOrEqual(matches.count, 1)
    }
}

final class PhysiqueArchetypeSanitizerTests: XCTestCase {
    func testDropsUnknownIdsCapsAndFallsBackWhenEmpty() {
        let catalogIds = Set(PhysiqueArchetypeCatalogLoader.load().map(\.id))
        let assessment = FixtureBuilders.makePhysiqueAssessment()
        let cleaned = PhysiqueAssessmentSanitizer.sanitizeDirections(
            [
                .init(archetypeId: "not_real", rank: 1, similarityDimension: "x", confidenceRaw: "high"),
                .init(archetypeId: "classic_athletic", rank: 2, similarityDimension: "Lean silhouette", confidenceRaw: "medium"),
                .init(archetypeId: "lean_fighter", rank: 3, similarityDimension: "you look like a twin", confidenceRaw: "medium"),
                .init(archetypeId: "mens_physique", rank: 4, similarityDimension: "V-taper direction", confidenceRaw: "low")
            ],
            catalogIds: catalogIds,
            physique: assessment.physique,
            priorities: assessment.developmentPriorities,
            overallConfidence: assessment.photoQuality.overallConfidence
        )
        XCTAssertEqual(cleaned.count, 3)
        XCTAssertFalse(cleaned.contains { $0.archetypeId == "not_real" })
        XCTAssertFalse(cleaned.contains { $0.similarityDimension.localizedCaseInsensitiveContains("look like") })
        XCTAssertEqual(cleaned.map(\.rank), [1, 2, 3])

        let fallback = PhysiqueAssessmentSanitizer.sanitizeDirections(
            [],
            catalogIds: catalogIds,
            physique: assessment.physique,
            priorities: assessment.developmentPriorities,
            overallConfidence: 0.8
        )
        XCTAssertFalse(fallback.isEmpty)
    }
}
```

Define `PhysiqueArchetypeMatchDraft` (or equivalent) for the sanitizer input in this task.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueArchetypeMatcherTests \
  -only-testing:HotBodTests/PhysiqueArchetypeSanitizerTests test
```

Expected: FAIL

- [ ] **Step 3: Implement matcher + sanitizer; wire OfflinePhysiqueAssessmentService**

In `OfflinePhysiqueAssessmentService.assess`, set:

```swift
physiqueDirections: PhysiqueArchetypeMatcher.match(
    physique: summary,
    priorities: priorities,
    overallConfidence: overallConfidence
)
```

Also extend free-text scrub patterns if needed to catch `you look like` / `celebrity twin` in `similarityDimension` (add to `disallowedPatterns`).

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueArchetypeMatcherTests \
  -only-testing:HotBodTests/PhysiqueArchetypeSanitizerTests \
  -only-testing:HotBodTests/OfflinePhysiqueAssessmentTests test
```

Expected: PASS. Add one offline assess assertion that `physiqueDirections` is non-empty for the standard fixture request.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Physique/PhysiqueArchetypeMatcher.swift \
  HotBod/Domain/Physique/PhysiqueAssessmentSanitizer.swift \
  HotBod/Services/Physique/OfflinePhysiqueAssessmentService.swift \
  HotBod/Tests/UnitTests/PhysiqueArchetypeTests.swift \
  HotBod/Tests/UnitTests/PhysiqueDomainTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: match physique directions offline with catalog sanitizer"
```

---

### Task 3: Edge schema/prompt + remote mapping

**Files:**
- Modify: `supabase/functions/_shared/physiqueSchemas.ts`
- Modify: `supabase/functions/physique-assess/index.ts`
- Modify: `supabase/functions/physique-assess/index.test.ts`
- Modify: `HotBod/Services/Physique/RemotePhysiqueAssessmentService.swift`
- Modify: `HotBod/Domain/Physique/PhysiqueAssessmentSanitizer.swift` (`map` attaches directions)
- Modify: `HotBod/Tests/UnitTests/PhysiqueArchetypeTests.swift` and/or `PhysiqueDomainTests.swift`
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift` (optional persist assertion)

**Interfaces:**
- Request gains:
  ```ts
  allowedArchetypes: Array<{ id: string; genericLabel: string; tags: string[] }>
  ```
  (or `allowedArchetypeIds` + parallel summaries — prefer structured `allowedArchetypes`)
- Response gains required:
  ```ts
  physiqueDirections: Array<{
    archetypeId: string;
    rank: number;
    similarityDimension: string;
    confidence: "high" | "medium" | "low" | "uncertain";
  }>
  ```
- Swift `PhysiqueAssessInvokeRequest` includes `allowedArchetypes` loaded from `PhysiqueArchetypeCatalogLoader.load()`.
- `RemotePhysiqueAssessmentPayload` includes `physiqueDirections`.
- `PhysiqueAssessmentSanitizer.map` calls `sanitizeDirections` and sets `physiqueDirections`.

**Prompt additions** (in `buildPhysiqueSystemPrompt`):
- Rank 1–3 directions only from `allowedArchetypes`.
- Use physique direction / reference language; forbid “you look like”, identity claims, BF%, genetic destiny.
- `similarityDimension` must describe proportions/silhouette, not identity.

**Schema note:** under OpenAI `strict: true`, every property in objects must be listed in `required` (including nullable fields via `["string","null"]` only if needed — here all direction fields are required non-null).

- [ ] **Step 1: Write failing Deno + Swift tests**

Deno: assert response schema requires `physiqueDirections`; assert validate rejects request without `allowedArchetypes` **or** treats empty allowed list as 400; assert a golden stubbed OpenAI payload with unknown `archetypeId` is still returned by handler (client strips — optional) OR handler filters unknown ids before return (prefer **handler filters** to allowed set for defense in depth).

Swift:

```swift
func testSanitizerMapAttachesCatalogBackedDirections() {
    // Build a RemotePhysiqueAssessmentPayload fixture including
    // physiqueDirections with one unknown + two valid IDs.
    // Map via PhysiqueAssessmentSanitizer.map
    // Assert directions count == 2 (or 3 with offline fill), no unknown id.
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd supabase/functions && deno test -P physique-assess/index.test.ts
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueAssessmentSanitizerTests \
  -only-testing:HotBodTests/PhysiqueArchetypeSanitizerTests test
```

Expected: FAIL until schema/payload wired.

- [ ] **Step 3: Implement schema, prompt, handler filter, remote invoke, sanitizer.map**

Handler should:
1. Validate `allowedArchetypes` non-empty.
2. Include them in the user payload JSON.
3. After model JSON parse, filter `physiqueDirections` to allowed ids before returning.

Remote service builds `allowedArchetypes` from catalog loader.

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd supabase/functions && deno test -P physique-assess/index.test.ts
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueAssessmentSanitizerTests \
  -only-testing:HotBodTests/PhysiqueArchetypeSanitizerTests \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testAssessPhysiquePersistsOnDeviceWhenRemoteUnavailable \
  test
```

Expected: PASS (on-device path still fills directions via offline).

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/_shared/physiqueSchemas.ts \
  supabase/functions/physique-assess \
  HotBod/Services/Physique/RemotePhysiqueAssessmentService.swift \
  HotBod/Domain/Physique/PhysiqueAssessmentSanitizer.swift \
  HotBod/Tests HotBod.xcodeproj/project.pbxproj
git commit -m "feat: return catalog-gated physique directions from cloud assess"
```

---

### Task 4: PhysiqueView section + verification

**Files:**
- Modify: `HotBod/Features/Physique/PhysiqueView.swift`
- Modify: `HotBod/Tests/UITests/PhysiqueUITests.swift` (add assertions if assessment can be seeded; otherwise unit-test a small view-model/copy helper)
- Create (optional): `HotBod/Domain/Physique/PhysiqueDirectionCopy.swift` for row formatting
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift` — `testRegression_physiqueDirectionsDoNotChangeTrainingBias`

**Interfaces:**
- UI copy exact from spec (§1 table + footer).
- Row formatting:
  ```swift
  enum PhysiqueDirectionCopy {
      static func referenceLine(for entry: PhysiqueArchetypeCatalogEntry) -> String? {
          entry.referenceLabel.map { "Reference: \($0)" }
      }
  }
  ```
- Section between Development Priorities and Why today’s training.
- `accessibilityIdentifier("physique.directions")` on section container; rows `physique.direction.\(id)`.

- [ ] **Step 1: Write failing tests**

```swift
func testReferenceLinePrefixesReferenceLabel() {
    let entry = PhysiqueArchetypeCatalogEntry(
        id: "classic_athletic",
        genericLabel: "Classic athletic",
        referenceLabel: "Brad Pitt — Fight Club era",
        tags: ["lean"],
        similarityHints: ["Lean silhouette"]
    )
    XCTAssertEqual(
        PhysiqueDirectionCopy.referenceLine(for: entry),
        "Reference: Brad Pitt — Fight Club era"
    )
    var genericOnly = entry
    genericOnly.referenceLabel = nil
    XCTAssertNil(PhysiqueDirectionCopy.referenceLine(for: genericOnly))
}

func testRegression_physiqueDirectionsDoNotChangeTrainingBias() async {
    // Assess offline with directions present; capture preferredMuscleGroups
    // from makeWorkoutGenerationInput and assert equal to merger output from
    // priorities alone (directions ignored).
}
```

UI (if feasible without heavy seeding): assert disclaimer string exists when presenting a debug/fixture path — otherwise skip UI directions happy path and cover empty-state regression still green:

```swift
func testPhysiqueTabStillHasNoCoachChat() {
    // existing regression remains
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueDirectionCopyTests \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testRegression_physiqueDirectionsDoNotChangeTrainingBias \
  test
```

Expected: FAIL

- [ ] **Step 3: Implement PhysiqueView section + copy helper + regression test**

Lookup entry via `PhysiqueArchetypeCatalogLoader.indexedById()[match.archetypeId]`; skip row if missing (shouldn’t happen post-sanitize).

- [ ] **Step 4: Run verification**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueArchetypeCatalogTests \
  -only-testing:HotBodTests/PhysiqueArchetypeMatcherTests \
  -only-testing:HotBodTests/PhysiqueArchetypeSanitizerTests \
  -only-testing:HotBodTests/PhysiqueDirectionCopyTests \
  -only-testing:HotBodTests/OfflinePhysiqueAssessmentTests \
  -only-testing:HotBodTests/PhysiqueAssessmentSanitizerTests \
  -only-testing:HotBodUITests/PhysiqueUITests \
  test
cd supabase/functions && deno test -P physique-assess/index.test.ts
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/Physique/PhysiqueView.swift \
  HotBod/Domain/Physique/PhysiqueDirectionCopy.swift \
  HotBod/Tests HotBod.xcodeproj/project.pbxproj
git commit -m "feat: show physique direction matches on Physique report"
```

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| Closed catalog seed | 1 |
| Domain match types + decode `[]` | 1 |
| Offline matcher | 2 |
| Sanitizer + offline fill | 2 |
| Offline assess attaches directions | 2 |
| Edge schema/prompt/allowed list | 3 |
| Remote mapping | 3 |
| Physique report UI + disclaimer | 4 |
| Report-only / bias unchanged | 4 regression |
| No celebrity images / lookalike claims | 2 scrub + 4 copy |

## Type consistency notes

- Catalog field: `physiqueDirections: [PhysiqueArchetypeMatch]`
- Remote draft/payload field names: `archetypeId`, `rank`, `similarityDimension`, `confidence`
- Loader uses `ExerciseCatalogLoader.resourceBundle`
- Max matches: 3; low confidence (`overallConfidence < 0.55`): max 1

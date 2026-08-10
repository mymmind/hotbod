# Physique Illustrative Direction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an opt-in Physique “illustrative direction” — server image-edit of the user’s front photo with subtle priority emphasis, local cache, and hard non-prediction framing.

**Architecture:** Client builds allowlisted hints + compressed front JPEG, invokes new `physique-illustrate` edge (auth + `OPENAI_API_KEY` → OpenAI `POST /v1/images/edits`), caches result by assessment id, and renders a Forge section after Why today’s training. Mock service powers UITests without network.

**Tech Stack:** Swift 6, SwiftUI, UIKit image resize, XCTest, XcodeGen, Deno edge tests, OpenAI Images edits API (`gpt-image-1` / env override), Supabase Functions.

**Spec:** `docs/superpowers/specs/2026-08-10-physique-illustrative-direction-design.md`

## Global Constraints

- iOS 17+.
- Prefer: “illustrative direction,” “subtle emphasis,” “not a prediction.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike/celebrity likeness, competitor assets, timeline promises (“in 12 weeks”).
- Never send celebrity `referenceLabel` into prompts — catalog `genericLabel` only.
- Never log photo bytes or full base64.
- Subtle edit only; no auto-generate on assess.
- After new Swift files under `HotBod/`, run `xcodegen generate`.
- Simulator: `id=EB7BE0BD-179B-4A37-9202-69D87FC47B75` if needed.
- Regression tests use `testRegression_` where applicable.
- Do not alter unrelated uncommitted local changes.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Models/PhysiqueIllustration.swift` | Hints + record types |
| `HotBod/Domain/Physique/PhysiqueIllustrationHintsBuilder.swift` | Assessment → allowlisted hints |
| `HotBod/Domain/Physique/PhysiqueIllustrationImageCodec.swift` | Resize/compress JPEG (~1024 max edge) |
| `HotBod/Data/Local/LocalPhysiqueIllustrationStore.swift` | Cache metadata JSON + image files |
| `HotBod/Data/Repositories/RepositoryProtocols.swift` | `PhysiqueIllustrationService` protocol |
| `HotBod/Services/Physique/MockPhysiqueIllustrationService.swift` | Fixture JPEG for tests/UI |
| `HotBod/Services/Physique/RemotePhysiqueIllustrationService.swift` | Edge invoke |
| `HotBod/Data/Remote/BackendServices.swift` | Factory |
| `HotBod/App/AppEnvironment.swift` + `+Physique` / `+Account` | State, generate, load, wipe |
| `HotBod/Features/Physique/PhysiqueIllustrationSection.swift` | UI section |
| `HotBod/Features/Physique/PhysiqueView.swift` | Embed section |
| `supabase/functions/_shared/physiqueIllustrateSchemas.ts` | Validate + prompt |
| `supabase/functions/physique-illustrate/index.ts` | Handler |
| `supabase/functions/physique-illustrate/index.test.ts` | Deno tests |
| Unit/UI tests under `HotBod/Tests/` | Coverage |

---

### Task 1: Hints, compress, local store

**Files:**
- Create: `HotBod/Domain/Models/PhysiqueIllustration.swift`
- Create: `HotBod/Domain/Physique/PhysiqueIllustrationHintsBuilder.swift`
- Create: `HotBod/Domain/Physique/PhysiqueIllustrationImageCodec.swift`
- Create: `HotBod/Data/Local/LocalPhysiqueIllustrationStore.swift`
- Create: `HotBod/Tests/UnitTests/PhysiqueIllustrationDomainTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct PhysiqueIllustrationHints: Hashable, Sendable {
      var priorityMuscles: [PhysiqueFocusMuscle] // ≤ 3
      var directionGenericLabels: [String]       // ≤ 3
  }

  struct PhysiqueIllustrationRecord: Codable, Hashable, Identifiable {
      var id: UUID { assessmentId }
      var assessmentId: UUID
      var sourcePhotoId: UUID
      var createdAt: Date
      var localImagePath: String // filename relative to illustrations dir
  }

  enum PhysiqueIllustrationHintsBuilder {
      static func make(
          from assessment: PhysiqueAssessment,
          catalog: [String: PhysiqueArchetypeCatalogEntry] = PhysiqueArchetypeCatalogLoader.indexedById()
      ) -> PhysiqueIllustrationHints
  }

  enum PhysiqueIllustrationImageCodec {
      static let maxEdge: CGFloat = 1024
      static let jpegQuality: CGFloat = 0.8
      static func jpegDataForUpload(from image: UIImage) -> Data?
      static func jpegDataForUpload(from data: Data) -> Data?
  }

  actor LocalPhysiqueIllustrationStore {
      init(directoryName: String = "physique_illustrations")
      func fetch(assessmentId: UUID) throws -> (PhysiqueIllustrationRecord, Data)?
      func save(assessmentId: UUID, sourcePhotoId: UUID, imageData: Data) throws -> PhysiqueIllustrationRecord
      func clear(assessmentId: UUID) throws
      func clearAll() throws
  }
  ```

**Hints rules:** top 3 `developmentPriorities.map(\.muscle)`; directions via `PhysiqueDirectionResolve.resolved` → `entry.genericLabel` only (never `referenceLabel`); unique labels; max 3.

**Store:** App Support/`physique_illustrations/` — `index.json` map assessmentId → record; image files `"{assessmentId}.jpg"`. `save` replaces existing. Use `PersistenceHelper.appSupportURL` / isolated testing via existing PersistenceTestHelpers when possible.

- [ ] **Step 1: Write failing tests**

```swift
final class PhysiqueIllustrationDomainTests: XCTestCase {
    func testHintsBuilderUsesGenericLabelsOnlyAndCapsPriorities() {
        var assessment = FixtureBuilders.makePhysiqueAssessment()
        assessment.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "a"),
            .init(muscle: .lats, reason: "b"),
            .init(muscle: .upperChest, reason: "c"),
            .init(muscle: .abs, reason: "d")
        ]
        assessment.physiqueDirections = [
            PhysiqueArchetypeMatch(
                archetypeId: "classic_athletic",
                rank: 1,
                similarityDimension: "taper",
                confidence: .high
            )
        ]
        let hints = PhysiqueIllustrationHintsBuilder.make(from: assessment)
        XCTAssertEqual(hints.priorityMuscles.count, 3)
        XCTAssertEqual(hints.priorityMuscles, [.lateralDelts, .lats, .upperChest])
        XCTAssertEqual(hints.directionGenericLabels, ["Classic athletic"])
        XCTAssertFalse(hints.directionGenericLabels.joined().localizedCaseInsensitiveContains("Brad"))
        XCTAssertFalse(hints.directionGenericLabels.joined().localizedCaseInsensitiveContains("Pitt"))
    }

    func testImageCodecRespectsMaxEdge() {
        let size = CGSize(width: 2000, height: 1500)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        let data = PhysiqueIllustrationImageCodec.jpegDataForUpload(from: image)
        XCTAssertNotNil(data)
        let out = UIImage(data: data!)!
        XCTAssertLessThanOrEqual(max(out.size.width, out.size.height), 1024 + 1)
    }

    func testStoreSaveFetchReplaceAndClearAll() async throws {
        try await PersistenceTestHelpers.withIsolatedPersistence {
            let store = LocalPhysiqueIllustrationStore(
                directoryName: "physique_illustrations_test_\(UUID().uuidString)"
            )
            let id = UUID()
            let photoId = UUID()
            let data = Data([0xFF, 0xD8, 0xFF, 0xD9]) // minimal stand-in; or tiny real JPEG
            // Prefer a 1x1 JPEG from codec for realism
            let jpeg = PhysiqueIllustrationImageCodec.jpegDataForUpload(
                from: UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in }
            )!
            _ = try await store.save(assessmentId: id, sourcePhotoId: photoId, imageData: jpeg)
            let loaded = try await store.fetch(assessmentId: id)
            XCTAssertEqual(loaded?.0.assessmentId, id)
            XCTAssertEqual(loaded?.0.sourcePhotoId, photoId)
            XCTAssertFalse(loaded!.1.isEmpty)

            let jpeg2 = jpeg
            _ = try await store.save(assessmentId: id, sourcePhotoId: UUID(), imageData: jpeg2)
            let replaced = try await store.fetch(assessmentId: id)
            XCTAssertNotEqual(replaced?.0.sourcePhotoId, photoId)

            try await store.clearAll()
            XCTAssertNil(try await store.fetch(assessmentId: id))
        }
    }
}
```

If `LocalPhysiqueIllustrationStore` is an actor, use `await` as shown; if sync class is simpler and matches other helpers, sync is OK — pick one and keep tests consistent. Prefer **actor** for file IO.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueIllustrationDomainTests test
```

Expected: FAIL

- [ ] **Step 3: Implement models, builder, codec, store**

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueIllustrationDomainTests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Models/PhysiqueIllustration.swift \
  HotBod/Domain/Physique/PhysiqueIllustrationHintsBuilder.swift \
  HotBod/Domain/Physique/PhysiqueIllustrationImageCodec.swift \
  HotBod/Data/Local/LocalPhysiqueIllustrationStore.swift \
  HotBod/Tests/UnitTests/PhysiqueIllustrationDomainTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: add physique illustration hints and local store"
```

---

### Task 2: Edge `physique-illustrate` + Deno tests

**Files:**
- Create: `supabase/functions/_shared/physiqueIllustrateSchemas.ts`
- Create: `supabase/functions/physique-illustrate/index.ts`
- Create: `supabase/functions/physique-illustrate/index.test.ts`

**Interfaces:**
- Produces:
  ```ts
  type PhysiqueIllustrateRequest = {
    assessmentId: string;
    imageBase64: string;
    priorityMuscles: string[];
    directionGenericLabels: string[];
  };

  type PhysiqueIllustrateResponse = {
    imageBase64: string;
    contentType: "image/jpeg" | "image/png";
  };

  export function validatePhysiqueIllustrateRequest(body: PhysiqueIllustrateRequest): string | null
  export function buildPhysiqueIllustratePrompt(input: {
    priorityMuscles: string[];
    directionGenericLabels: string[];
  }): string
  export function allowlistedMuscleDisplayNames(ids: string[]): string[]
  ```

**Allowlisted muscle ids** (mirror Swift `PhysiqueFocusMuscle` raw values):  
`lateralDelts, rearDelts, lats, upperChest, traps, chest, shoulders, biceps, triceps, abs, glutes, quads, hamstrings, calves`

**Validation:**
- `assessmentId` non-empty UUID-ish string
- `imageBase64` non-empty; decoded size ≤ 1_500_000 bytes
- `priorityMuscles`: filter to allowlist, max 3; if empty after filter → 400
- `directionGenericLabels`: trim, drop empties, max 3; **must not** contain banned substrings (case-insensitive): `brad`, `pitt`, `bruce lee`, `van damme`, `you look like`, `celebrity` (defense in depth — client already strips)

**Prompt** must include:
- Subtle emphasis of listed muscles / generic directions
- Keep same person, pose, framing, clothing
- Explicit forbids: medical, BF%, timelines, celebrity likeness, different person, dramatic bulk
- Must **not** interpolate any celebrity reference strings

**Handler:**
1. OPTIONS / 503 no key / 401 no auth / getUser (copy physique-assess)
2. Validate body
3. Decode base64 → `Blob`/`File` named `front.jpg`
4. `POST https://api.openai.com/v1/images/edits` as `multipart/form-data`:
   - `model`: `Deno.env.get("OPENAI_IMAGE_MODEL") ?? "gpt-image-1"`
   - `image`: file
   - `prompt`: built prompt
   - `size`: `1024x1024` (or omit if model default)
5. Read `data[0].b64_json`; return `{ imageBase64, contentType: "image/png" }` (API often returns png; client codec can re-encode to JPEG on save)
6. Stub OpenAI in Deno tests; never call real API in CI

Inject OpenAI fetch via optional dependency / stub `globalThis.fetch` like other function tests.

- [ ] **Step 1: Write failing Deno tests**

```ts
Deno.test("rejects missing auth", async () => { /* 401 */ });
Deno.test("rejects missing OPENAI_API_KEY", async () => { /* 503 */ });
Deno.test("validate rejects empty image", () => {
  assertEquals(validatePhysiqueIllustrateRequest({
    assessmentId: crypto.randomUUID(),
    imageBase64: "",
    priorityMuscles: ["lateralDelts"],
    directionGenericLabels: [],
  }), /* non-null error */);
});
Deno.test("validate filters unknown muscles and caps at 3", () => { /* ... */ });
Deno.test("prompt excludes celebrity names and includes subtle emphasis rules", () => {
  const prompt = buildPhysiqueIllustratePrompt({
    priorityMuscles: ["lateralDelts", "lats"],
    directionGenericLabels: ["Classic athletic"],
  });
  assertMatch(prompt, /subtle/i);
  assertMatch(prompt, /not a prediction|illustration/i);
  assertEquals(prompt.toLowerCase().includes("brad"), false);
});
Deno.test("handler returns image when OpenAI stubbed", async () => { /* stub fetch → b64 */ });
```

- [ ] **Step 2: Run Deno tests to verify they fail**

```bash
cd supabase/functions && deno test physique-illustrate/index.test.ts
```

Expected: FAIL

- [ ] **Step 3: Implement schemas + handler**

- [ ] **Step 4: Run Deno tests to verify they pass**

```bash
cd supabase/functions && deno test physique-illustrate/index.test.ts
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/_shared/physiqueIllustrateSchemas.ts \
  supabase/functions/physique-illustrate
git commit -m "feat: add physique-illustrate edge function"
```

---

### Task 3: Remote/Mock service + AppEnvironment wiring

**Files:**
- Modify: `HotBod/Data/Repositories/RepositoryProtocols.swift` — add protocol
- Create: `HotBod/Services/Physique/MockPhysiqueIllustrationService.swift`
- Create: `HotBod/Services/Physique/RemotePhysiqueIllustrationService.swift`
- Modify: `HotBod/Data/Remote/BackendServices.swift` — `makePhysiqueIllustrationService`
- Modify: `HotBod/App/AppEnvironment.swift` — properties + inject service/store
- Modify: `HotBod/App/AppEnvironment+Physique.swift` — load/generate
- Modify: `HotBod/App/AppEnvironment+Account.swift` — clear store + runtime fields on wipe
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift` / `makeForTests`
- Create/extend: `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift`

**Interfaces:**
```swift
protocol PhysiqueIllustrationService: Sendable {
    func generate(
        assessmentId: UUID,
        hints: PhysiqueIllustrationHints,
        imageData: Data
    ) async throws -> Data
}

enum PhysiqueIllustrationError: Error {
    case notConfigured
    case unavailable
    case invalidResponse
    case serverMessage(String)
}

// AppEnvironment
var physiqueIllustrationService: any PhysiqueIllustrationService
var physiqueIllustrationStore: LocalPhysiqueIllustrationStore // or protocol
var physiqueIllustration: PhysiqueIllustrationRecord?
var physiqueIllustrationImageData: Data? // for UI, or load on demand
var physiqueIllustrationStatus: String?
var isGeneratingPhysiqueIllustration: Bool

func loadPhysiqueIllustration(for assessmentId: UUID) async
func generatePhysiqueIllustration(
    assessment: PhysiqueAssessment,
    photos: [BodyProgressPhoto]
) async
```

**generate flow:**
1. Guard onboarding/profile; find photo `photos.first { $0.id == assessment.frontPhotoId }` with existing file
2. Load UIImage → `PhysiqueIllustrationImageCodec.jpegDataForUpload`
3. Hints via builder
4. `isGenerating = true`; clear status
5. `try await service.generate(...)`
6. `store.save(...)`; set `physiqueIllustration` + image data
7. On error: user-safe status (`Illustration unavailable.` / `Sign in to generate.` / server message sanitized — never echo base64)
8. `isGenerating = false`

**Factory:** If Supabase configured → Remote; else if UITesting/`-MockAI` → Mock; else Mock or Unavailable that throws `.notConfigured`. Prefer: **UITesting or MockAI → Mock**; production configured → Remote; else service that throws clear `.notConfigured`.

**Mock:** return a tiny valid JPEG (generate via codec in init or bundle 1x1).

**Wipe:** `clearAll` on store; nil runtime illustration fields in `resetRuntimeStateAfterDataDeletion`.

**Remote invoke body:**
```swift
struct RemotePhysiqueIllustrateRequest: Encodable {
    var assessmentId: String
    var imageBase64: String
    var priorityMuscles: [String]
    var directionGenericLabels: [String]
}
```
Decode response `{ imageBase64, contentType }`.

- [ ] **Step 1: Write failing tests**

```swift
func testGeneratePhysiqueIllustrationPersistsWithMock() async throws {
    let repos = TestRepositories.empty()
    var profile = UserProfile.empty()
    try await repos.userProfile.saveProfile(profile)
    try await repos.userProfile.setOnboardingComplete(true)
    let front = FixtureBuilders.makeBodyPhoto(pose: .frontRelaxed, userId: profile.id)
    // Ensure photo file exists on disk for load — follow existing body photo test helpers
    try await repos.bodyProgress.savePhoto(front)
    var assessment = FixtureBuilders.makePhysiqueAssessment()
    assessment.frontPhotoId = front.id
    try await repos.physiqueAssessment.saveActive(assessment)

    let env = AppEnvironment.makeForTests(
        repos: repos,
        physiqueIllustrationService: MockPhysiqueIllustrationService()
    )
    env.userProfile = profile
    env.hasCompletedOnboarding = true
    await env.loadActivePhysiqueAssessment()
    await env.generatePhysiqueIllustration(assessment: assessment, photos: [front])
    XCTAssertNotNil(env.physiqueIllustration)
    XCTAssertEqual(env.physiqueIllustration?.assessmentId, assessment.id)
    XCTAssertFalse(env.isGeneratingPhysiqueIllustration)
}

func testRegression_wipeClearsPhysiqueIllustration() async throws {
    // seed illustration runtime + store, wipe, assert nil / fetch nil
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testGeneratePhysiqueIllustrationPersistsWithMock \
  test
```

Expected: FAIL

- [ ] **Step 3: Implement services + env wiring**

Ensure `makeForTests` defaults to Mock. Wire wipe.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testGeneratePhysiqueIllustrationPersistsWithMock \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testRegression_wipeClearsPhysiqueIllustration \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Data HotBod/Services/Physique HotBod/App HotBod/Tests \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: wire physique illustration generate and cache"
```

---

### Task 4: Physique UI + UITest

**Files:**
- Create: `HotBod/Features/Physique/PhysiqueIllustrationSection.swift`
- Modify: `HotBod/Features/Physique/PhysiqueView.swift` — show section when assessment present; load illustration on appear / assessment change
- Modify: `HotBod/Tests/UITests/PhysiqueUITests.swift` or new `PhysiqueIllustrationUITests.swift`
- Modify: `HotBod/App/UITestConfiguration.swift` / `BaseUITestCase` if a seed or MockAI already covers service

**UI (exact copy):**

```swift
// After why-today actions area on current report (PhysiqueView), not history detail:
PhysiqueIllustrationSection(...)

// Ready:
helper: "Subtle emphasis of your current focus areas. Not a prediction."
ForgeButton(title: "Generate illustrative direction", style: .secondary,
            isLoading: isGenerating,
            accessibilityIdentifier: "physique.illustrate")

// Result:
ForgeSectionHeader(title: "Illustrative direction", subtitle: nil)
Image...
Text("This is an illustration of possible emphasis — not a forecast of your body, timeline, or genetics.")
ForgeButton(title: "Regenerate", ..., accessibilityIdentifier: "physique.illustrate.regenerate")
.accessibilityIdentifier("physique.illustrate.result")
```

Load image from `environment.physiqueIllustrationImageData` or store fetch. On appear: `loadPhysiqueIllustration(for: assessment.id)`.

**UITest:** With `-MockAI` / mock illustration service (ensure UITesting factory uses Mock):
1. Need assessment + front photo — either extend `-SeedPhysiqueHistory` to also seed a front photo file **or** add `-SeedPhysiqueIllustrationReady` that seeds assessment + dummy front photo on disk.
2. Prefer new flag `-SeedPhysiqueIllustrationReady` that: skip onboarding, save assessment with known frontPhotoId, write a tiny JPEG to that photo path, mock illustration service already default in UITesting.
3. Open Physique → tap `physique.illustrate` → wait for `physique.illustrate.result` → assert disclaimer text exists.

- [ ] **Step 1: Write failing UI test**

```swift
final class PhysiqueIllustrationUITests: BaseUITestCase {
    override func setUpWithError() throws {
        launchTab = "physique"
        seedPhysiqueIllustrationReady = true // wire in BaseUITestCase → -SeedPhysiqueIllustrationReady
        try super.setUpWithError()
    }

    func testGenerateIllustrativeDirectionShowsResult() {
        let generate = app.buttons["physique.illustrate"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        generate.tap()
        XCTAssertTrue(
            app.otherElements["physique.illustrate.result"].waitForExistence(timeout: 10)
            || app.descendants(matching: .any)["physique.illustrate.result"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.staticTexts[
                "This is an illustration of possible emphasis — not a forecast of your body, timeline, or genetics."
            ].waitForExistence(timeout: 5)
        )
    }
}
```

- [ ] **Step 2: Run UI test to verify it fails**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodUITests/PhysiqueIllustrationUITests test
```

Expected: FAIL

- [ ] **Step 3: Implement UI + seed flag**

Seed must create a real on-disk front photo the UI/env can load (reuse BodyPhoto import path helpers used elsewhere in UITestConfiguration).

- [ ] **Step 4: Run UI + domain smoke**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodUITests/PhysiqueIllustrationUITests \
  -only-testing:HotBodTests/PhysiqueIllustrationDomainTests \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/Physique HotBod/App/UITestConfiguration.swift \
  HotBod/Tests/UITests HotBod.xcodeproj/project.pbxproj
git commit -m "feat: show physique illustrative direction UI"
```

---

## Self-Review Checklist

| Spec requirement | Task |
|------------------|------|
| Hints genericLabel only, max 3 | Task 1 |
| Compress ~1024 | Task 1 |
| Local cache by assessmentId | Task 1 |
| Edge auth/key + images/edits | Task 2 |
| Prompt forbids + no celeb | Task 2 |
| Deno tests | Task 2 |
| Mock/Remote + env generate/load | Task 3 |
| Wipe clears | Task 3 |
| UI copy/a11y + CTA | Task 4 |
| UITest mock path | Task 4 |
| No Progress / auto-assess / history illust | Out of scope |

**Type consistency:** `PhysiqueIllustrationHints`, `PhysiqueIllustrationRecord`, `PhysiqueIllustrationService.generate`, store APIs aligned.  
**OpenAI:** `POST /v1/images/edits`, model env `OPENAI_IMAGE_MODEL` default `gpt-image-1`, response `b64_json`.

# Apple Intelligence Phase 1 — Floor + FM Scaffolding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise HotBod’s iOS floor for Apple Intelligence / Foundation Models / PCC and add a thin protocol wrapper + UITest mock — without cutting OpenAI/Gemini product paths yet.

**Architecture:** Bump `deploymentTarget` to **iOS 27.0** (PCC API floor; on-device FM is 26.0+). Introduce `AppleLanguageModeling` protocol with availability + session factories. Production client wraps `FoundationModels` behind `#if canImport(FoundationModels)`; UITesting / tests use `MockAppleLanguageModeling`. Inject into `AppEnvironment` for later phases; leave `BackendServices` AI factories unchanged in Phase 1.

**Tech Stack:** Swift 6, SwiftUI, FoundationModels (system), XCTest, XcodeGen (`project.yml`).

**Umbrella:** `docs/superpowers/specs/2026-08-12-apple-intelligence-exclusive-cutover-design.md`  
**Phase scope:** Phase 1 only (Phases 2–5 out of scope).

## Global Constraints

- iOS **27.0+** after this phase (was 17.0).
- Prefer: “on-device,” “Apple Intelligence.”
- Avoid: medical claims, destiny/lookalike copy, “guaranteed AI.”
- Soft: do **not** delete Gemini/OpenAI/edges/illustration/USDA/Supabase in this phase.
- UITests: `-MockAI` continues to force mock AI workout service; Apple language mock is selected for UITesting / unit tests via factory.
- Simulator: `id=EB7BE0BD-179B-4A37-9202-69D87FC47B75` if needed (may lack Apple Intelligence — mock path must keep CI green).
- Do not alter unrelated uncommitted `Localizable.xcstrings` noise.
- After `project.yml` change: `xcodegen generate`; restore `objectVersion` / `DEVELOPMENT_TEAM` churn if it appears.

## File Structure

| File | Responsibility |
|------|----------------|
| `project.yml` | `deploymentTarget.iOS: "27.0"` |
| `AGENTS.md` | Stack line iOS 27+ |
| `HotBod/Services/AI/AppleLanguageModeling.swift` | Protocol + availability enums + errors |
| `HotBod/Services/AI/MockAppleLanguageModeling.swift` | Deterministic fake for tests / UITesting |
| `HotBod/Services/AI/SystemAppleLanguageModeling.swift` | FoundationModels-backed client |
| `HotBod/Data/Remote/BackendServices.swift` | `makeAppleLanguageModeling()` factory only |
| `HotBod/App/AppEnvironment.swift` | Hold `appleLanguageModeling` dependency |
| `HotBod/Tests/UnitTests/AppleLanguageModelingTests.swift` | Mock + factory behavior |
| `HotBod/Tests/Support/FixtureBuilders.swift` | Default mock in `makeForTests` if needed |

---

### Task 1: Raise deployment target + docs

**Files:**
- Modify: `project.yml` (`deploymentTarget.iOS`)
- Modify: `AGENTS.md` (Stack → iOS 27+)
- Modify: umbrella note is already iOS-flexible; optional one-line in Phase 1 plan only (no extra md files)

**Interfaces:**
- Produces: app / test targets build with iOS 27.0 deployment target

- [ ] **Step 1: Change project.yml**

```yaml
deploymentTarget:
  iOS: "27.0"
```

(Keep watch deployment as-is unless xcodegen requires alignment — do not raise watch unless compile forces it.)

- [ ] **Step 2: Update AGENTS.md**

Replace stack bullet `iOS 17+` with `iOS 27+` (Apple Intelligence / Foundation Models / PCC).

- [ ] **Step 3: Regenerate project + build**

```bash
xcodegen generate
# restore objectVersion / DEVELOPMENT_TEAM if churned
xcodebuild build -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75'
```

Expected: BUILD SUCCEEDED (or fix only deployment-related compile breaks — no AI cut).

- [ ] **Step 4: Commit**

```bash
git add project.yml AGENTS.md HotBod.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
chore: raise deployment target to iOS 27 for Apple Intelligence

EOF
)"
```

---

### Task 2: Protocol + mock + unit tests

**Files:**
- Create: `HotBod/Services/AI/AppleLanguageModeling.swift`
- Create: `HotBod/Services/AI/MockAppleLanguageModeling.swift`
- Create: `HotBod/Tests/UnitTests/AppleLanguageModelingTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum AppleLanguageModelKind: String, Sendable, Equatable {
      case onDevice
      case privateCloudCompute
  }

  enum AppleLanguageModelAvailability: Equatable, Sendable {
      case available
      case unavailable(reason: AppleLanguageModelUnavailableReason)
  }

  enum AppleLanguageModelUnavailableReason: String, Sendable, Equatable {
      case deviceNotEligible
      case systemNotReady
      case appleIntelligenceNotEnabled
      case modelNotReady
      case quotaLimitReached
      case networkRequired
      case notSupportedInThisBuild
      case unknown
  }

  struct AppleLanguageQuotaSnapshot: Equatable, Sendable {
      var isLimitReached: Bool
      var resetDate: Date?
  }

  /// Phase 1 surface: availability + lightweight prompt for future phases.
  /// Does not yet replace coach / physique services.
  protocol AppleLanguageModeling: AnyObject, Sendable {
      func availability(for kind: AppleLanguageModelKind) -> AppleLanguageModelAvailability
      func quota(for kind: AppleLanguageModelKind) -> AppleLanguageQuotaSnapshot?
      func complete(prompt: String, kind: AppleLanguageModelKind) async throws -> String
  }

  enum AppleLanguageModelingError: Error, Equatable {
      case unavailable(AppleLanguageModelUnavailableReason)
      case emptyResponse
  }

  @MainActor
  final class MockAppleLanguageModeling: AppleLanguageModeling {
      var onDeviceAvailability: AppleLanguageModelAvailability = .available
      var pccAvailability: AppleLanguageModelAvailability = .available
      var pccQuota: AppleLanguageQuotaSnapshot? = AppleLanguageQuotaSnapshot(isLimitReached: false, resetDate: nil)
      var cannedResponse: String = "mock-apple-response"
      private(set) var lastPrompt: String?
      private(set) var lastKind: AppleLanguageModelKind?

      // availability/quota/complete as obvious switches over stored vars;
      // complete throws .unavailable if availability != .available
  }
  ```

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import HotBod

@MainActor
final class AppleLanguageModelingTests: XCTestCase {
    func testMockCompleteReturnsCannedResponseWhenAvailable() async throws {
        let mock = MockAppleLanguageModeling()
        mock.cannedResponse = "hello"
        let text = try await mock.complete(prompt: "ping", kind: .onDevice)
        XCTAssertEqual(text, "hello")
        XCTAssertEqual(mock.lastPrompt, "ping")
        XCTAssertEqual(mock.lastKind, .onDevice)
    }

    func testMockCompleteThrowsWhenUnavailable() async {
        let mock = MockAppleLanguageModeling()
        mock.onDeviceAvailability = .unavailable(reason: .deviceNotEligible)
        do {
            _ = try await mock.complete(prompt: "x", kind: .onDevice)
            XCTFail("expected throw")
        } catch let AppleLanguageModelingError.unavailable(reason) {
            XCTAssertEqual(reason, .deviceNotEligible)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testMockPCCQuotaSnapshot() {
        let mock = MockAppleLanguageModeling()
        mock.pccQuota = AppleLanguageQuotaSnapshot(isLimitReached: true, resetDate: nil)
        XCTAssertEqual(mock.quota(for: .privateCloudCompute)?.isLimitReached, true)
        XCTAssertNil(mock.quota(for: .onDevice))
    }
}
```

- [ ] **Step 2: Run — expect FAIL (missing types)**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppleLanguageModelingTests
```

- [ ] **Step 3: Implement protocol + mock** (no FoundationModels import in these two files)

- [ ] **Step 4: Run tests — expect PASS** (add pbxproj refs / xcodegen as needed)

- [ ] **Step 5: Commit**

```bash
git add HotBod/Services/AI/AppleLanguageModeling.swift \
  HotBod/Services/AI/MockAppleLanguageModeling.swift \
  HotBod/Tests/UnitTests/AppleLanguageModelingTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: add AppleLanguageModeling protocol and mock

EOF
)"
```

---

### Task 3: System client + factory + AppEnvironment injection

**Files:**
- Create: `HotBod/Services/AI/SystemAppleLanguageModeling.swift`
- Modify: `HotBod/Data/Remote/BackendServices.swift` (add factory only)
- Modify: `HotBod/App/AppEnvironment.swift` (+ `makeForTests` / `HotBodApp` wiring as needed)
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift` or `AppEnvironment.makeForTests`
- Modify: `HotBod/Tests/UnitTests/AppleLanguageModelingTests.swift` (factory UITesting → mock)

**Interfaces:**
- Produces:
  ```swift
  @MainActor
  final class SystemAppleLanguageModeling: AppleLanguageModeling {
      // Maps SystemLanguageModel.default.availability → AppleLanguageModelAvailability
      // Maps PrivateCloudComputeLanguageModel().availability similarly when API present
      // complete(prompt:kind:):
      //   - onDevice: LanguageModelSession(model: .default) → respond(to: prompt) → String
      //   - pcc: session with PrivateCloudComputeLanguageModel() when available
      // Wrap with #if canImport(FoundationModels); else all kinds → .unavailable(.notSupportedInThisBuild)
  }

  enum BackendServices {
      @MainActor
      static func makeAppleLanguageModeling() -> any AppleLanguageModeling {
          if UITestConfiguration.isUITesting || UITestConfiguration.shouldMockAI {
              return MockAppleLanguageModeling()
          }
          return SystemAppleLanguageModeling()
      }
  }

  // AppEnvironment
  let appleLanguageModeling: any AppleLanguageModeling
  // default: BackendServices.makeAppleLanguageModeling()
  // makeForTests: MockAppleLanguageModeling() unless overridden
  ```

- [ ] **Step 1: Failing test for factory mock under UITesting flag**

If UITestConfiguration is hard to set in unit tests, test `MockAppleLanguageModeling` injection via `AppEnvironment.makeForTests` instead:

```swift
@MainActor
func testMakeForTestsUsesMockAppleLanguageModelingByDefault() async {
    let env = AppEnvironment.makeForTests()
    XCTAssertTrue(env.appleLanguageModeling is MockAppleLanguageModeling)
}
```

- [ ] **Step 2: Implement SystemAppleLanguageModeling**

Implementation notes for implementer:

1. Prefer reading current Apple docs in Xcode for exact `Availability` case names — map known cases; default `.unknown`.
2. `complete` is a **minimal** Phase 1 probe (`respond(to:)` / equivalent string API). Do not add `@Generable` schemas yet (Phase 2/3).
3. If PCC type or APIs are `#available(iOS 27.0, *)` only, guard accordingly.
4. Never call live model from unit tests — factory must return mock in `makeForTests`.

- [ ] **Step 3: Wire AppEnvironment**

Add stored property + init parameter with default `BackendServices.makeAppleLanguageModeling()`. Thread through convenience inits / `makeForTests`.

**Do not** change `makeAIWorkoutService` / physique factories in this task.

- [ ] **Step 4: Build + focused tests**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppleLanguageModelingTests
xcodebuild build -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75'
```

Expected: PASS / BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Services/AI/SystemAppleLanguageModeling.swift \
  HotBod/Data/Remote/BackendServices.swift \
  HotBod/App/AppEnvironment.swift \
  HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod/Tests/UnitTests/AppleLanguageModelingTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: wire SystemAppleLanguageModeling into AppEnvironment

EOF
)"
```

---

## Spec coverage checklist (Phase 1)

| Umbrella Phase 1 acceptance | Task |
|-----------------------------|------|
| Deployment target raised | 1 |
| Thin Apple FM wrapper (availability, on-device, PCC, quota) | 2–3 |
| UITest/simulator mock | 2–3 |
| App builds | 1, 3 |
| No product cut yet | all (explicit non-goal) |

## Out of scope (later phases)

- Physique PCC assess, coach on-device swap, illustration deletion, Supabase/USDA strip

## Plan self-review notes

- Floor is **27.0** because PCC APIs are documented iOS 27+; on-device alone would be 26.0.
- Phase 1 `complete(prompt:)` is a scaffolding probe, not production coach/assess.
- OpenAI/Gemini paths intentionally remain until Phases 2–3.

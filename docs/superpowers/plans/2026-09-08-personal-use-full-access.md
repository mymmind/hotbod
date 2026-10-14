# Personal Use Full Access Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the single personal user full Pro access and real (Gemini) coaching without Sign In, via one compile-time flag.

**Architecture:** `PersonalUseConfig.isEnabled` (default `true`) drives Pro unlock, hides Account/Cloud UI, skips Supabase session restore, and routes the coach through `AIWorkoutServiceSelection` to Gemini/mock instead of `RemoteAIWorkoutService`. Remote physique/illustration factories return Unavailable. Supabase code stays in the repo, unused.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XcodeGen (`xcodegen generate` after new `HotBod/` files), `HotBod.xctestplan` configuration **PR**.

**Spec:** `docs/superpowers/specs/2026-09-08-personal-use-full-access-design.md`

## Global Constraints

- iOS 26+ / Swift 6; local-first; no new backend; no secrets.
- `PersonalUseConfig.defaultIsEnabled = true`. Flip to `false` only before a public release (not this work).
- `SubscriptionConfig.unrestrictedAccessOverride` stays the first `??` (highest priority). Do not change existing paywall tests.
- Do not delete Supabase, edge functions, `SupabaseConfig.plist`, StoreKit, or paywall views.
- Do not wire Apple Intelligence into the coach. Do not expand Gemini general-chat coverage.
- Do not change `RemoteAIWorkoutService` sign-in copy (that type is not constructed while the flag is on).
- Never show “Sign in” / “Sign in to generate.” / “Sign in under Settings” while personal use is on.
- After new Swift files under `HotBod/`, run `xcodegen generate`. If `objectVersion` / `DEVELOPMENT_TEAM` churn, restore those baselines.
- Simulator: `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0`. If missing, run `xcodebuild -scheme HotBod -showdestinations` and substitute an installed iPhone 26.x simulator.
- Do not commit unrelated dirty files (e.g. `HotBod/Resources/Localizable.xcstrings` unless this work edits it).

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/App/PersonalUseConfig.swift` | Flag, test override, account-UI + remote-intelligence gates |
| `HotBod/Services/AI/AIWorkoutServiceSelection.swift` | Pure coach routing: `.remote` / `.gemini` / `.mock` |
| `HotBod/Services/Subscription/ForgeSubscriptionProducts.swift` | `unrestrictedAccess` ORs in personal use |
| `HotBod/Data/Remote/BackendServices.swift` | Use selection; skip remote physique/illustration |
| `HotBod/Features/Settings/SettingsView.swift` | Hide Account/Cloud when personal use |
| `HotBod/Features/Settings/SettingsView+Profile.swift` | Plan label “Full access”; local delete when account UI hidden |
| `HotBod/App/AppEnvironment.swift` | Skip `restoreSession` / `pullFromCloud` when personal use |
| `HotBod/App/AppEnvironment+Physique.swift` | Illustration `.notConfigured` copy is not sign-in |
| `HotBod/Tests/UnitTests/PersonalUseConfigTests.swift` | Flag + unrestrictedAccess formula |
| `HotBod/Tests/UnitTests/AIWorkoutServiceSelectionTests.swift` | Coach routing table |
| `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift` | Paywall no-op + bootstrap skip restore |

Do not modify `supabase/functions/`, `SupabaseAuthService`, or `RemoteAIWorkoutService`.

---

### Task 1: PersonalUseConfig (TDD)

**Files:**
- Create: `HotBod/Tests/UnitTests/PersonalUseConfigTests.swift`
- Create: `HotBod/App/PersonalUseConfig.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `PersonalUseConfig.defaultIsEnabled: Bool`, `isEnabledOverride: Bool?`, `isEnabled: Bool`, `shouldShowCloudAccountUI(supabaseConfigured: Bool) -> Bool`, `shouldUseRemoteIntelligence: Bool`

- [ ] **Step 1: Write the failing tests**

Create `HotBod/Tests/UnitTests/PersonalUseConfigTests.swift`:

```swift
import XCTest
@testable import HotBod

final class PersonalUseConfigTests: XCTestCase {
    override func tearDown() {
        PersonalUseConfig.isEnabledOverride = nil
        super.tearDown()
    }

    func testDefaultIsEnabled() {
        PersonalUseConfig.isEnabledOverride = nil
        XCTAssertTrue(PersonalUseConfig.isEnabled)
        XCTAssertTrue(PersonalUseConfig.defaultIsEnabled)
    }

    func testOverrideFalseDisablesPersonalUse() {
        PersonalUseConfig.isEnabledOverride = false
        XCTAssertFalse(PersonalUseConfig.isEnabled)
        XCTAssertTrue(PersonalUseConfig.shouldUseRemoteIntelligence)
        XCTAssertTrue(PersonalUseConfig.shouldShowCloudAccountUI(supabaseConfigured: true))
        XCTAssertFalse(PersonalUseConfig.shouldShowCloudAccountUI(supabaseConfigured: false))
    }

    func testPersonalUseHidesAccountAndSkipsRemoteIntelligence() {
        PersonalUseConfig.isEnabledOverride = true
        XCTAssertTrue(PersonalUseConfig.isEnabled)
        XCTAssertFalse(PersonalUseConfig.shouldUseRemoteIntelligence)
        XCTAssertFalse(PersonalUseConfig.shouldShowCloudAccountUI(supabaseConfigured: true))
        XCTAssertFalse(PersonalUseConfig.shouldShowCloudAccountUI(supabaseConfigured: false))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/PersonalUseConfigTests
```

Expected: FAIL — `PersonalUseConfig` not found.

- [ ] **Step 3: Write the config**

Create `HotBod/App/PersonalUseConfig.swift`:

```swift
import Foundation

enum PersonalUseConfig {
    static let defaultIsEnabled = true

    /// Unit-test seam. Always clear in `defer`/tearDown.
    nonisolated(unsafe) static var isEnabledOverride: Bool?

    static var isEnabled: Bool {
        isEnabledOverride ?? defaultIsEnabled
    }

    static func shouldShowCloudAccountUI(supabaseConfigured: Bool) -> Bool {
        supabaseConfigured && !isEnabled
    }

    static var shouldUseRemoteIntelligence: Bool { !isEnabled }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/PersonalUseConfigTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/App/PersonalUseConfig.swift \
  HotBod/Tests/UnitTests/PersonalUseConfigTests.swift \
  HotBod.xcodeproj/project.pbxproj project.yml
git commit -m "$(cat <<'EOF'
feat: add PersonalUseConfig full-access flag

Compile-time personal-use switch that hides cloud account UI and skips remote intelligence until a public release.
EOF
)"
```

Only stage `project.pbxproj` hunks caused by `xcodegen generate` for these new files. Restore `objectVersion` / `DEVELOPMENT_TEAM` if they churned.

---

### Task 2: Unlock Pro via unrestrictedAccess (TDD)

**Files:**
- Modify: `HotBod/Tests/UnitTests/PersonalUseConfigTests.swift`
- Modify: `HotBod/Services/Subscription/ForgeSubscriptionProducts.swift` (`unrestrictedAccess`)
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift` (add paywall no-op test near existing quota tests)

**Interfaces:**
- Consumes: `PersonalUseConfig.isEnabled`
- Produces: `SubscriptionConfig.unrestrictedAccess` = `unrestrictedAccessOverride ?? (PersonalUseConfig.isEnabled || defaultUnrestrictedAccess)`

- [ ] **Step 1: Write the failing tests**

Append to `PersonalUseConfigTests`:

```swift
    func testUnrestrictedAccessTrueWhenPersonalUseEnabled() {
        PersonalUseConfig.isEnabledOverride = true
        SubscriptionConfig.unrestrictedAccessOverride = nil
        defer { SubscriptionConfig.unrestrictedAccessOverride = nil }
        XCTAssertTrue(SubscriptionConfig.unrestrictedAccess)
    }

    func testUnrestrictedAccessOverrideFalseWinsOverPersonalUse() {
        PersonalUseConfig.isEnabledOverride = true
        SubscriptionConfig.unrestrictedAccessOverride = false
        defer { SubscriptionConfig.unrestrictedAccessOverride = nil }
        XCTAssertFalse(SubscriptionConfig.unrestrictedAccess)
    }
```

In `AppEnvironmentOrchestrationTests` (same file as `testRegression_nonPreferredDayUserRegenerateUsesStandardQuotaPath`), add:

```swift
    func testPresentPaywallNoOpWhenPersonalUseEnabled() {
        PersonalUseConfig.isEnabledOverride = true
        SubscriptionConfig.unrestrictedAccessOverride = nil
        defer {
            PersonalUseConfig.isEnabledOverride = nil
            SubscriptionConfig.unrestrictedAccessOverride = nil
        }
        let env = AppEnvironment.makeForTests()
        env.presentPaywall(for: .unlimitedGeneration)
        XCTAssertNil(env.paywallFeature)
        XCTAssertTrue(env.canAccess(.coachWorkoutApply))
        XCTAssertTrue(env.canAccess(.bodyPhotoHistory))
        XCTAssertTrue(env.canAccess(.workoutExport))
    }
```

Do **not** edit `testRegression_nonPreferredDayUserRegenerateUsesStandardQuotaPath`. It already sets `unrestrictedAccessOverride = false`.

- [ ] **Step 2: Compile and run the new tests**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/PersonalUseConfigTests \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testPresentPaywallNoOpWhenPersonalUseEnabled
```

Expected: tests compile and PASS in DEBUG even before Step 3 (`defaultUnrestrictedAccess` is already `true`; `unrestrictedAccessOverride = false` already wins). Still apply Step 3 so **Release** builds unlock when personal use is on.

- [ ] **Step 3: Wire the OR**

In `ForgeSubscriptionProducts.swift`, replace `unrestrictedAccess`:

```swift
    static var unrestrictedAccess: Bool {
        unrestrictedAccessOverride ?? (PersonalUseConfig.isEnabled || defaultUnrestrictedAccess)
    }
```

Leave `defaultUnrestrictedAccess` as `#if DEBUG true / #else false`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/PersonalUseConfigTests \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testPresentPaywallNoOpWhenPersonalUseEnabled \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testRegression_nonPreferredDayUserRegenerateUsesStandardQuotaPath
```

Expected: PASS. The quota regression must still present a paywall when override is `false`.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Services/Subscription/ForgeSubscriptionProducts.swift \
  HotBod/Tests/UnitTests/PersonalUseConfigTests.swift \
  HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift
git commit -m "$(cat <<'EOF'
feat: treat personal use as unrestricted Pro access

Release builds unlock paywalls and regen limits while PersonalUseConfig is on; test override still forces free-tier.
EOF
)"
```

---

### Task 3: Coach routing table (TDD)

**Files:**
- Create: `HotBod/Tests/UnitTests/AIWorkoutServiceSelectionTests.swift`
- Create: `HotBod/Services/AI/AIWorkoutServiceSelection.swift`

**Interfaces:**
- Consumes: three `Bool` flags (does not read configs itself)
- Produces: `AIWorkoutServiceSelection.preferred(personalUse:supabaseConfigured:geminiConfigured:) -> AIWorkoutServiceSelection`

- [ ] **Step 1: Write the failing tests**

Create `HotBod/Tests/UnitTests/AIWorkoutServiceSelectionTests.swift`:

```swift
import XCTest
@testable import HotBod

final class AIWorkoutServiceSelectionTests: XCTestCase {
    func testPersonalUsePrefersGeminiEvenIfSupabaseConfigured() {
        XCTAssertEqual(
            AIWorkoutServiceSelection.preferred(
                personalUse: true,
                supabaseConfigured: true,
                geminiConfigured: true
            ),
            .gemini
        )
    }

    func testPersonalUseFallsBackToMockWithoutGemini() {
        XCTAssertEqual(
            AIWorkoutServiceSelection.preferred(
                personalUse: true,
                supabaseConfigured: true,
                geminiConfigured: false
            ),
            .mock
        )
    }

    func testPersonalUseOffPrefersRemoteWhenSupabaseConfigured() {
        XCTAssertEqual(
            AIWorkoutServiceSelection.preferred(
                personalUse: false,
                supabaseConfigured: true,
                geminiConfigured: true
            ),
            .remote
        )
    }

    func testPersonalUseOffPrefersGeminiWhenOnlyGeminiConfigured() {
        XCTAssertEqual(
            AIWorkoutServiceSelection.preferred(
                personalUse: false,
                supabaseConfigured: false,
                geminiConfigured: true
            ),
            .gemini
        )
    }

    func testPersonalUseOffMockWhenNothingConfigured() {
        XCTAssertEqual(
            AIWorkoutServiceSelection.preferred(
                personalUse: false,
                supabaseConfigured: false,
                geminiConfigured: false
            ),
            .mock
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/AIWorkoutServiceSelectionTests
```

Expected: FAIL — `AIWorkoutServiceSelection` not found.

- [ ] **Step 3: Write the selection enum**

Create `HotBod/Services/AI/AIWorkoutServiceSelection.swift`:

```swift
import Foundation

enum AIWorkoutServiceSelection: Equatable {
    case remote
    case gemini
    case mock

    static func preferred(
        personalUse: Bool,
        supabaseConfigured: Bool,
        geminiConfigured: Bool
    ) -> Self {
        if personalUse {
            return geminiConfigured ? .gemini : .mock
        }
        if supabaseConfigured { return .remote }
        if geminiConfigured { return .gemini }
        return .mock
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/AIWorkoutServiceSelectionTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Services/AI/AIWorkoutServiceSelection.swift \
  HotBod/Tests/UnitTests/AIWorkoutServiceSelectionTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat: route personal-use coach to Gemini instead of Supabase

Keep remote as the non-personal default when Supabase is configured; skip it entirely while the personal-use flag is on.
EOF
)"
```

---

### Task 4: BackendServices skip remote intelligence

**Files:**
- Modify: `HotBod/Data/Remote/BackendServices.swift` (`makeAIWorkoutService`, `makeRemotePhysiqueAssessmentService`, `makePhysiqueIllustrationService`)

**Interfaces:**
- Consumes: `AIWorkoutServiceSelection.preferred`, `PersonalUseConfig.isEnabled`, `PersonalUseConfig.shouldUseRemoteIntelligence`, `GeminiConfig.isConfigured`, `SupabaseConfig.isConfigured`
- Produces: Gemini or mock coach while personal use is on; Unavailable remote physique/illustration while `!shouldUseRemoteIntelligence`

- [ ] **Step 1: Replace `makeAIWorkoutService`**

```swift
    static func makeAIWorkoutService(
        auth: AuthService,
        exerciseRepository: any ExerciseRepository = LocalExerciseRepository()
    ) -> AIWorkoutService {
        let selection = AIWorkoutServiceSelection.preferred(
            personalUse: PersonalUseConfig.isEnabled,
            supabaseConfigured: SupabaseConfig.isConfigured,
            geminiConfigured: GeminiConfig.isConfigured
        )

        switch selection {
        case .remote:
            #if canImport(Supabase)
            if let client = SupabaseClientProvider.shared {
                return RemoteAIWorkoutService(client: client, auth: auth)
            }
            #endif
            if GeminiConfig.isConfigured {
                return GeminiAIWorkoutService(exerciseRepository: exerciseRepository)
            }
            return MockAIWorkoutService()
        case .gemini:
            return GeminiAIWorkoutService(exerciseRepository: exerciseRepository)
        case .mock:
            return MockAIWorkoutService()
        }
    }
```

- [ ] **Step 2: Skip remote physique when personal use**

Replace the body of `makeRemotePhysiqueAssessmentService`:

```swift
    static func makeRemotePhysiqueAssessmentService(auth: AuthService) -> any PhysiqueAssessmentServing {
        guard PersonalUseConfig.shouldUseRemoteIntelligence else {
            return UnavailablePhysiqueAssessmentService()
        }
        #if canImport(Supabase)
        if SupabaseConfig.isConfigured, let client = SupabaseClientProvider.shared {
            return RemotePhysiqueAssessmentService(client: client, auth: auth)
        }
        #endif
        return UnavailablePhysiqueAssessmentService()
    }
```

- [ ] **Step 3: Skip remote illustration when personal use**

Replace the Supabase branch in `makePhysiqueIllustrationService` so personal use never constructs `RemotePhysiqueIllustrationService`. Keep the UITest/mock-AI early return unchanged:

```swift
    static func makePhysiqueIllustrationService(auth: AuthService = makeAuthService()) -> any PhysiqueIllustrationService {
        if UITestConfiguration.isUITesting || UITestConfiguration.shouldMockAI {
            return MockPhysiqueIllustrationService()
        }

        guard PersonalUseConfig.shouldUseRemoteIntelligence else {
            return UnavailablePhysiqueIllustrationService()
        }

        #if canImport(Supabase)
        if SupabaseConfig.isConfigured, let client = SupabaseClientProvider.shared {
            return RemotePhysiqueIllustrationService(client: client, auth: auth)
        }
        #endif

        return UnavailablePhysiqueIllustrationService()
    }
```

Leave `makeAuthService` and `makeCloudSyncService` unchanged.

- [ ] **Step 4: Build to confirm compile**

```bash
xcodebuild build -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Data/Remote/BackendServices.swift
git commit -m "$(cat <<'EOF'
feat: skip Supabase coach and physique while personal use is on

Factory now honors AIWorkoutServiceSelection and Unavailable remote physique so Gemini/offline paths run without a JWT.
EOF
)"
```

---

### Task 5: Hide Account UI and local delete

**Files:**
- Modify: `HotBod/Features/Settings/SettingsView.swift` (cloud/account block ~82–97)
- Modify: `HotBod/Features/Settings/SettingsView+Profile.swift` (Plan label ~69–74; delete row ~117)

**Interfaces:**
- Consumes: `PersonalUseConfig.shouldShowCloudAccountUI(supabaseConfigured:)`, `SubscriptionConfig.unrestrictedAccess`
- Produces: no Account/Cloud/plist-hint sections while personal use is on; Plan value `"Full access"`; App-section Delete All Data when account UI is hidden

- [ ] **Step 1: Gate Settings cloud sections**

In `SettingsView.swift` `settingsBody`, replace the `if environment.isSupabaseConfigured` block with:

```swift
                    if PersonalUseConfig.shouldShowCloudAccountUI(
                        supabaseConfigured: environment.isSupabaseConfigured
                    ) {
                        accountSection
                        cloudSection
                    }
```

Do not keep the DEBUG plist-hint `else` branch. Cloud is unused while personal use is on.

- [ ] **Step 2: Plan label + delete placement**

In `SettingsView+Profile.swift` `appSection`, change the Plan value:

```swift
                value: SubscriptionConfig.unrestrictedAccess
                    ? "Full access"
                    : (environment.isPro ? "Pro" : "Free (\(environment.remainingFreeRegenerations) regen left)")
```

Replace `if !environment.isSupabaseConfigured {` around the Delete All Data row with:

```swift
            if !PersonalUseConfig.shouldShowCloudAccountUI(
                supabaseConfigured: environment.isSupabaseConfigured
            ) {
```

Leave the Upgrade row as `if !SubscriptionConfig.unrestrictedAccess, !environment.isPro` (it will not show while personal use is on).

- [ ] **Step 3: Build**

```bash
xcodebuild build -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add HotBod/Features/Settings/SettingsView.swift \
  HotBod/Features/Settings/SettingsView+Profile.swift
git commit -m "$(cat <<'EOF'
feat: hide Settings account UI during personal use

Account, sync, and cloud-backup rows stay out of Settings; local Delete All Data remains in the App section.
EOF
)"
```

---

### Task 6: Skip session restore on bootstrap (TDD)

**Files:**
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift`
- Modify: `HotBod/App/AppEnvironment.swift` (`bootstrap`, session restore block ~237–246)

**Interfaces:**
- Consumes: `PersonalUseConfig.isEnabled`
- Produces: bootstrap does not call `restoreSession` / `pullFromCloud` when personal use is on; leftover device sessions are ignored (no `signOut`)

- [ ] **Step 1: Write the failing tests**

Add a `RestoringAuthService` next to `TrackingAuthService` at the bottom of `AppEnvironmentOrchestrationTests.swift`:

```swift
private final class SessionRestoringAuthService: AuthService, @unchecked Sendable {
    var isAvailable: Bool { true }
    private(set) var restoreCalls = 0

    func currentUserId() async -> UUID? { UUID() }
    func currentEmail() async -> String? { "test@example.com" }
    func signUp(email: String, password: String) async throws {}
    func signIn(email: String, password: String) async throws {}
    func signOut() async throws {}
    func deleteAccount() async throws {}
    func restoreSession() async -> Bool {
        restoreCalls += 1
        return true
    }
}
```

Add tests on `AppEnvironmentAccountDeletionTests` **or** a new `@MainActor final class AppEnvironmentPersonalUseBootstrapTests: XCTestCase` in the same file:

```swift
@MainActor
final class AppEnvironmentPersonalUseBootstrapTests: XCTestCase {
    func testBootstrapSkipsSessionRestoreWhenPersonalUseEnabled() async {
        PersonalUseConfig.isEnabledOverride = true
        defer { PersonalUseConfig.isEnabledOverride = nil }

        let auth = SessionRestoringAuthService()
        let env = AppEnvironment.makeForTests(authService: auth)
        await env.bootstrap()

        XCTAssertEqual(auth.restoreCalls, 0)
        XCTAssertFalse(env.isSignedIn)
        XCTAssertNil(env.authEmail)
    }

    func testBootstrapRestoresSessionWhenPersonalUseDisabled() async {
        PersonalUseConfig.isEnabledOverride = false
        defer { PersonalUseConfig.isEnabledOverride = nil }

        let auth = SessionRestoringAuthService()
        let env = AppEnvironment.makeForTests(authService: auth)
        await env.bootstrap()

        XCTAssertEqual(auth.restoreCalls, 1)
        XCTAssertTrue(env.isSignedIn)
        XCTAssertEqual(env.authEmail, "test@example.com")
    }
}
```

`makeForTests` must pass `authService:` through (it already does via `FixtureBuilders` / `AppEnvironment.makeForTests`). If UITest skip-onboarding is not set, bootstrap reaches the restore block.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/AppEnvironmentPersonalUseBootstrapTests
```

Expected: FAIL — `testBootstrapSkipsSessionRestoreWhenPersonalUseEnabled` sees `restoreCalls == 1` because bootstrap still restores whenever `auth.isAvailable`.

- [ ] **Step 3: Skip restore when personal use is on**

In `AppEnvironment.bootstrap`, change:

```swift
        if authService.isAvailable, await authService.restoreSession() {
```

to:

```swift
        if !PersonalUseConfig.isEnabled,
           authService.isAvailable,
           await authService.restoreSession() {
```

Do not call `signOut`. Leave the inner pull/merge body as-is.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/AppEnvironmentPersonalUseBootstrapTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/App/AppEnvironment.swift \
  HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift
git commit -m "$(cat <<'EOF'
feat: skip Supabase session restore during personal use

Bootstrap stays on local SwiftData and ignores a leftover cloud session instead of pulling remote state.
EOF
)"
```

---

### Task 7: Illustration copy without Sign In (TDD)

**Files:**
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift`
- Modify: `HotBod/App/AppEnvironment+Physique.swift` (`physiqueIllustrationStatusMessage`)

**Interfaces:**
- Consumes: `PhysiqueIllustrationError`
- Produces: `.notConfigured` user string `"Illustration unavailable."` (same as `.unavailable`)

- [ ] **Step 1: Write the failing test**

`physiqueIllustrationStatusMessage` is `private`. Make it `func` (internal) on `AppEnvironment` so tests can call it, **or** add this orchestration test that uses `UnavailablePhysiqueIllustrationService`.

Prefer a focused unit test: change the method from `private func` to `func` (internal) and add to `AppEnvironmentPhysiqueOrchestrationTests`:

```swift
    func testIllustrationNotConfiguredCopyIsNotSignIn() {
        let env = AppEnvironment.makeForTests()
        XCTAssertEqual(
            env.physiqueIllustrationStatusMessage(for: .notConfigured),
            "Illustration unavailable."
        )
        XCTAssertFalse(
            env.physiqueIllustrationStatusMessage(for: .notConfigured)
                .localizedCaseInsensitiveContains("sign in")
        )
    }
```

After Step 1, `physiqueIllustrationStatusMessage` is still private so the test will not compile. In the same edit as the test, change `private func physiqueIllustrationStatusMessage` to `func physiqueIllustrationStatusMessage` so the test compiles and can fail on the string.

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests/testIllustrationNotConfiguredCopyIsNotSignIn
```

Expected: FAIL — `XCTAssertEqual` expected `"Illustration unavailable."`, got `"Sign in to generate."`

- [ ] **Step 3: Change the copy**

```swift
        case .notConfigured:
            return "Illustration unavailable."
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests/testIllustrationNotConfiguredCopyIsNotSignIn
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add HotBod/App/AppEnvironment+Physique.swift \
  HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift
git commit -m "$(cat <<'EOF'
fix: drop sign-in copy from physique illustration errors

Not-configured illustration now uses the same unavailable message as other local failures.
EOF
)"
```

---

### Task 8: PR verification

**Files:** none new

- [ ] **Step 1: Run new unit tests together**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/PersonalUseConfigTests \
  -only-testing:HotBodTests/AIWorkoutServiceSelectionTests \
  -only-testing:HotBodTests/AppEnvironmentPersonalUseBootstrapTests \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests/testIllustrationNotConfiguredCopyIsNotSignIn \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testPresentPaywallNoOpWhenPersonalUseEnabled \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testRegression_nonPreferredDayUserRegenerateUsesStandardQuotaPath
```

Expected: PASS.

- [ ] **Step 2: Run PR test plan**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -testPlan HotBod
```

If that runs Nightly, use the PR configuration explicitly:

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -testPlan HotBod \
  -only-testing:HotBodTests \
  -only-testing:HotBodUITests/LaunchUITests \
  -only-testing:HotBodUITests/TodayWorkoutUITests \
  -only-testing:HotBodUITests/ProteinTrackerUITests \
  -only-testing:HotBodUITests/PhysiqueUITests \
  -only-testing:HotBodUITests/WorkoutSessionUITests \
  -only-testing:HotBodUITests/SettingsUITests
```

Expected: PASS. `SettingsUITests/testExportTrainingDataRowExists` must still pass (export row was not removed).

- [ ] **Step 3: Manual smoke (if a simulator is available)**

Launch the app (not UITest). Confirm: Settings has no Sign In / Create Account / Sync / Photo cloud backup; Plan reads “Full access”; Delete All Data is still in App; Coach replies without asking to sign in (Gemini if `GeminiConfig.plist` is valid). Do not tap Delete All Data.

If no GUI simulator, skip and note it in the wrap-up.

No commit unless Steps 1–2 forced a fix; if they did, commit the fix as `fix: <what broke>` then re-run Steps 1–2.

---

## Spec coverage

| Spec requirement | Task |
|-----------------|------|
| `PersonalUseConfig` flag + override | 1 |
| `shouldShowCloudAccountUI` / `shouldUseRemoteIntelligence` | 1, 5 |
| `unrestrictedAccess` OR personal use; override still wins | 2 |
| `AIWorkoutServiceSelection` table | 3 |
| BackendServices Gemini/mock; skip remote physique/illustration | 4 |
| Hide Account/Cloud; no plist hint | 5 |
| Plan “Full access”; no Upgrade | 5 |
| Delete All Data when account UI hidden | 5 |
| Bootstrap skip restore, no signOut | 6 |
| Illustration copy not “Sign in to generate.” | 7 |
| Leave Supabase in repo | all (no delete tasks) |
| PR tests pass | 8 |

# Physique Split Suggestion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the Physique report, offer a one-shot Apply/Not now card when the days/week–suggested split concentrates Physique focus muscles better than the current template; Apply updates split, resets rotation, regenerates today.

**Architecture:** Pure `PhysiqueSplitSuggestionEvaluator` (concentration millipoint scores + gates). Local `PhysiqueSplitSuggestionPreferences` stores dismissed/handled assessment id. `AppEnvironment` evaluates/applies/dismisses with rollback on regenerate failure. Report UI below “Why today’s training”; history views pass `nil` suggestion.

**Tech Stack:** Swift 6, SwiftUI, XCTest, UserDefaults, XcodeGen if new files need project sync, `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-08-11-physique-split-suggestion-design.md`

## Global Constraints

- iOS 17+.
- Local-first; Settings `preferredSplit` is source of truth after Apply (no temporary override).
- Prefer: “better fit for your current focus,” “Better split for your focus.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims, “optimal program” guarantees.
- Soft / opt-in only — never auto-change split; avoided muscles still stripped before scoring.
- Coverage uses **concentration millipoints** (`1000 / dayMuscleCount`), not raw hits (Full Body must not always win).
- After new Swift files under `HotBod/`, run `xcodegen generate` if the target does not auto-pick them; restore `objectVersion` / `DEVELOPMENT_TEAM` churn.
- Simulator: `id=EB7BE0BD-179B-4A37-9202-69D87FC47B75` if needed.
- Regression tests use `testRegression_` where applicable.
- Do not alter unrelated uncommitted local changes.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Physique/PhysiqueSplitSuggestion.swift` | Model + evaluator + suggestedSplit + concentration score |
| `HotBod/Features/Onboarding/OnboardingProfileEditing.swift` | Wrapper → Domain `suggestedSplit` |
| `HotBod/Services/Physique/PhysiqueSplitSuggestionPreferences.swift` | UserDefaults dismissed/handled id |
| `HotBod/App/AppEnvironment+Physique.swift` | evaluate / dismiss / apply (+ wipe clear) |
| `HotBod/App/AppEnvironment+Account.swift` | Clear prefs on wipe |
| `HotBod/Features/Physique/PhysiqueAssessmentReportContent.swift` | Card + dialog below why-today |
| `HotBod/Features/Physique/PhysiqueView.swift` | Wire env suggestion + actions for active report |
| `HotBod/App/UITestConfiguration.swift` | `-SeedPhysiqueSplitSuggestion` |
| `HotBod/Tests/UITests/BaseUITestCase.swift` | Launch flag |
| `HotBod/Tests/UnitTests/PhysiqueSplitSuggestionTests.swift` | Domain unit tests |
| `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift` | Apply / dismiss / wipe |
| `HotBod/Tests/UITests/PhysiqueSplitSuggestionUITests.swift` | Card smoke |
| `HotBod/Resources/Localizable.xcstrings` | New user-facing strings if project syncs them |

---

### Task 1: Domain evaluator + onboarding wrapper

**Files:**
- Create: `HotBod/Domain/Physique/PhysiqueSplitSuggestion.swift`
- Create: `HotBod/Tests/UnitTests/PhysiqueSplitSuggestionTests.swift`
- Modify: `HotBod/Features/Onboarding/OnboardingProfileEditing.swift` (`suggestedSplit`)

**Interfaces:**
- Produces:
  ```swift
  struct PhysiqueSplitSuggestion: Equatable, Sendable {
      var assessmentId: UUID
      var from: TrainingSplit
      var to: TrainingSplit
      var scoreCurrent: Int
      var scoreCandidate: Int
      var highlightMuscles: [MuscleGroup]
  }

  enum PhysiqueSplitSuggestionEvaluator {
      /// Same rules as legacy onboarding: …3 fullBody, 4 UL, 5…6 PPL, else adaptive.
      static func suggestedSplit(forDaysPerWeek days: Int) -> TrainingSplit

      /// Concentration millipoints for `preferred` over `daysPerWeek` cycled sessions.
      static func coverageScore(
          split: TrainingSplit,
          daysPerWeek: Int,
          preferred: [MuscleGroup]
      ) -> Int

      static func evaluate(
          assessmentId: UUID,
          currentSplit: TrainingSplit,
          daysPerWeek: Int,
          preferredMuscleGroups: [MuscleGroup],
          avoidedMuscleGroups: [MuscleGroup],
          dismissedAssessmentId: UUID?
      ) -> PhysiqueSplitSuggestion?
  }
  ```

- [ ] **Step 1: Write failing unit tests**

```swift
import XCTest
@testable import HotBod

final class PhysiqueSplitSuggestionTests: XCTestCase {
    func testSuggestedSplitMatchesOnboardingHeuristic() {
        XCTAssertEqual(PhysiqueSplitSuggestionEvaluator.suggestedSplit(forDaysPerWeek: 3), .fullBody)
        XCTAssertEqual(PhysiqueSplitSuggestionEvaluator.suggestedSplit(forDaysPerWeek: 4), .upperLower)
        XCTAssertEqual(PhysiqueSplitSuggestionEvaluator.suggestedSplit(forDaysPerWeek: 5), .pushPullLegs)
        XCTAssertEqual(PhysiqueSplitSuggestionEvaluator.suggestedSplit(forDaysPerWeek: 6), .pushPullLegs)
        XCTAssertEqual(PhysiqueSplitSuggestionEvaluator.suggestedSplit(forDaysPerWeek: 7), .adaptive)
    }

    func testCoveragePPLBeatsFullBodyForShouldersBackAtSixDays() {
        let preferred: [MuscleGroup] = [.shoulders, .back]
        let full = PhysiqueSplitSuggestionEvaluator.coverageScore(
            split: .fullBody, daysPerWeek: 6, preferred: preferred
        )
        let ppl = PhysiqueSplitSuggestionEvaluator.coverageScore(
            split: .pushPullLegs, daysPerWeek: 6, preferred: preferred
        )
        XCTAssertGreaterThan(ppl, full)
    }

    func testEvaluateSuggestsPPLWhenOnFullBodySixDays() {
        let id = UUID()
        let suggestion = PhysiqueSplitSuggestionEvaluator.evaluate(
            assessmentId: id,
            currentSplit: .fullBody,
            daysPerWeek: 6,
            preferredMuscleGroups: [.shoulders, .back],
            avoidedMuscleGroups: [],
            dismissedAssessmentId: nil
        )
        XCTAssertEqual(suggestion?.to, .pushPullLegs)
        XCTAssertEqual(suggestion?.from, .fullBody)
        XCTAssertEqual(suggestion?.assessmentId, id)
        XCTAssertFalse(suggestion?.highlightMuscles.isEmpty ?? true)
    }

    func testEvaluateNilWhenCandidateEqualsCurrent() {
        let suggestion = PhysiqueSplitSuggestionEvaluator.evaluate(
            assessmentId: UUID(),
            currentSplit: .pushPullLegs,
            daysPerWeek: 6,
            preferredMuscleGroups: [.shoulders, .back],
            avoidedMuscleGroups: [],
            dismissedAssessmentId: nil
        )
        XCTAssertNil(suggestion)
    }

    func testEvaluateNilWhenDismissedForAssessment() {
        let id = UUID()
        let suggestion = PhysiqueSplitSuggestionEvaluator.evaluate(
            assessmentId: id,
            currentSplit: .fullBody,
            daysPerWeek: 6,
            preferredMuscleGroups: [.shoulders, .back],
            avoidedMuscleGroups: [],
            dismissedAssessmentId: id
        )
        XCTAssertNil(suggestion)
    }

    func testEvaluateNilWhenPreferredEmptyAfterAvoided() {
        let suggestion = PhysiqueSplitSuggestionEvaluator.evaluate(
            assessmentId: UUID(),
            currentSplit: .fullBody,
            daysPerWeek: 6,
            preferredMuscleGroups: [.shoulders],
            avoidedMuscleGroups: [.shoulders],
            dismissedAssessmentId: nil
        )
        XCTAssertNil(suggestion)
    }

    func testEvaluateNilWhenCandidateNotBetter() {
        // Same sequence family: arnold vs PPL → equal concentration → nil
        let suggestion = PhysiqueSplitSuggestionEvaluator.evaluate(
            assessmentId: UUID(),
            currentSplit: .arnold,
            daysPerWeek: 6,
            preferredMuscleGroups: [.shoulders, .back],
            avoidedMuscleGroups: [],
            dismissedAssessmentId: nil
        )
        // candidate is PPL; scores equal → nil
        XCTAssertNil(suggestion)
    }

    func testAdaptiveUsesUpperLowerUnionSet() {
        let preferred: [MuscleGroup] = [.shoulders, .quads]
        let score = PhysiqueSplitSuggestionEvaluator.coverageScore(
            split: .adaptive, daysPerWeek: 7, preferred: preferred
        )
        XCTAssertGreaterThan(score, 0)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL (types missing)**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueSplitSuggestionTests
```

Expected: compile error / missing type.

- [ ] **Step 3: Implement domain + wrapper**

`HotBod/Domain/Physique/PhysiqueSplitSuggestion.swift`:

```swift
import Foundation

struct PhysiqueSplitSuggestion: Equatable, Sendable {
    var assessmentId: UUID
    var from: TrainingSplit
    var to: TrainingSplit
    var scoreCurrent: Int
    var scoreCandidate: Int
    var highlightMuscles: [MuscleGroup]
}

enum PhysiqueSplitSuggestionEvaluator {
    private static let millipointBudget = 1000

    static func suggestedSplit(forDaysPerWeek days: Int) -> TrainingSplit {
        switch days {
        case ...3: .fullBody
        case 4: .upperLower
        case 5...6: .pushPullLegs
        default: .adaptive
        }
    }

    static func coverageScore(
        split: TrainingSplit,
        daysPerWeek: Int,
        preferred: [MuscleGroup]
    ) -> Int {
        guard !preferred.isEmpty else { return 0 }
        var total = 0
        for muscles in muscleSets(split: split, daysPerWeek: daysPerWeek) {
            let weight = millipointBudget / max(muscles.count, 1)
            for m in preferred where muscles.contains(m) {
                total += weight
            }
        }
        return total
    }

    static func evaluate(
        assessmentId: UUID,
        currentSplit: TrainingSplit,
        daysPerWeek: Int,
        preferredMuscleGroups: [MuscleGroup],
        avoidedMuscleGroups: [MuscleGroup],
        dismissedAssessmentId: UUID?
    ) -> PhysiqueSplitSuggestion? {
        if dismissedAssessmentId == assessmentId { return nil }
        let preferred = PhysiqueTrainingBiasMerger.physiquePreferredMuscleGroups(
            assessmentBias: preferredMuscleGroups,
            avoided: avoidedMuscleGroups
        )
        guard !preferred.isEmpty else { return nil }
        let candidate = suggestedSplit(forDaysPerWeek: daysPerWeek)
        guard candidate != currentSplit else { return nil }
        let scoreCurrent = coverageScore(
            split: currentSplit, daysPerWeek: daysPerWeek, preferred: preferred
        )
        let scoreCandidate = coverageScore(
            split: candidate, daysPerWeek: daysPerWeek, preferred: preferred
        )
        guard scoreCandidate > scoreCurrent else { return nil }
        return PhysiqueSplitSuggestion(
            assessmentId: assessmentId,
            from: currentSplit,
            to: candidate,
            scoreCurrent: scoreCurrent,
            scoreCandidate: scoreCandidate,
            highlightMuscles: highlightMuscles(
                preferred: preferred,
                currentSplit: currentSplit,
                candidate: candidate,
                daysPerWeek: daysPerWeek
            )
        )
    }

    // MARK: Private

    private static func muscleSets(
        split: TrainingSplit,
        daysPerWeek: Int
    ) -> [Set<MuscleGroup>] {
        let n = max(1, daysPerWeek)
        let sequence = TrainingSchedule.splitSequence(for: split)
        if sequence.isEmpty {
            let adaptive = Set(TrainingSchedule.muscles(for: .upper))
                .union(TrainingSchedule.muscles(for: .lower))
            return Array(repeating: adaptive, count: n)
        }
        return (0..<n).map { Set(TrainingSchedule.muscles(for: sequence[$0 % sequence.count])) }
    }

    private static func highlightMuscles(
        preferred: [MuscleGroup],
        currentSplit: TrainingSplit,
        candidate: TrainingSplit,
        daysPerWeek: Int
    ) -> [MuscleGroup] {
        let deltas: [(MuscleGroup, Int)] = preferred.map { m in
            let delta = coverageScore(split: candidate, daysPerWeek: daysPerWeek, preferred: [m])
                - coverageScore(split: currentSplit, daysPerWeek: daysPerWeek, preferred: [m])
            return (m, delta)
        }
        let positive = deltas.filter { $0.1 > 0 }.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            let li = preferred.firstIndex(of: lhs.0) ?? 0
            let ri = preferred.firstIndex(of: rhs.0) ?? 0
            return li < ri
        }
        let picked = Array(positive.prefix(2).map(\.0))
        return picked.isEmpty ? Array(preferred.prefix(2)) : picked
    }
}
```

`OnboardingProfileEditing.suggestedSplit`:

```swift
static func suggestedSplit(for daysPerWeek: Int) -> TrainingSplit {
    PhysiqueSplitSuggestionEvaluator.suggestedSplit(forDaysPerWeek: daysPerWeek)
}
```

- [ ] **Step 4: Run domain + onboarding tests**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueSplitSuggestionTests \
  -only-testing:HotBodTests/OnboardingProfileEditingTests
```

Expected: PASS. If new file missing from target, `xcodegen generate` then re-run (restore pbxproj noise).

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Physique/PhysiqueSplitSuggestion.swift \
  HotBod/Tests/UnitTests/PhysiqueSplitSuggestionTests.swift \
  HotBod/Features/Onboarding/OnboardingProfileEditing.swift
git commit -m "$(cat <<'EOF'
feat: physique split suggestion concentration evaluator

EOF
)"
```

---

### Task 2: Preferences + AppEnvironment apply/dismiss

**Files:**
- Create: `HotBod/Services/Physique/PhysiqueSplitSuggestionPreferences.swift`
- Modify: `HotBod/App/AppEnvironment+Physique.swift`
- Modify: `HotBod/App/AppEnvironment+Account.swift` (`resetRuntimeStateAfterDataDeletion` / wipe path)
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift`
- Modify: `HotBod/Tests/UnitTests/PhysiqueSplitSuggestionTests.swift` (optional prefs unit) or keep prefs coverage via orchestration

**Interfaces:**
- Consumes: `PhysiqueSplitSuggestionEvaluator.evaluate`, `PhysiqueSplitSuggestion`
- Produces:
  ```swift
  enum PhysiqueSplitSuggestionPreferences {
      static var dismissedAssessmentId: UUID? { get set }
      static func markHandled(assessmentId: UUID)
      static func clear()
  }

  // AppEnvironment
  func physiqueSplitSuggestion(
      for assessment: PhysiqueAssessment,
      profile: UserProfile
  ) -> PhysiqueSplitSuggestion?

  func dismissPhysiqueSplitSuggestion(assessmentId: UUID)

  @discardableResult
  func applyPhysiqueSplitSuggestion(_ suggestion: PhysiqueSplitSuggestion) async -> Bool
  ```

- [ ] **Step 1: Write failing orchestration tests**

```swift
@MainActor
func testPhysiqueSplitSuggestionAppearsForMismatchedFullBody() async throws {
    PhysiqueSplitSuggestionPreferences.clear()
    let repos = TestRepositories.empty()
    var profile = UserProfile.empty()
    profile.preferredSplit = .fullBody
    profile.reminderTrainingDays = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    try await repos.userProfile.saveProfile(profile)

    var assessment = FixtureBuilders.makePhysiqueAssessment()
    assessment.trainingBias = PhysiqueTrainingBias(
        preferredMuscleGroups: [.shoulders, .back],
        rationale: "test"
    )
    try await repos.physiqueAssessment.save(assessment) // match existing repo API

    let env = AppEnvironment.makeForTests(repos: repos)
    env.userProfile = profile
    env.activePhysiqueAssessment = assessment

    let suggestion = env.physiqueSplitSuggestion(for: assessment, profile: profile)
    XCTAssertEqual(suggestion?.to, .pushPullLegs)
}

@MainActor
func testDismissPhysiqueSplitSuggestionHidesCard() async throws {
    PhysiqueSplitSuggestionPreferences.clear()
    // same setup as above…
    let suggestion = env.physiqueSplitSuggestion(for: assessment, profile: profile)
    XCTAssertNotNil(suggestion)
    env.dismissPhysiqueSplitSuggestion(assessmentId: assessment.id)
    XCTAssertNil(env.physiqueSplitSuggestion(for: assessment, profile: profile))
}

@MainActor
func testApplyPhysiqueSplitSuggestionUpdatesSplitResetsIndexAndHandles() async throws {
    PhysiqueSplitSuggestionPreferences.clear()
    // setup fullBody + 6 days + assessment; seed programState.splitDayIndex = 2
    env.programState.splitDayIndex = 2
    try await repos.programState.saveState(env.programState)

    guard let suggestion = env.physiqueSplitSuggestion(for: assessment, profile: profile) else {
        return XCTFail("expected suggestion")
    }
    let ok = await env.applyPhysiqueSplitSuggestion(suggestion)
    XCTAssertTrue(ok)
    XCTAssertEqual(env.userProfile?.preferredSplit, .pushPullLegs)
    XCTAssertEqual(env.programState.splitDayIndex, 0)
    XCTAssertNil(env.physiqueSplitSuggestion(for: assessment, profile: env.userProfile!))
}

@MainActor
func testRegression_wipeClearsPhysiqueSplitSuggestionDismissal() async throws {
    PhysiqueSplitSuggestionPreferences.markHandled(assessmentId: UUID())
    XCTAssertNotNil(PhysiqueSplitSuggestionPreferences.dismissedAssessmentId)
    // wipe via env.wipeAllLocalUserData
    try await env.wipeAllLocalUserData(clearAuthSession: false)
    XCTAssertNil(PhysiqueSplitSuggestionPreferences.dismissedAssessmentId)
}
```

Match existing `FixtureBuilders` / repo method names in this file (`save` vs `saveAssessment`). Clear prefs in `setUp`/`tearDown` for isolation.

- [ ] **Step 2: Run — expect FAIL**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests/testPhysiqueSplitSuggestionAppearsForMismatchedFullBody
```

- [ ] **Step 3: Implement preferences + environment**

`PhysiqueSplitSuggestionPreferences.swift`:

```swift
import Foundation

enum PhysiqueSplitSuggestionPreferences {
    private static let key = "hotbod.physique.splitSuggestion.dismissedAssessmentId"

    static var dismissedAssessmentId: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    static func markHandled(assessmentId: UUID) {
        dismissedAssessmentId = assessmentId
    }

    static func clear() {
        dismissedAssessmentId = nil
    }
}
```

`AppEnvironment+Physique.swift` (add):

```swift
func physiqueSplitSuggestion(
    for assessment: PhysiqueAssessment,
    profile: UserProfile
) -> PhysiqueSplitSuggestion? {
    PhysiqueSplitSuggestionEvaluator.evaluate(
        assessmentId: assessment.id,
        currentSplit: profile.preferredSplit,
        daysPerWeek: profile.trainingDaysPerWeek,
        preferredMuscleGroups: assessment.trainingBias.preferredMuscleGroups,
        avoidedMuscleGroups: profile.avoidedMuscleGroups,
        dismissedAssessmentId: PhysiqueSplitSuggestionPreferences.dismissedAssessmentId
    )
}

func dismissPhysiqueSplitSuggestion(assessmentId: UUID) {
    PhysiqueSplitSuggestionPreferences.markHandled(assessmentId: assessmentId)
}

@discardableResult
func applyPhysiqueSplitSuggestion(_ suggestion: PhysiqueSplitSuggestion) async -> Bool {
    guard var profile = userProfile, profile.preferredSplit == suggestion.from else {
        return false
    }
    let previousSplit = profile.preferredSplit
    let previousIndex = programState.splitDayIndex

    profile.preferredSplit = suggestion.to
    guard await updateUserProfile(profile, refreshWorkout: false) else {
        return false
    }

    var state = programState
    state.splitDayIndex = 0
    programState = state
    try? await programStateRepository.saveState(state)

    let regenerated = await regenerateTodayWorkout(profile: profile)
    if !regenerated {
        var rolledBack = profile
        rolledBack.preferredSplit = previousSplit
        _ = await updateUserProfile(rolledBack, refreshWorkout: false)
        var rolledState = programState
        rolledState.splitDayIndex = previousIndex
        programState = rolledState
        try? await programStateRepository.saveState(rolledState)
        return false
    }

    PhysiqueSplitSuggestionPreferences.markHandled(assessmentId: suggestion.assessmentId)
    return true
}
```

Wipe path — in `resetRuntimeStateAfterDataDeletion` or immediately after `PersistenceHelper.clearAllPersistedData()`:

```swift
PhysiqueSplitSuggestionPreferences.clear()
```

(`PersistenceHelper` does **not** clear UserDefaults.)

- [ ] **Step 4: Run orchestration tests**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests
```

Expected: new tests PASS; existing green.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Services/Physique/PhysiqueSplitSuggestionPreferences.swift \
  HotBod/App/AppEnvironment+Physique.swift \
  HotBod/App/AppEnvironment+Account.swift \
  HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift
git commit -m "$(cat <<'EOF'
feat: apply and dismiss physique split suggestions

EOF
)"
```

---

### Task 3: Report UI + UITest seed

**Files:**
- Modify: `HotBod/Features/Physique/PhysiqueAssessmentReportContent.swift`
- Modify: `HotBod/Features/Physique/PhysiqueView.swift`
- Modify: `HotBod/App/UITestConfiguration.swift`
- Modify: `HotBod/Tests/UITests/BaseUITestCase.swift`
- Create: `HotBod/Tests/UITests/PhysiqueSplitSuggestionUITests.swift`
- Modify: `HotBod/Resources/Localizable.xcstrings` only if Xcode/string catalog requires entries for new literals (prefer `String(localized:)` / existing patterns)

**Interfaces:**
- Consumes: `physiqueSplitSuggestion(for:profile:)`, `dismissPhysiqueSplitSuggestion`, `applyPhysiqueSplitSuggestion`
- Produces: UI ids `physique.splitSuggestion`, `physique.splitSuggestion.apply`, `physique.splitSuggestion.dismiss`

- [ ] **Step 1: Extend report content**

Add optional props (defaults keep history/previews working):

```swift
var splitSuggestion: PhysiqueSplitSuggestion? = nil
var onApplySplitSuggestion: ((PhysiqueSplitSuggestion) -> Void)? = nil
var onDismissSplitSuggestion: ((UUID) -> Void)? = nil
@State private var confirmApply = false
```

In `body`, **after** `whyTodayCard`:

```swift
if let splitSuggestion {
    splitSuggestionCard(splitSuggestion)
}
```

Card:

```swift
private func splitSuggestionCard(_ suggestion: PhysiqueSplitSuggestion) -> some View {
    ForgeCard {
        VStack(alignment: .leading, spacing: ForgeSpacing.s3) {
            ForgeSectionHeader(title: "Better split for your focus", subtitle: nil)
            Text("\(suggestion.from.displayName) → \(suggestion.to.displayName)")
                .font(ForgeTypography.body.weight(.semibold))
            Text(highlightCopy(suggestion.highlightMuscles))
                .font(ForgeTypography.caption)
                .foregroundStyle(ForgeColors.muted)
            HStack(spacing: ForgeSpacing.s3) {
                ForgeButton(
                    title: "Not now",
                    style: .secondary,
                    accessibilityIdentifier: "physique.splitSuggestion.dismiss"
                ) {
                    onDismissSplitSuggestion?(suggestion.assessmentId)
                }
                ForgeButton(
                    title: "Apply",
                    style: .accent,
                    accessibilityIdentifier: "physique.splitSuggestion.apply"
                ) {
                    confirmApply = true
                }
            }
        }
    }
    .accessibilityIdentifier("physique.splitSuggestion")
    .confirmationDialog(
        "Switch to \(suggestion.to.displayName)?",
        isPresented: $confirmApply,
        titleVisibility: .visible
    ) {
        Button("Switch and regenerate") {
            onApplySplitSuggestion?(suggestion)
        }
        Button("Cancel", role: .cancel) {}
    } message: {
        Text("Today’s workout will regenerate from day one of the new split.")
    }
}

private func highlightCopy(_ muscles: [MuscleGroup]) -> String {
    let names = muscles.map(\.displayName)
    switch names.count {
    case 0: return "Better fit for your current focus."
    case 1: return "More focused weekly work for \(names[0])."
    default: return "More focused weekly work for \(names[0]) and \(names[1])."
    }
}
```

- [ ] **Step 2: Wire `PhysiqueView` active report only**

In `reportSection`:

```swift
let suggestion: PhysiqueSplitSuggestion? = {
    guard let profile = environment.userProfile else { return nil }
    return environment.physiqueSplitSuggestion(for: assessment, profile: profile)
}()

PhysiqueAssessmentReportContent(
    assessment: assessment,
    sinceLastDiff: environment.sinceLastPhysiqueDiff(photos: photos),
    splitSuggestion: suggestion,
    onApplySplitSuggestion: { suggestion in
        Task {
            let ok = await environment.applyPhysiqueSplitSuggestion(suggestion)
            if !ok {
                // existing syncMessage / generation failure surface is enough
            }
        }
    },
    onDismissSplitSuggestion: { id in
        environment.dismissPhysiqueSplitSuggestion(assessmentId: id)
    }
)
```

Ensure history detail keeps default `splitSuggestion: nil`. After dismiss/apply, view must refresh — if `PhysiqueSplitSuggestionPreferences` is not `@Published`, force a local `@State` revision bump in the dismiss/apply callbacks (`splitSuggestionRevision &+= 1`) and include it when computing suggestion so SwiftUI re-renders.

- [ ] **Step 3: UITest seed + test**

`UITestConfiguration`:

```swift
static var shouldSeedPhysiqueSplitSuggestion: Bool {
    isUITesting && ProcessInfo.processInfo.arguments.contains("-SeedPhysiqueSplitSuggestion")
}
```

In `applyDeepLinks`, call `seedPhysiqueSplitSuggestionIfNeeded`.

Seed helper:
1. `PhysiqueSplitSuggestionPreferences.clear()`
2. Force profile: `preferredSplit = .fullBody`, six `reminderTrainingDays`, save via env
3. Seed one active assessment with `preferredMuscleGroups: [.shoulders, .back]` (can reuse cadence/history stub photos + `FixtureBuilders`-like inline assessment)
4. `environment.activePhysiqueAssessment = …` + repo save
5. `loadActivePhysiqueAssessment()`

`BaseUITestCase`: `var seedPhysiqueSplitSuggestion = false` → append `-SeedPhysiqueSplitSuggestion`.

`PhysiqueSplitSuggestionUITests.swift`:

```swift
final class PhysiqueSplitSuggestionUITests: BaseUITestCase {
    override func setUpWithError() throws {
        seedPhysiqueSplitSuggestion = true
        launchTab = "physique"
        try super.setUpWithError()
    }

    func testSplitSuggestionCardAppearsWhenSeeded() {
        XCTAssertTrue(app.otherElements["physique.root"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.descendants(matching: .any)["physique.splitSuggestion"].waitForExistence(timeout: 10)
        )
    }
}
```

- [ ] **Step 4: Build + focused tests**

```bash
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueSplitSuggestionTests \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests \
  -only-testing:HotBodUITests/PhysiqueSplitSuggestionUITests
```

Expected: PASS. Fix Localizable / accessibility as needed.

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/Physique/PhysiqueAssessmentReportContent.swift \
  HotBod/Features/Physique/PhysiqueView.swift \
  HotBod/App/UITestConfiguration.swift \
  HotBod/Tests/UITests/BaseUITestCase.swift \
  HotBod/Tests/UITests/PhysiqueSplitSuggestionUITests.swift \
  HotBod/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
feat: physique report split suggestion card

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Concentration coverage score | 1 |
| Gates: dismiss, empty preferred, candidate≠current, score> | 1 |
| Extract suggestedSplit; onboarding wrapper | 1 |
| UserDefaults dismiss/handled prefs | 2 |
| evaluate / dismiss / apply + rollback | 2 |
| Wipe clears prefs | 2 |
| Report card below why-today; confirm dialog | 3 |
| History does not show apply | 3 (nil default) |
| UITest seed + smoke | 3 |
| No Today/Settings chrome | — (omitted) |

## Plan self-review notes

- Spec amended: concentration millipoints (Full Body must not always win).
- Adaptive path must use upper∪lower set via `muscleSets`, not raw `.upper` focuses.
- Apply rollback required when regenerate fails.
- UI refresh after dismiss needs local revision state (UserDefaults is not observable).

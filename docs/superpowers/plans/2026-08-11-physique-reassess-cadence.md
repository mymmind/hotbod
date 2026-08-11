# Physique Reassess Cadence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Schedule a one-shot local “time to reassess” notification 6 weeks after the active Physique assessment, show an in-app due banner on the report, and open the Physique tab when the notification is tapped.

**Architecture:** Pure `PhysiqueReassessCadence` computes due/fire. Parallel `PhysiqueReassessReminderScheduling` mirrors workout reminders (id prefix `hotbod.physique.reassess`), piggybacks `workoutRemindersEnabled`, and never catch-up-pushes when already overdue. `AppEnvironment.rescheduleAllLocalReminders()` keeps call sites in sync. Physique report shows `physique.cadenceDue` banner; `UNUserNotificationCenterDelegate` routes taps via a pure identifier helper.

**Tech Stack:** Swift 6, SwiftUI, UserNotifications, XCTest, XcodeGen (`xcodegen generate` after new HotBod/ files), `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-08-11-physique-reassess-cadence-design.md`

## Global Constraints

- iOS 17+.
- Local-first; reuse `UNUserNotificationCenter` patterns from workout reminders.
- Cadence is calendar weeks from **active** assessment `createdAt` only.
- Stale-photo banner stays independent.
- Prefer: “reassess,” “refresh your focus,” “time to reassess.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims, nagging catch-up pushes when already overdue.
- Piggyback `workoutRemindersEnabled` — no new Settings toggle.
- UITests / `-UITesting` use no-op schedulers.
- After new Swift files under `HotBod/`, run `xcodegen generate`.
- Simulator: use `id=EB7BE0BD-179B-4A37-9202-69D87FC47B75` if needed.
- Regression tests use `testRegression_` prefix where applicable.
- Do not alter unrelated uncommitted local changes (e.g. unrelated `Localizable.xcstrings` / pbxproj noise). Prefer adding new file refs only; if `xcodegen` churns `objectVersion` / `DEVELOPMENT_TEAM`, restore baselines and add refs manually.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Physique/PhysiqueReassessCadence.swift` | Pure dueDate / isDue / nextFireDateComponents |
| `HotBod/Domain/Physique/PhysiqueNotificationRouting.swift` | Pure identifier → open Physique? |
| `HotBod/Services/Notifications/PhysiqueReassessReminderScheduling.swift` | Protocol, planner copy, NoOp |
| `HotBod/Services/Notifications/LocalPhysiqueReassessReminderScheduler.swift` | UNUserNotificationCenter one-shot |
| `HotBod/App/AppEnvironment.swift` | Inject scheduler; `rescheduleAllLocalReminders` |
| `HotBod/App/AppEnvironment+Physique.swift` | Reschedule after save/assess |
| `HotBod/App/AppEnvironment+Account.swift` | Cancel on wipe |
| `HotBod/App/HotBodAppDelegate.swift` | UNUserNotificationCenterDelegate |
| `HotBod/App/HotBodApp.swift` | Wire delegate + router |
| `HotBod/Features/Physique/PhysiqueView.swift` | Cadence due banner |
| `HotBod/App/UITestConfiguration.swift` | `-SeedPhysiqueCadenceDue` |
| `HotBod/Tests/UITests/BaseUITestCase.swift` | Launch flag plumbing |
| `HotBod/Tests/Support/FixtureBuilders.swift` | Fake scheduler for tests |
| `HotBod/Tests/UnitTests/PhysiqueReassessCadenceTests.swift` | Domain + routing + planner |
| `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift` | Integration reschedule/cancel |
| `HotBod/Tests/UITests/PhysiqueCadenceUITests.swift` | Banner smoke |

---

### Task 1: Cadence domain + routing helper

**Files:**
- Create: `HotBod/Domain/Physique/PhysiqueReassessCadence.swift`
- Create: `HotBod/Domain/Physique/PhysiqueNotificationRouting.swift`
- Create: `HotBod/Tests/UnitTests/PhysiqueReassessCadenceTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum PhysiqueReassessCadence {
      static let intervalWeeks = 6
      static let notificationIdentifier = "hotbod.physique.reassess"

      static func dueDate(
          from createdAt: Date,
          calendar: Calendar = .current
      ) -> Date

      static func isDue(
          assessmentCreatedAt: Date,
          now: Date = Date(),
          calendar: Calendar = .current
      ) -> Bool

      /// Returns calendar components for a one-shot trigger, or nil when
      /// already past due (`now >= dueDate`) or components cannot be built.
      static func nextFireDateComponents(
          from createdAt: Date,
          timeOfDay: TimeOfDayPreference,
          now: Date = Date(),
          calendar: Calendar = .current
      ) -> DateComponents?
  }

  enum PhysiqueNotificationRouting {
      static func shouldOpenPhysique(identifier: String) -> Bool
  }
  ```

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import HotBod

final class PhysiqueReassessCadenceTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    func testDueDateIsSixWeeksAfterCreatedAt() {
        let created = Date(timeIntervalSince1970: 1_700_000_000) // fixed
        let due = PhysiqueReassessCadence.dueDate(from: created, calendar: calendar)
        let weeks = calendar.dateComponents([.weekOfYear], from: created, to: due).weekOfYear
        XCTAssertEqual(weeks, 6)
        XCTAssertEqual(PhysiqueReassessCadence.intervalWeeks, 6)
    }

    func testIsDueFalseBeforeInterval() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let now = calendar.date(byAdding: .day, value: 20, to: created)!
        XCTAssertFalse(PhysiqueReassessCadence.isDue(
            assessmentCreatedAt: created, now: now, calendar: calendar
        ))
    }

    func testIsDueTrueAtOrAfterInterval() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let due = PhysiqueReassessCadence.dueDate(from: created, calendar: calendar)
        XCTAssertTrue(PhysiqueReassessCadence.isDue(
            assessmentCreatedAt: created, now: due, calendar: calendar
        ))
        XCTAssertTrue(PhysiqueReassessCadence.isDue(
            assessmentCreatedAt: created,
            now: due.addingTimeInterval(3600),
            calendar: calendar
        ))
    }

    func testNextFireNilWhenAlreadyPastDue() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let due = PhysiqueReassessCadence.dueDate(from: created, calendar: calendar)
        let comps = PhysiqueReassessCadence.nextFireDateComponents(
            from: created,
            timeOfDay: .morning,
            now: due.addingTimeInterval(1),
            calendar: calendar
        )
        XCTAssertNil(comps)
    }

    func testNextFireUsesReminderHourOnDueCalendarDay() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let due = PhysiqueReassessCadence.dueDate(from: created, calendar: calendar)
        let now = calendar.date(byAdding: .day, value: -1, to: due)!
        let comps = PhysiqueReassessCadence.nextFireDateComponents(
            from: created,
            timeOfDay: .evening,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(comps?.hour, TimeOfDayPreference.evening.reminderHour)
        XCTAssertEqual(comps?.minute, 0)
        XCTAssertEqual(comps?.day, calendar.component(.day, from: due))
        XCTAssertEqual(comps?.month, calendar.component(.month, from: due))
        XCTAssertEqual(comps?.year, calendar.component(.year, from: due))
    }

    func testNextFireFallsBackToDueInstantWhenMorningAlreadyPassedButNotYetDue() {
        // due evening; now is afternoon same calendar day as due → morning fire missed
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let due = PhysiqueReassessCadence.dueDate(from: created, calendar: calendar)
        var morningComps = calendar.dateComponents([.year, .month, .day], from: due)
        morningComps.hour = TimeOfDayPreference.morning.reminderHour
        morningComps.minute = 0
        let morningFire = calendar.date(from: morningComps)!
        // Pick a now after morning fire but before due (if due is later that day)
        // If due itself is before/at morning (unlikely with +6 weeks preserving time-of-day),
        // construct now = due - 1 hour when that is after morning fire.
        let now = max(morningFire.addingTimeInterval(3600), due.addingTimeInterval(-3600))
        guard now < due else {
            // Skip pathological timezone/edge; still assert nil-vs-components contract below
            return
        }
        let comps = PhysiqueReassessCadence.nextFireDateComponents(
            from: created,
            timeOfDay: .morning,
            now: now,
            calendar: calendar
        )
        XCTAssertNotNil(comps)
        let fire = calendar.date(from: comps!)
        XCTAssertEqual(fire?.timeIntervalSince1970, due.timeIntervalSince1970, accuracy: 1)
    }

    func testNotificationRoutingMatchesPrefix() {
        XCTAssertTrue(PhysiqueNotificationRouting.shouldOpenPhysique(
            identifier: PhysiqueReassessCadence.notificationIdentifier
        ))
        XCTAssertTrue(PhysiqueNotificationRouting.shouldOpenPhysique(
            identifier: "hotbod.physique.reassess.extra"
        ))
        XCTAssertFalse(PhysiqueNotificationRouting.shouldOpenPhysique(
            identifier: "hotbod.workout.2.7.0"
        ))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueReassessCadenceTests test
```

Expected: FAIL (types missing)

- [ ] **Step 3: Implement domain helpers**

`PhysiqueReassessCadence.swift`:

```swift
import Foundation

enum PhysiqueReassessCadence {
    static let intervalWeeks = 6
    static let notificationIdentifier = "hotbod.physique.reassess"

    static func dueDate(from createdAt: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .weekOfYear, value: intervalWeeks, to: createdAt) ?? createdAt
    }

    static func isDue(
        assessmentCreatedAt: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        now >= dueDate(from: assessmentCreatedAt, calendar: calendar)
    }

    static func nextFireDateComponents(
        from createdAt: Date,
        timeOfDay: TimeOfDayPreference,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DateComponents? {
        let due = dueDate(from: createdAt, calendar: calendar)
        guard due > now else { return nil }

        var preferred = calendar.dateComponents([.year, .month, .day], from: due)
        preferred.hour = timeOfDay.reminderHour
        preferred.minute = 0
        preferred.second = 0

        if let preferredFire = calendar.date(from: preferred), preferredFire > now {
            return preferred
        }

        // Preferred clock already passed, but not yet past due → fire at due instant.
        return calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: due
        )
    }
}
```

`PhysiqueNotificationRouting.swift`:

```swift
import Foundation

enum PhysiqueNotificationRouting {
    static func shouldOpenPhysique(identifier: String) -> Bool {
        identifier.hasPrefix(PhysiqueReassessCadence.notificationIdentifier)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueReassessCadenceTests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Physique/PhysiqueReassessCadence.swift \
  HotBod/Domain/Physique/PhysiqueNotificationRouting.swift \
  HotBod/Tests/UnitTests/PhysiqueReassessCadenceTests.swift \
  HotBod.xcodeproj
git commit -m "feat: add physique reassess cadence domain helpers"
```

---

### Task 2: Reminder scheduler + AppEnvironment wiring

**Files:**
- Create: `HotBod/Services/Notifications/PhysiqueReassessReminderScheduling.swift`
- Create: `HotBod/Services/Notifications/LocalPhysiqueReassessReminderScheduler.swift`
- Modify: `HotBod/App/AppEnvironment.swift` (property, init default, `rescheduleAllLocalReminders`)
- Modify: `HotBod/App/AppEnvironment+Physique.swift` (reschedule after save/assess)
- Modify: `HotBod/App/AppEnvironment+Account.swift` (cancel on wipe)
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift` (inject NoOp / expose fake)
- Modify: `HotBod/Tests/UnitTests/PhysiqueReassessCadenceTests.swift` (planner title/body/id)
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift` (integration)

**Interfaces:**
- Consumes: `PhysiqueReassessCadence.nextFireDateComponents`, `notificationIdentifier`
- Produces:
  ```swift
  enum PhysiqueReassessReminderPlanner {
      static let identifier = PhysiqueReassessCadence.notificationIdentifier
      static func title() -> String  // "Time to reassess"
      static func body() -> String   // "Capture updated photos and refresh your Physique focus."
  }

  protocol PhysiqueReassessReminderScheduling: AnyObject, Sendable {
      func requestAuthorizationIfNeeded() async -> Bool
      func reschedule(profile: UserProfile, assessmentCreatedAt: Date?) async
      func cancelAll() async
  }

  final class NoOpPhysiqueReassessReminderScheduler: PhysiqueReassessReminderScheduling, @unchecked Sendable
  final class LocalPhysiqueReassessReminderScheduler: PhysiqueReassessReminderScheduling, @unchecked Sendable

  // Recording fake for tests:
  final class RecordingPhysiqueReassessReminderScheduler: PhysiqueReassessReminderScheduling, @unchecked Sendable {
      var rescheduleCalls: [(enabled: Bool, createdAt: Date?)] = []
      var cancelCount = 0
      // implement: cancelAll increments; reschedule records profile.workoutRemindersEnabled + createdAt
  }

  // AppEnvironment:
  let physiqueReassessReminderScheduler: any PhysiqueReassessReminderScheduling
  func reschedulePhysiqueReassessReminder() async
  func rescheduleAllLocalReminders() async  // workout + physique
  ```

- [ ] **Step 1: Write failing planner + orchestration tests**

Add to `PhysiqueReassessCadenceTests`:

```swift
func testPlannerCopyAndIdentifier() {
    XCTAssertEqual(PhysiqueReassessReminderPlanner.identifier, "hotbod.physique.reassess")
    XCTAssertEqual(PhysiqueReassessReminderPlanner.title(), "Time to reassess")
    XCTAssertEqual(
        PhysiqueReassessReminderPlanner.body(),
        "Capture updated photos and refresh your Physique focus."
    )
}
```

Add recording fake (can live in `FixtureBuilders.swift` or test file) and tests in `AppEnvironmentPhysiqueOrchestrationTests`:

```swift
@MainActor
func testRegression_assessPhysiqueReschedulesReassessReminder() async throws {
    let recorder = RecordingPhysiqueReassessReminderScheduler()
    let repos = InMemoryRepositories()
    // build env with mock assess service that returns FixtureBuilders.makePhysiqueAssessment()
    // + physiqueReassessReminderScheduler: recorder
    // + userProfile with workoutRemindersEnabled: true
    // seed front+back photos as existing assess tests do
    _ = await env.assessPhysique(photos: [front, back])
    XCTAssertFalse(recorder.rescheduleCalls.isEmpty)
    XCTAssertNotNil(recorder.rescheduleCalls.last?.createdAt)
}

@MainActor
func testRegression_clearAccountCancelsPhysiqueReassessReminder() async throws {
    let recorder = RecordingPhysiqueReassessReminderScheduler()
    // env with recorder, active assessment set
    try await env.wipeAllLocalUserData(clearAuthSession: false)
    XCTAssertGreaterThan(recorder.cancelCount, 0)
}

@MainActor
func testRegression_remindersDisabledCancelsPhysiqueReassessOnReschedule() async throws {
    let recorder = RecordingPhysiqueReassessReminderScheduler()
    // env with assessment + profile.workoutRemindersEnabled = false
    await env.rescheduleAllLocalReminders()
    // Local scheduler would cancel; Recording fake should still be invoked with enabled false
    XCTAssertEqual(recorder.rescheduleCalls.last?.enabled, false)
}
```

Implement `RecordingPhysiqueReassessReminderScheduler` so `reschedule` appends `(profile.workoutRemindersEnabled, assessmentCreatedAt)` and always calls through conceptually like Local (tests only assert call recording — they do not hit UNUserNotificationCenter).

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueReassessCadenceTests/testPlannerCopyAndIdentifier \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests test
```

Expected: FAIL (protocol / methods missing)

- [ ] **Step 3: Implement scheduler + wire environment**

`PhysiqueReassessReminderScheduling.swift`:

```swift
import Foundation

enum PhysiqueReassessReminderPlanner {
    static let identifier = PhysiqueReassessCadence.notificationIdentifier

    static func title() -> String { "Time to reassess" }

    static func body() -> String {
        "Capture updated photos and refresh your Physique focus."
    }
}

protocol PhysiqueReassessReminderScheduling: AnyObject, Sendable {
    func requestAuthorizationIfNeeded() async -> Bool
    func reschedule(profile: UserProfile, assessmentCreatedAt: Date?) async
    func cancelAll() async
}

final class NoOpPhysiqueReassessReminderScheduler: PhysiqueReassessReminderScheduling, @unchecked Sendable {
    func requestAuthorizationIfNeeded() async -> Bool { false }
    func reschedule(profile: UserProfile, assessmentCreatedAt: Date?) async {}
    func cancelAll() async {}
}
```

`LocalPhysiqueReassessReminderScheduler.swift` — mirror `LocalWorkoutReminderScheduler`:

```swift
import Foundation
import UserNotifications

final class LocalPhysiqueReassessReminderScheduler: PhysiqueReassessReminderScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    func reschedule(profile: UserProfile, assessmentCreatedAt: Date?) async {
        await cancelAll()
        guard profile.workoutRemindersEnabled, let createdAt = assessmentCreatedAt else { return }
        guard let comps = PhysiqueReassessCadence.nextFireDateComponents(
            from: createdAt,
            timeOfDay: profile.timeOfDayPreference
        ) else { return }
        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = PhysiqueReassessReminderPlanner.title()
        content.body = PhysiqueReassessReminderPlanner.body()
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: PhysiqueReassessReminderPlanner.identifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter {
            $0.hasPrefix(PhysiqueReassessCadence.notificationIdentifier)
        }
        // Also remove the exact id even if not in pending list (harmless)
        var toRemove = Set(ids)
        toRemove.insert(PhysiqueReassessReminderPlanner.identifier)
        center.removePendingNotificationRequests(withIdentifiers: Array(toRemove))
    }
}
```

`AppEnvironment` changes:

1. Add `let physiqueReassessReminderScheduler: any PhysiqueReassessReminderScheduling`
2. Init param `physiqueReassessReminderScheduler: (any PhysiqueReassessReminderScheduling)? = nil` defaulting to NoOp when UITesting else Local
3. Replace bootstrap `await rescheduleWorkoutReminders()` with `await rescheduleAllLocalReminders()`
4. Add:

```swift
func reschedulePhysiqueReassessReminder() async {
    guard let profile = userProfile else {
        await physiqueReassessReminderScheduler.cancelAll()
        return
    }
    await physiqueReassessReminderScheduler.reschedule(
        profile: profile,
        assessmentCreatedAt: activePhysiqueAssessment?.createdAt
    )
}

func rescheduleAllLocalReminders() async {
    await rescheduleWorkoutReminders()
    await reschedulePhysiqueReassessReminder()
}
```

5. Find every call site of `rescheduleWorkoutReminders()` that runs after profile save / reminder toggle — switch those to `rescheduleAllLocalReminders()` (keep the private workout method for the shared helper). Grep: `rescheduleWorkoutReminders`.

`AppEnvironment+Physique.swift` — after successful save path:

```swift
func saveActivePhysiqueAssessment(_ assessment: PhysiqueAssessment) async {
    try? await physiqueAssessmentRepository.saveActive(assessment)
    await loadActivePhysiqueAssessment()
    await reschedulePhysiqueReassessReminder()
}
```

(`assessPhysique` already calls `saveActivePhysiqueAssessment`, so it inherits reschedule.)

`AppEnvironment+Account.swift` — in wipe path next to other clears:

```swift
await physiqueReassessReminderScheduler.cancelAll()
```

Also cancel when assessment history is cleared if there is a dedicated clear method.

Update `FixtureBuilders.makeAppEnvironment` (or equivalent) to pass `NoOpPhysiqueReassessReminderScheduler()` by default; allow override for recording fake.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueReassessCadenceTests \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Services/Notifications/PhysiqueReassessReminderScheduling.swift \
  HotBod/Services/Notifications/LocalPhysiqueReassessReminderScheduler.swift \
  HotBod/App/AppEnvironment.swift \
  HotBod/App/AppEnvironment+Physique.swift \
  HotBod/App/AppEnvironment+Account.swift \
  HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod/Tests/UnitTests/PhysiqueReassessCadenceTests.swift \
  HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift \
  HotBod.xcodeproj
git commit -m "feat: schedule physique reassess local reminders"
```

---

### Task 3: Physique due banner + UITest seed

**Files:**
- Modify: `HotBod/Features/Physique/PhysiqueView.swift`
- Modify: `HotBod/App/UITestConfiguration.swift`
- Modify: `HotBod/Tests/UITests/BaseUITestCase.swift`
- Create: `HotBod/Tests/UITests/PhysiqueCadenceUITests.swift`

**Interfaces:**
- Consumes: `PhysiqueReassessCadence.isDue(assessmentCreatedAt:)`
- Produces: accessibility id `physique.cadenceDue`; launch arg `-SeedPhysiqueCadenceDue`

- [ ] **Step 1: Write failing UITest**

`BaseUITestCase` — add `var seedPhysiqueCadenceDue = false` and append `-SeedPhysiqueCadenceDue` when true (same pattern as history/illustration seeds).

`UITestConfiguration`:

```swift
static var shouldSeedPhysiqueCadenceDue: Bool {
    isUITesting && ProcessInfo.processInfo.arguments.contains("-SeedPhysiqueCadenceDue")
}

@MainActor
static func seedPhysiqueCadenceDueIfNeeded(in environment: AppEnvironment) async {
    guard shouldSeedPhysiqueCadenceDue else { return }
    let createdAt = Calendar.current.date(byAdding: .day, value: -49, to: Date()) ?? Date().addingTimeInterval(-49 * 24 * 3600)
    var assessment = FixtureBuilders.makePhysiqueAssessment(createdAt: createdAt)
    // Or construct inline like other seeds if FixtureBuilders is unavailable from app target —
    // prefer duplicating minimal PhysiqueAssessment init already used in seedPhysiqueHistoryIfNeeded
    // with createdAt ~49 days ago (7 weeks).
    await environment.saveActivePhysiqueAssessment(assessment)
}
```

Call `seedPhysiqueCadenceDueIfNeeded` from the same place `seedPhysiqueHistoryIfNeeded` / illustration seeds run (`applyDeepLinks` or bootstrap seed hook).

`PhysiqueCadenceUITests.swift`:

```swift
@MainActor
final class PhysiqueCadenceUITests: BaseUITestCase {
    func testCadenceDueBannerAppearsWhenAssessmentOverdue() {
        seedPhysiqueCadenceDue = true
        launchTab = "physique"
        // relaunch: BaseUITestCase launches in setUp — override setUp or set flags before super
    }
}
```

**Important:** flags must be set **before** `app.launch()` in `setUpWithError`. Pattern used elsewhere: set properties in the test class’s `setUpWithError` before `super.setUpWithError()`, or override and configure then call super. Follow `PhysiqueHistoryUITests` / `PhysiqueIllustrationUITests` exactly:

```swift
override func setUpWithError() throws {
    seedPhysiqueCadenceDue = true
    launchTab = "physique"
    try super.setUpWithError()
}

func testCadenceDueBannerAppearsWhenAssessmentOverdue() {
    XCTAssertTrue(app.otherElements["physique.root"].waitForExistence(timeout: 15))
    XCTAssertTrue(
        app.staticTexts["physique.cadenceDue"].waitForExistence(timeout: 10)
            || app.descendants(matching: .any)["physique.cadenceDue"].waitForExistence(timeout: 5)
    )
}

func testFreshAssessmentHasNoCadenceDueBanner() {
    // Default seed / SkipOnboarding without cadence seed; open physique
    // May need a minimal fresh assessment seed — if empty state has no banner, assert absence:
    launchTab = "physique"
    // Use a separate test class method with seedPhysiqueCadenceDue = false (default)
    // and optionally seed fresh via -SeedPhysiqueHistory (newer is "now") or leave empty.
    XCTAssertFalse(app.descendants(matching: .any)["physique.cadenceDue"].waitForExistence(timeout: 3))
}
```

Split into two test classes or two setUp configurations if BaseUITestCase only launches once — match existing Physique UITest style (one flag per test class if needed).

- [ ] **Step 2: Run UITest to verify it fails**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodUITests/PhysiqueCadenceUITests test
```

Expected: FAIL (banner / identifier missing)

- [ ] **Step 3: Implement banner in PhysiqueView**

Compute due from active assessment:

```swift
private var isCadenceDue: Bool {
    guard let assessment else { return false }
    return PhysiqueReassessCadence.isDue(assessmentCreatedAt: assessment.createdAt)
}
```

In the banner stack (after stale, before status):

```swift
if hasStalePhotos {
    staleBanner
}
if isCadenceDue {
    cadenceDueBanner
}
```

```swift
private var cadenceDueBanner: some View {
    ForgeCard {
        Text("6 weeks since last assessment — reassess to refresh your focus.")
            .font(ForgeTypography.body)
            .foregroundStyle(ForgeColors.muted)
    }
    .accessibilityIdentifier("physique.cadenceDue")
}
```

Do **not** show cadence banner on history snapshot views (`PhysiqueAssessmentHistoryView` / read-only detail) — only `PhysiqueView` active report.

Ensure seed uses `createdAt` ≥ 7 weeks ago and that `saveActivePhysiqueAssessment` runs after onboarding skip so `activePhysiqueAssessment` is loaded before UI appears.

- [ ] **Step 4: Run UITest to verify it passes**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodUITests/PhysiqueCadenceUITests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/Physique/PhysiqueView.swift \
  HotBod/App/UITestConfiguration.swift \
  HotBod/Tests/UITests/BaseUITestCase.swift \
  HotBod/Tests/UITests/PhysiqueCadenceUITests.swift \
  HotBod.xcodeproj
git commit -m "feat: show physique reassess cadence due banner"
```

---

### Task 4: Notification tap → Physique tab

**Files:**
- Create: `HotBod/App/HotBodAppDelegate.swift`
- Modify: `HotBod/App/HotBodApp.swift`
- Modify: `HotBod/Tests/UnitTests/PhysiqueReassessCadenceTests.swift` (routing already covered in Task 1 — add delegate thin wrapper test only if logic lives outside pure helper)

**Interfaces:**
- Consumes: `PhysiqueNotificationRouting.shouldOpenPhysique(identifier:)`
- Produces: on tap, `router.route = .main` (if needed) + `router.selectedTab = .physique`

- [ ] **Step 1: Write failing unit test for routing (if not already green from Task 1)**

If Task 1 routing tests pass, add a documentation-level test that the identifier constant used by the scheduler matches routing:

```swift
func testSchedulerIdentifierIsRoutable() {
    XCTAssertTrue(PhysiqueNotificationRouting.shouldOpenPhysique(
        identifier: PhysiqueReassessReminderPlanner.identifier
    ))
}
```

- [ ] **Step 2: Implement app delegate**

`HotBodAppDelegate.swift`:

```swift
import UIKit
import UserNotifications

final class HotBodAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var router: AppRouter?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let id = response.notification.request.identifier
        guard PhysiqueNotificationRouting.shouldOpenPhysique(identifier: id) else { return }
        await MainActor.run {
            guard let router else { return }
            router.showMain()
            router.selectedTab = .physique
        }
    }
}
```

`HotBodApp.swift`:

```swift
@UIApplicationDelegateAdaptor(HotBodAppDelegate.self) private var appDelegate
@State private var router = AppRouter(initialRoute: LaunchRouteResolver.initialRoute())

// In WindowGroup body, after environment attached:
.onAppear {
    appDelegate.router = router
}
```

Keep UITesting behavior unchanged (NoOp scheduler means no real notifications in tests).

- [ ] **Step 3: Build to verify compile**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run focused regression suite**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueReassessCadenceTests \
  -only-testing:HotBodTests/AppEnvironmentPhysiqueOrchestrationTests \
  -only-testing:HotBodUITests/PhysiqueCadenceUITests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/App/HotBodAppDelegate.swift \
  HotBod/App/HotBodApp.swift \
  HotBod/Tests/UnitTests/PhysiqueReassessCadenceTests.swift \
  HotBod.xcodeproj
git commit -m "feat: open Physique tab from reassess notification"
```

---

## Spec Coverage Checklist

| Spec requirement | Task |
|------------------|------|
| 6-week due from active `createdAt` | 1 |
| No catch-up push when past due | 1, 2 |
| Piggyback `workoutRemindersEnabled` | 2 |
| One-shot id `hotbod.physique.reassess` | 2 |
| Fire at `timeOfDayPreference.reminderHour` | 1, 2 |
| Reschedule after assess/save; cancel on wipe | 2 |
| `rescheduleAllLocalReminders` with workout | 2 |
| Due banner `physique.cadenceDue` | 3 |
| Stale banner independent / order | 3 |
| No banner on history snapshots | 3 |
| `-SeedPhysiqueCadenceDue` UITest | 3 |
| Notification tap → Physique tab | 4 |
| UITesting NoOp scheduler | 2 |
| Non-medical copy | 2, 3 |

## Out of Scope (do not implement)

- Settings toggle / custom interval
- Today tab cadence chip
- Auto-assess from notification
- Harder program coupling

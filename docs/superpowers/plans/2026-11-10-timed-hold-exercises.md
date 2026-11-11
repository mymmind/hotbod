# Timed Holds and Dead Hang Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Dead Hang to the catalog and a wall-clock hold countdown that completes any duration-based set, with an always-visible kilogram field that treats a cleared value as bodyweight.

**Architecture:** `HoldCountdown` and `TimedSetLogging` are pure domain types. `WorkoutSession` stores the hold end instant the same way it stores rest. The session view starts, stops, and commits through the existing `completeCurrentSet` path.

**Tech Stack:** Swift, SwiftUI, Swift Testing via XCTest, XcodeGen, iOS 26 simulator.

## Global Constraints

- iOS 26+. Local-first. No new backend dependency.
- Black/white brutalist UI. No extra gradients. No emoji. No cheesy copy.
- Duration is stored on `CompletedSet.durationSeconds`.
- Blank added-load draft commits `nil`, not `0`.
- Hold and rest are not active together.
- UI tests launch with `-UITesting -ResetState -MockAI -MockFoodSearch -SkipOnboarding`.
- Reaching zero is covered by date-injected unit tests, not a sleeping UI test.

## File structure

- Create: `HotBod/Domain/Algorithms/HoldCountdown.swift` — countdown, outcome, target resolution.
- Create: `HotBod/Domain/Algorithms/TimedSetLogging.swift` — weight-field predicate, added-load commit and display.
- Create: `HotBod/Core/Components/ForgeHoldTimerBar.swift` — HOLD bar.
- Create: `HotBod/Features/WorkoutSession/WorkoutSessionView+HoldTimer.swift` — start, stop, restore, commit.
- Create: `HotBod/Tests/UnitTests/HoldCountdownTests.swift` — domain, catalog, decode tests.
- Modify: seed, content JSON, metadata resolver, load overrides, seed DTO, `WorkoutSession`, set table, session view, UI test seed.

---

### Task 1: Domain countdown and added load

**Files:**
- Create: `HotBod/Domain/Algorithms/HoldCountdown.swift`
- Create: `HotBod/Domain/Algorithms/TimedSetLogging.swift`
- Test: `HotBod/Tests/UnitTests/HoldCountdownTests.swift`

**Interfaces:**
- Produces: `HoldCountdown.starting(plannedSetId:workoutExerciseId:setIndex:targetSeconds:at:) -> HoldCountdown`
- Produces: `HoldCountdown.remaining(at:) -> Int`, `outcome(at:) -> HoldCommitOutcome`
- Produces: `HoldCountdownTarget.resolve(draft:plannedSeconds:exerciseDefault:) -> HoldTargetResolution`
- Produces: `TimedSetLogging.showsAlwaysVisibleWeightField(for:) -> Bool`
- Produces: `TimedSetLogging.committedAddedLoad(draft:plannedKg:) -> CommittedLoggedLoad`
- Produces: `TimedSetLogging.displayedAddedLoadText(draft:completedKg:plannedKg:) -> String`

- [ ] Write failing tests for remaining, end commit, early stop, cancel under one second, target resolution, weight predicate, empty-draft nil, completed nil display.
- [ ] Run `HoldCountdownTests` and confirm assertion failures.
- [ ] Implement the two domain types.
- [ ] Re-run until those tests pass.

### Task 2: Dead Hang catalog

**Files:**
- Modify: `HotBod/Resources/ExerciseSeed.json`
- Modify: `HotBod/Resources/ExerciseContent.json`
- Modify: `HotBod/Data/Local/LocalExerciseRepository.swift` (`ExerciseSeedDTO`)
- Modify: `HotBod/Domain/Models/ExerciseMetadataResolver.swift`
- Modify: `HotBod/Domain/Models/DomainModels.swift` (`ExerciseLoadTrackingOverrides`)

- [ ] Seed `dead_hang` as pull-up bar, isolation, static hold, beginner, time, 30 seconds, optional load, primary back/forearms/abs, secondary traps.
- [ ] Add substitution group `grip_hang` containing only `dead_hang`.
- [ ] Pass `prescriptionType`, `defaultDurationSeconds`, and `forceType` through the seed DTO.
- [ ] Add resolver and load-override fallbacks.
- [ ] Assert catalog fields, finisher exclusion, and group id.

### Task 3: Persist the hold on the session

**Files:**
- Modify: `HotBod/Domain/Models/DomainModels.swift` (`WorkoutSession`)

- [ ] Add optional `activeHoldEndsAt`, `activeHoldTargetSeconds`, `activeHoldPlannedSetId`, `activeHoldExerciseId`, `activeHoldSetIndex`.
- [ ] Decode with `decodeIfPresent`. Encode with `encodeIfPresent`.
- [ ] Test that JSON without those keys decodes with every hold field nil.

### Task 4: Session hold bar and weight field

**Files:**
- Create: `HotBod/Core/Components/ForgeHoldTimerBar.swift`
- Create: `HotBod/Features/WorkoutSession/WorkoutSessionView+HoldTimer.swift`
- Modify: `WorkoutSessionView.swift`, `WorkoutSessionView+SetTable.swift`, `WorkoutSessionView+ExerciseActions.swift`, `WorkoutSessionView+Persistence.swift`

- [ ] HOLD bar shares the rest bar slot. Identifiers `hold.start` and `hold.stop`.
- [ ] Start clears rest. Stop under one second cancels. Otherwise commit duration through `completeCurrentSet`.
- [ ] Zero commits the target. Restore of a past end commits the target.
- [ ] Timed kilogram rows always show weight. Empty draft commits nil. Inverted row keeps Add load.

### Task 5: UI test

**Files:**
- Modify: `HotBod/App/UITestConfiguration.swift`
- Modify: `HotBod/App/AppEnvironment+Workout.swift`
- Modify: `HotBod/Tests/UITests/BaseUITestCase.swift`
- Create: `HotBod/Tests/UITests/TimedHoldUITests.swift`

- [ ] `-SeedTimedHold` puts a single-set plank first.
- [ ] UI test starts and stops immediately, asserts the set stays open and rest does not start.
- [ ] Comment that zero and elapsed logging are unit-tested with an injected date.

### Task 6: Verify

```bash
xcodegen generate
xcodebuild test -project HotBod.xcodeproj -scheme HotBod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -only-testing:HotBodTests/HoldCountdownTests \
  -only-testing:HotBodUITests/TimedHoldUITests
```

# Timed Holds and Dead Hang

Date: 2026-11-10  
Status: Approved for planning

## Problem

Plank and side plank are already timed holds. Logging them means typing seconds. Rest between sets has a wall-clock countdown. The hold itself does not.

Dead hang is missing from the catalog, so it cannot be chosen or programmed.

These holds also need added weight (belt, vest, or plate) without forcing a kilogram onto a bodyweight set.

## Goals

- Add Dead Hang as a normal catalog exercise the generator can select for back, grip, or core work.
- Give every duration-based exercise one hold countdown on the active set.
- Reaching zero logs the target duration and completes the set. Stopping after at least one second logs the time held.
- Show a kilogram field on timed exercises that track real weight. A cleared field means bodyweight.
- Keep duration on `CompletedSet.durationSeconds` and complete the set through the existing log path, including rest.

## Non-goals

- A pause control, extra time buttons, or per-second countdown beeps during the hold.
- A watch countdown. The phone owns the clock. The watch snapshot updates when the set commits, as it does today.
- Changing weight-sanity thresholds or the Save anyway policy.
- Putting Dead Hang on the core-finisher allowlist.
- Putting Dead Hang in the `back_vertical_pull` swap group.
- Sleeping a UI test for a full hold.

## Dead Hang

Seed id `dead_hang`, name Dead Hang.

| Field | Value |
| --- | --- |
| Equipment | `pullUpBar` only |
| Movement pattern | `isolation` |
| Mechanics | `isolation` |
| Force | `staticHold` |
| Difficulty | `beginner` |
| Primary muscles | `back`, `forearms`, `abs` |
| Secondary muscles | `traps` |
| Prescription | `time` |
| Default duration | 30 seconds |
| Load tracking | `optional` |
| Substitution group | `grip_hang`, member list is only `dead_hang` |

Isolation is deliberate. The selector may add another isolation in a session that already has a vertical pull, so a pull-up and a dead hang can both appear. A `verticalPull` tag would take the single vertical-pull slot from pull-ups and pulldowns.

`grip_hang` keeps swap from offering Dead Hang as a pull-up replacement. The library, add-exercise, and the generator still see it. Generation uses the existing ranker with no extra boost. It is eligible when a target muscle matches one of its primary muscles and a pull-up bar is available.

`ExerciseMetadataResolver.timeExerciseIds` includes `dead_hang`. `ExerciseLoadTrackingOverrides.map` maps `dead_hang` to `.optional`. The seed row sets `prescriptionType` and `loadTrackingMode` as well, so the fallbacks cover tests and older rows that omit those fields.

Content in `ExerciseContent.json`:

- Aliases: Bar Hang, Deadhang.
- Instructions: hang from a bar with a shoulder-width overhand grip, arms long, ribs down.
- Form cues: shoulders active, ribs down, steady breath.
- Common mistakes: shrugging into the ears, kipping, holding the breath.

## Added weight

Timed exercises that track kilograms always show the weight field. The Add load switch is removed for those rows.

Predicate `TimedSetLogging.showsAlwaysVisibleWeightField`:

- `resolvedPrescriptionType` is `.time` or `.distanceOrTime`
- `resolvedLoadTrackingMode` is not `.none`
- `resolvedWeightDisplaySemantics.tracksExternalKilograms` is true

Plank, side plank, and dead hang match. Their stored load mode stays `.optional`, so `plansExternalLoad` stays false until that exercise has a logged kilogram. The first prescriptions leave `targetWeightKg` nil. After a logged added weight, later sessions may fill a target and progress it.

Rower, battle ropes, and other timed work whose load mode is `.none` or whose semantics are a resistance level keep their current fields. Rep exercises, including inverted row, keep the Add load switch.

Farmer's carry matches the predicate: it is distance-or-time and it tracks kilograms. Its weight field was already visible. A cleared field on that row commits `nil` instead of falling back to the planned load. Any later exercise that matches the predicate does the same.

Weight commit for rows where the predicate is true:

| Draft | Result |
| --- | --- |
| Missing (`nil`) | Planned kilograms, which may themselves be `nil` |
| Empty or whitespace | `nil` (bodyweight), even when a planned target exists |
| Number | That number |
| Non-numeric (`-`, `.`) | Blocked, same as today |

Display for those rows:

- Incomplete set, missing draft: show the planned kilograms, or empty when the plan is `nil`.
- Incomplete set, empty draft: show empty.
- Completed set with `weightKg == nil`: show empty. Do not fall back to the planned target.
- Completed set with a weight: show that weight.

A blank field does not write `0`. Completing the set does not require a number.

This display and commit rule is separate from barbell `displayedWeightText` / `committedLoad`, which still treat an empty draft as “use planned.”

## Hold clock

### Who gets it

Any exercise with `resolvedPrescriptionType` of `.time` or `.distanceOrTime`. The seconds field is the timed metric. Distance, when the prescription has one, still commits through the existing distance draft or planned meters.

### Value type

`HoldCountdown` in Domain:

- `plannedSetId`
- `workoutExerciseId` (`WorkoutExercise.id`)
- `setIndex`
- `targetSeconds` (greater than 0)
- `endsAt`

Remaining seconds use `WorkoutSessionCalculator.restSecondsRemaining(until:at:)`, which is `max(0, ceil(end − now))`.

Elapsed seconds are `targetSeconds − remaining`.

Outcomes, given `now`:

| Condition | Outcome |
| --- | --- |
| Remaining is 0 | Commit `targetSeconds` |
| Elapsed is 0 | Cancel. The set stays open |
| Otherwise | Commit elapsed seconds |

Stop before the remaining display has dropped by one second cancels. Stop after that logs the whole seconds already held. Zero logs the target, not a value above the target.

Target chosen at start:

1. A typed seconds draft that parses to an integer greater than 0.
2. Else, when the draft is missing or empty, `PlannedSet.targetDurationSeconds` when it is greater than 0.
3. Else, when the draft is missing or empty, `ExerciseMetadataResolver.defaultDurationSeconds`.
4. A non-empty draft that is not a positive integer blocks Start. It does not fall through to the planned target.
5. If no step produces a target greater than 0, Start does nothing.

### Persistence

`WorkoutSession` stores optional fields, decoded with `decodeIfPresent`, default `nil`:

- `activeHoldEndsAt`
- `activeHoldTargetSeconds`
- `activeHoldPlannedSetId`
- `activeHoldExerciseId`
- `activeHoldSetIndex`

All five are required to restore a hold. Anything missing means no hold. Existing session JSON without these keys still decodes.

Invariant: `activeHoldEndsAt` and `activeRestEndAt` are not both set. Starting a hold clears rest and does not complete a set. Completing a hold clears the hold fields, then the existing post-set path may start rest.

On restore:

- The set is already completed, or the exercise or set is gone: discard the hold.
- `endsAt` is still in the future: show the running countdown.
- `endsAt` is in the past: commit that set at `targetSeconds`, then run the normal post-set path.

### Session UI

The HOLD bar uses the same screen slot as the rest bar. Only one is visible. Rest visible means the hold bar is hidden. A running hold means the rest bar is hidden.

The bar shows remaining time as `formattedElapsed`.

- No hold running, and the exercise on screen has an incomplete timed set: show Start (`hold.start`) for that set (the first incomplete set).
- A hold is running: show Stop (`hold.stop`) and the remaining time. Start is hidden. When the on-screen exercise is a different one, the bar also names the exercise the clock belongs to.
- There is one clock. Start is not offered for a second set while one is running.

While that clock is running, the seconds field for its planned set shows the target and does not accept edits. The weight field stays editable. The logged duration comes from the clock. The normal complete control on that set is Stop.

While the clock is idle, typing seconds and completing the set is unchanged.

Cancel writes nothing into `durationTexts` and clears the hold fields.

Stop, zero, and the complete control, when the outcome is a commit:

1. Clear the hold fields.
2. Write the outcome duration into `durationTexts` for the planned set.
3. Call `completeCurrentSet` for the hold’s exercise and set index.

Weight, distance, reps, and RPE stay on the existing commit path. Timed sets store 0 reps, as they do today. The set-complete cue plays, then rest starts the way it does after a manual log.

If weight sanity returns before the set is appended, the seconds draft still holds the outcome duration. The set stays open so the athlete can fix the load and log again. This uses the existing prompt. It does not add a sanity rule.

## Testing

Unit tests inject `now`. They do not sleep.

`HoldCountdown`:

- Remaining matches `restSecondsRemaining` for the same end date and `now`.
- At `endsAt`, the outcome is commit of `targetSeconds`.
- After remaining has dropped by at least one second, Stop commits elapsed.
- Before that, Stop cancels.
- Target resolution uses a positive typed draft first.
- A missing or empty draft uses the planned seconds, then the exercise default.
- A non-empty draft that is not a positive integer blocks Start.

Catalog:

- `dead_hang` is pull-up bar, isolation, static hold, beginner, time, 30-second default, optional load.
- Primary muscles are back, forearms, and abs.
- It is absent from `CoreFinisherPlanner.allowlist`.
- Its substitution group is `grip_hang` and is not `back_vertical_pull`.

`TimedSetLogging.showsAlwaysVisibleWeightField`:

- True for plank, side plank, and dead hang.
- False for rower or battle ropes.
- False for inverted row.

Added-load commit and display:

- Missing draft uses the planned kilograms.
- Empty draft commits `nil` and displays empty on an incomplete set.
- A completed set with `nil` weight displays empty.

`WorkoutSession` JSON without hold keys decodes with every hold field `nil`.

UI test, launch flags `-UITesting -ResetState -MockAI -MockFoodSearch -SkipOnboarding`:

- A session whose current exercise is a plank shows the HOLD bar and `hold.start`.
- After Start, `hold.stop` is present and `hold.start` is absent.
- Start then Stop immediately leaves that set incomplete.

The UI test file states that reaching zero and logging a real elapsed hold are covered by the date-injected unit tests.

## Architecture notes

- `HoldCountdown` and `TimedSetLogging` are pure. The session view owns when to start, persist, and call `completeCurrentSet`.
- New `WorkoutSession` init parameters default to `nil` so current call sites keep compiling.
- Duration history, overload, and sync keep reading `CompletedSet.durationSeconds`.

# HotBod master review

**Date:** 14 October 2026  
**Revision:** `main` at `13745db`  
**Method:** Seven read-only reviews of the shipped P0 workout engine, the rest of the training product, architecture, persistence, tests, logging UX, and safety. Findings below are the ones that survive de-duplication. Lane notes are in the appendix.

## Verdict

P0 did what it was asked to do at plan time. A stored suggestion is not incremented again on regenerate. A skipped RIR does not count as effort. The duration number includes warmups, rest, transitions, core, conditioning, and cooldown.

That guarantee dies the moment the user trains on a reduced day, and the sessions a 4-day push/pull/legs lifter actually gets are still the sessions in the 13 October audit. Fix the two write-back bugs before any more generator work. Then fix set counts, the rep floor, and the three missing movement slots. Do not add coach copy, charts, or sync of new planner state until those are true.

## What holds

- `SessionLoadPlanner` is the generate path and the manual-add path. Recovery is 0.7, deload and return-from-break are 0.9, and only one of those applies. Generating twice does not add another increment.
- Skip and swipe-dismiss mark the set skipped and clear RIR, RPE, and failure. Unknown historic RIR is ignored only when “Use older effort entries” is off. Explicit RIR still moves load and can start a high-effort deload.
- The duration budget runs after the full session is assembled. The stored minute count and the “Estimated N min” sentence use the same number. Standard sessions do not drop below 4 exercises. Recovery sessions do not drop below 3.
- Local JSON still decodes old profiles, sets, and sessions. Missing effort keys stay trusted. Missing session mode is standard.
- Personal use is on by design for this checkout: Pro is unlocked, account UI is hidden, launch does not pull from Supabase, and the coach is Gemini only when a key is configured. Tracked source has no hardcoded API keys. HealthKit readiness is read-only.
- Domain algorithms are pure Foundation code. Repository protocols and the no-backend stubs are real. An invalid generated plan is not saved.

## Do this, in this order

Each item is the smallest change that removes a user-visible lie. Do not start the next item by building a new subsystem.

### 1. A reduced day must not become the new baseline

`ProgressiveOverload.updateStats` (`HotBod/Domain/Algorithms/Algorithms.swift` around 408–523) builds the next suggestion from whatever weight was just logged. A recovery plan of 67.5 kg at 0.7 is about 47.5 kg. Hitting the top of the range stores about 50 kg. The next normal session plans 50 kg. A deload week does the same with 0.9.

Pass the session mode and whether a deload or return-from-break modifier was active. When one was, keep the previous `suggestedNextWeightKg` and still record the set, the reps, and the volume. Add `testRegression_modifiedSessionWriteBack`.

### 2. Cooldown sets must not freeze the bar

`updateStats` treats planned cooldown sets as working sets and completed cooldown sets as not working (`Algorithms.swift` around 433). `hitTop` then never fires. A user who turns cooldown on and finishes every working set at the top of the range never gets a load increase.

Filter planned sets with the same rule as completed sets: not warmup and not cooldown. Add `testRegression_cooldownBlocksProgression`.

### 3. One prescription for generate, add, and swap

Three planners still disagree:

- `WorkoutGenerationService.planExercise` applies optional load, beginner clamps, deload set cuts, warmups, and `SessionLoadPlanner`.
- `SessionExercisePlanner` skips optional load (weighted dips and pull-ups stay bodyweight) and always uses a standard effort target.
- `ExerciseSwapReplanner` (`Phase2Algorithms.swift`) never calls `SessionLoadPlanner`. A deload-week swap of 67.5 kg stays 67.5 kg. Tests only check a 30 kg substitute, so the suite stays green.

The immediate fix is to route swap and manual add through `SessionLoadPlanner` with the session mode and deload flags, and to use the generator’s optional-load rule. The structural fix, after those tests exist, is one `ExercisePrescriber` that all three call.

### 4. Completing a workout must be safe to run twice

`WorkoutSessionView` sets the session completed and then calls `applyWorkoutSessionCompletion`. A second path on the UI-test End Workout button does the same work. `updateStats` appends recent sets and advances deload state on every call. A repeat double-counts volume. The writes use `try?`, so a failure is silent.

Add one `completeWorkoutSession` that saves, applies fatigue, updates stats, and advances the program, and that no-ops when that session id was already applied. Delete the duplicate button path. Add `testRegression_sessionCompletionIdempotent`.

### 5. Stop planning 1-set sessions

This is the audit, still in the code. Each muscle has a 14-set budget over a rolling 7 days (`MuscleVolumePlanner.swift` around 98–118). One full session spends it. Four to six days later the next push, pull, or legs day is still inside the window, so every exercise is floored at 1 set. Glutes are a primary on squat, lunge, sled push, and RDL, so leg day B becomes 1 set of everything. The rationale still says the target muscles are recovered.

Size the session from weekly sets divided by how often that split day actually happens. Cap an exercise by the muscle it was chosen for, not the tightest of all its primaries. Do not plan a selected exercise for 1 set; drop it and say why. When volume is cut, say which muscle is full.

### 6. Reopen the rep range when the load goes up

Two sessions of `holdLoadIncreaseReps` turn 8–10 into 10–10 (`Algorithms.swift` around 599). The range is not reset on `.increaseLoad`. The set row pre-fills the minimum, so tapping Done logs that minimum. Once min equals max, that tap is a top-of-range hit and the load goes up every session.

On a load increase, restore the goal’s default range. Do not treat an untouched field as a logged minimum.

### 7. Protect three slots

- Legs need a knee-flexion slot (leg curl family) filled before generic hamstring fill, and the duration budget must not drop it because an RDL already “covers” hamstrings.
- Push needs a lateral-raise slot. Front raise, face pull, and rear-delt fly must not tie with it.
- Pull needs one rear-delt slot and at most one curl.

Also take sled push off the bodyweight list, or it keeps winning leg-day slots in gyms with no sled. Exempt the anchor compound of each slot from the recent-use penalty so bench does not vanish every other push day.

### 8. A soreness tap must not throw away the workout in progress

`applySorenessChange` (`TodayView.swift` around 449) regenerates and `cancelActiveWorkoutIfNeeded` drops the live session with no confirmation. Logged sets never reach stats. The new plan excludes every exercise that was just on screen.

Hide the soreness strip while a session is active. A readiness change should adjust sets and load on the same exercises.

### 9. Make the numbers on screen mean what they say

- Progress “E1RM Trend · Last 12 weeks” plots the 14-day set cache. “Top Lifts” compares e1RM to average weight. Until real per-session history exists, show best set this session against last exposure for the anchor lifts, and remove the percent and “+kg” lines.
- Today’s set pills count warmups. Count working sets, and show warmups as a separate suffix.
- “Safety Notes” includes “risk of overtraining” and instructions to swap compounds for isolations. Keep injury and equipment notes. Delete the overtraining wording. If the validator wants less volume, the generator should already have cut it.

### 10. Make logging one thumb

- Tapping a completed row leaves the bottom button on “Update Set” after the keyboard dismisses (`WorkoutSessionView.swift` around 444). Clear that sticky index when there is no draft.
- Reps and seconds fields snap back to the planned number when cleared. Select-all on focus, the way weight already does.
- The RIR sheet starts the rest timer only after dismiss, and Skip is a small target at the top of the sheet. Start rest when the set is logged. Put the choices in the thumb zone.
- Replace the countdown lines (“Let’s go”, “All gas”) with the first exercise, the set count, and the weight.

### 11. Before anyone turns sync on

Personal use does not sync today. The moment it does, these are data-loss bugs:

- A stats pull drops `lastMaxEffortAt`, `sessionsSinceMaxEffort`, `preferVariation`, and `isOrphaned` because the remote row has no columns for them, then replaces the local array.
- Sign-in pulls program state before it pushes, and it does not sync the in-progress session. An older cloud snapshot can clear `activeSessionId`.
- A failed stats fetch while toggling “Use older effort entries” saves an empty list over every lift (`AppEnvironment+Profile.swift` around 7).
- Pushing a session deletes its child rows before the new ones are written. A failed request leaves a partial cloud workout that the next pull can copy back.

Do not sync new planner fields until pull merges by time and the four local-only stat fields have columns.

### 12. Before any build that is not this phone

`PersonalUseConfig.defaultIsEnabled` is `true`, and `-UITesting` / `GRANT_PRO=1` can grant Pro in a Release binary. That is the right setting for this personal checkout. It is the wrong default for TestFlight. Build one capabilities value at launch, and keep the test launch arguments out of Release.

The injury table does not block pull-ups for a shoulder limitation, or a Romanian deadlift for a knee limitation, and the seed catalog stores no contraindication text. The plan still says movements were adjusted. Add Exercise lists the whole catalog and ignores the filter the generator just used. Fix the table, stop the false sentence, and filter the add sheet the same way swaps are filtered.

The on-device Gemini prompt does not carry the user’s limitations or the bans already in the server coach prompt. Apply those before a real Gemini key is bundled. The key must not go in the URL query string.

## Do not build yet

- Coach explanations, Foundation Models copy, or more AI surfaces. They would narrate 1-set sessions and a random shoulder accessory.
- More variety controls or a bigger catalog, except seated calf raise and a sled equipment flag.
- A full stimulus-tag system, family load transfer, or a mesocycle UI. The three slots in item 7 cover most of what the audit felt.
- 12-week charts, strength scores, or HealthKit-weighted readiness. The history those need does not exist, and the recovery model is uncalibrated.
- Physique scores that feed training with numbers. Keep photos qualitative. No body-fat figures.
- Supabase columns for new planner state.

## What the suite does not catch

`HotBodTests` is green on this revision. These production holes still pass:

| Hole | Test that would fail if the hole were closed |
|---|---|
| Deload or recovery swap keeps full load | `testRegression_swapAppliesSessionLoadModifier` |
| Trust-flag save failure still writes the profile | `testRegression_trustFlagSaveFailureHoldsProfile` |
| Regenerated workout ignores the recomputed suggestion | extend `testRegression_untrustedHistoricEffort` to read `todayWorkout` |
| Manual add ignores session mode | `testRegression_manualAddUsesSessionLoadModifier` |
| Recovery property cases never run | let `WorkoutGenerationInput.random` include a recovery session, and stop requiring 4 exercises there |

## Appendix: lane counts

Reviewed at `13745db`. No code was changed by the review.

| Lane | Critical | Important | Minor | Worst item |
|---|---:|---:|---:|---|
| Workout engine | 2 | 5 | 5 | Reduced-day weight written back as the next baseline |
| Product | 5 | 7 | 8 | Alternate sessions planned at 1 set |
| Architecture | 3 | 8 | 8 | Completion path is not idempotent |
| Persistence and sync | 2 | 5 | 2 | Stats pull drops four local progression fields |
| Tests | 3 | 7 | 3 | Swap modifier untested and wrong |
| Logging UX | 3 | 5 | 3 | Bottom button stuck on Update Set |
| Safety and trust | 0 | 5 | 4 | Injury table and Add Exercise do not match the plan’s claim |

The engine, architecture, and test lanes describe the same three prescription paths. They are one fix in the order above, not three projects. The product lane’s “planned load is stable” claim is true until a reduced session is logged; item 1 overrides it.

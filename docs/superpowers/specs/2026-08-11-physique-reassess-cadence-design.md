# Physique Reassess Cadence Design

**Date:** 2026-08-11  
**Status:** Approved for planning  
**Depends on:**  
- `docs/superpowers/specs/2026-08-10-physique-assessment-coach-replacement-design.md`  
- `docs/superpowers/specs/2026-08-10-physique-assessment-history-diff-design.md`  
- Existing workout local reminders (`LocalWorkoutReminderScheduler`, `workoutRemindersEnabled`)

## Goal

Close the longitudinal Physique loop with a **6-week reassess cadence**: one-shot local notification after the active assessment’s `createdAt`, plus an in-app due banner on the Physique report. Cancel and reschedule on successful reassess. Piggyback enablement on `workoutRemindersEnabled` (no new Settings toggle).

## Constraints

- iOS 17+, SwiftUI, local-first; reuse `UNUserNotificationCenter` patterns from workout reminders.
- Cadence is calendar weeks from **active** assessment `createdAt` only (newest history entry).
- Stale-photo banner (`PhysiquePhotoGate.isStale`) stays independent.
- Prefer: “reassess,” “refresh your focus,” “time to reassess.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims, nagging catch-up pushes when already overdue.
- UITests / `-UITesting` use no-op schedulers.
- App must compile after each slice; tests per AGENTS.md hygiene.

## Non-goals

- User-configurable interval or dedicated Physique reminder Settings toggle
- Catch-up / repeating notifications when already past due
- Auto-running assessment from the notification
- Changing training bias or priorities from cadence alone
- Cloud sync of reminder state
- Merging Progress photo UI into Physique

## Decisions

| Topic | Choice |
|-------|--------|
| Job | Local notification + in-app due banner |
| Trigger | Fixed 6 weeks after active `createdAt` |
| Enablement | Piggyback `workoutRemindersEnabled` |
| In-app | Due banner above report (stale banner unchanged) |
| Architecture | Parallel physique reminder scheduler + pure cadence helper |
| Past due at schedule time | Banner only; no catch-up push |

## 1. Product Surface

### Cadence rule

- Constant: `PhysiqueReassessCadence.intervalWeeks = 6`.
- **Due** when `now >= createdAt + 6 weeks`.
- No active assessment → no schedule, no due banner.
- Stale-photo banner unchanged; both may show.

### In-app

- On the **active** Physique report only: if due → `ForgeCard` banner  
  “6 weeks since last assessment — reassess to refresh your focus.”  
  Accessibility: `physique.cadenceDue`
- History / past snapshot screens: no cadence banner.
- Banner order when both apply: stale-photo first, then cadence due.
- Successful reassess clears due and reschedules +6 weeks from the new assessment.

### Notification

- One-shot local notification at the due date/time.
- Fire time: reuse `profile.timeOfDayPreference.reminderHour` (minute `0`), on the calendar day of the due date.
- Title: `Time to reassess`  
  Body: `Capture updated photos and refresh your Physique focus.`
- Identifier: `hotbod.physique.reassess` (prefix for cancel scoping; do not touch `hotbod.workout.*`).
- Tap → select **Physique** tab via notification response handling on `AppRouter`.
- If due date is already in the past when scheduling: **do not** enqueue a catch-up notification; in-app banner covers overdue.

### Enablement

| Condition | Schedule? | Due banner? |
|-----------|-----------|-------------|
| No assessment | No | No |
| Reminders off | Cancel pending | Yes if due |
| Authorization denied | No pending | Yes if due |
| Reminders on + authorized + assessment + dueDate > now | Yes | No (not due yet) |
| Reminders on + authorized + assessment + already due | No pending | Yes |

Authorization: reuse the existing center; request only when status is `.notDetermined` (same options as workout reminders). Do not re-prompt from Physique if denied.

## 2. Architecture

### Domain (pure)

```text
PhysiqueReassessCadence
  intervalWeeks: 6
  dueDate(from createdAt: Date, calendar: Calendar) -> Date
  isDue(assessmentCreatedAt: Date, now: Date, calendar: Calendar) -> Bool
  nextFireDateComponents(
    from createdAt: Date,
    timeOfDay: TimeOfDayPreference,
    now: Date,
    calendar: Calendar
  ) -> DateComponents?   // nil when already past due or invalid
```

### Services

```text
PhysiqueReassessReminderScheduling
  reschedule(profile: UserProfile, assessmentCreatedAt: Date?) async
  cancelAll() async

LocalPhysiqueReassessReminderScheduler
NoOpPhysiqueReassessReminderScheduler
```

- `reschedule`: `cancelAll` for physique ids → if `workoutRemindersEnabled` and `assessmentCreatedAt` present and authorized and `nextFireDateComponents != nil` → add one request.
- Planner/copy helpers live beside the scheduler (mirror `WorkoutReminderPlanner` style).

### AppEnvironment

- Inject scheduler next to `workoutReminderScheduler` (UITesting → no-op).
- `reschedulePhysiqueReassessReminder()` reads `userProfile` + `activePhysiqueAssessment?.createdAt`.
- Prefer `rescheduleAllLocalReminders()` that runs workout + physique so call sites stay in sync.
- Invoke after: bootstrap / profile save (reminder toggle) / successful `assessPhysique` / `saveActivePhysiqueAssessment` / account or assessment clear (`cancelAll`).

### Deep link

- Introduce a small `UNUserNotificationCenterDelegate` (or app-owned center delegate) wired at launch.
- On response: if identifier has prefix `hotbod.physique.reassess` → `router.selectedTab = .physique` (and ensure main route if needed).
- Prefer a pure helper `PhysiqueNotificationRouting.tab(forIdentifier:)` for tests — no URL scheme.

## 3. UI States, Errors, Testing

### UI matrix

| Case | Behavior |
|------|----------|
| No assessment | No banner; cancel/no-op schedule |
| Assessment &lt; 6 weeks | No banner; one-shot pending when enabled |
| Assessment ≥ 6 weeks | Show `physique.cadenceDue`; no catch-up push |
| Stale photos + cadence due | Both banners (stale, then cadence) |
| Reminders off / denied | Banner when due; no pending notification |
| Successful reassess | Banner clears; reschedule +6 weeks |
| Past history snapshot | No cadence banner |

### Errors

- Notification `add` failure → silent; in-app due still works.
- Denied permission → no Physique-driven re-prompt.
- Copy remains non-medical.

### Testing

- Unit: `PhysiqueReassessCadence` dueDate / isDue / nextFireDateComponents (including past-due → nil).
- Unit: planner id + hour from `timeOfDayPreference`.
- Integration: fake scheduler receives `reschedule` / `cancelAll` after assess, reminder toggle, and clear assessment.
- UITest: seed assessment with `createdAt` ~7 weeks ago → assert `physique.cadenceDue`; fresh assessment → absent. Prefer `-SeedPhysiqueCadenceDue` launch flag alongside existing UITesting stack.
- Deep link: unit test identifier → `.physique` via routing helper.

## 4. Out of Scope Follow-ups

- Dedicated Settings toggle / custom 4/6/8-week interval
- Deep link that pre-opens camera / import
- Cadence chip on Today tab
- Harder program coupling from assessment

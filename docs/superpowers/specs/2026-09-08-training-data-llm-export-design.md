# Training Data LLM Export

Date: 2026-09-08  
Status: Approved for planning

## Problem

Users want to take their HotBod training log to an external LLM (ChatGPT, Claude, etc.) for coaching feedback. Existing export paths do not serve that:

- HealthKit writes Apple Health workouts, not a readable history.
- Post-session share cards are images, Pro-gated, and cover one session.

There is no way to copy or share a full, LLM-readable dump of training, protein, and recovery.

## Goals

- Export **all completed workout history**, current recovery, exercise stats, training profile (no name), and **all protein history as daily totals**.
- Produce **one markdown document**.
- Let the user **copy** that markdown (paste into a chat) **and share a `.md` file** (Files, AirDrop, Messages) from a **single system share sheet**.
- Live in Settings as a one-shot action. No preview screen, no date picker, no JSON, no Pro gate.
- Keep generation as a **pure Domain function** so it is unit-tested without UI.

## Non-goals

- Re-import / round-trip restore.
- JSON or CSV variants.
- Date-range UI (all history is the v1 rule).
- Per-meal protein lines.
- Body photos, physique assessments, or illustration data.
- Changing HealthKit export or workout share cards.
- Gating this export behind `ProFeature.workoutExport` (share cards stay Pro).
- In-app LLM analysis of the dump.
- Medical advice, body-fat estimates, or coach copy that claims diagnosis.

## Locked decisions

| Topic | Decision |
|--------|----------|
| Delivery | Copy + file via one `UIActivityViewController` |
| Format | Markdown only |
| Scope | Profile + completed sessions + exercise stats + protein daily totals + current recovery |
| Range | All history |
| Access | Free |
| UI | Settings → App → Export training data |
| Photos / name / physique | Excluded |

## Architecture

Three units:

1. **`TrainingDataExportSnapshot`** — Codable input bag. No UI, no repositories.
2. **`TrainingDataMarkdownExporter`** — `static func render(_ snapshot: TrainingDataExportSnapshot, generatedAt: Date, calendar: Calendar) -> String`. Pure. Default `generatedAt` / `calendar` for production; tests inject both.
3. **`AppEnvironment.makeTrainingDataExport() async throws -> TrainingDataExport`** — loads repositories, filters, writes a temp file, returns markdown + file URL + filename.

Settings calls (3), then presents existing `ShareSheet(items:)` with **the markdown `String` first and the file `URL` second**. System Copy uses the string; Save to Files / AirDrop uses the file.

```
Settings App section
  → makeTrainingDataExport()
      profile / sessions / stats / protein (distantPast…now) / recovery / exercise catalog
      → snapshot (completed sessions only; name stripped)
      → TrainingDataMarkdownExporter.render
      → write temp hotbod-training-YYYY-MM-DD.md
  → ShareSheet([markdown, fileURL])
```

No backend. No new repository methods: protein uses existing `fetchEntries(from:to:)` with `Date.distantPast` and `Date()`.

## Snapshot

```swift
struct TrainingDataExportSnapshot: Equatable {
    var profile: UserProfile?           // caller must already have name = nil
    var sessions: [WorkoutSession]      // completed only, any order (exporter sorts)
    var exerciseStats: [UserExerciseStats]
    var proteinEntries: [ProteinEntry]
    var recovery: [MuscleRecoveryState]
    var exerciseNames: [String: String] // catalog id → display name
    var proteinGoalGrams: Double
}

struct TrainingDataExport: Equatable {
    var markdown: String
    var fileURL: URL
    var filename: String
}

enum TrainingDataExportError: Error, Equatable {
    case fileWriteFailed
}
```

`AppEnvironment` is responsible for:

- Setting `profile?.name = nil` (and not putting `id` in the markdown even if it remains on the struct).
- Filtering `sessions` to `status == .completed`.
- Building `exerciseNames` from `exerciseRepository.fetchAll()`.
- Using `userProfile?.proteinGoalGrams ?? 145` as `proteinGoalGrams`.
- Passing through all protein entries and all persisted exercise stats and recovery states.

The exporter must **not** trust the caller for sort order. It sorts itself.

## Markdown contract

UTF-8. Local calendar dates as `yyyy-MM-dd`. Weights in kg with trailing zeros stripped (`80`, `77.5`). Display names from existing `displayName` properties on domain enums. Unknown exercise ids fall back to the raw id.

### Header

```
# HotBod training export
Generated: 2026-09-08
Not medical advice. Paste into an LLM if you want coaching on this log.
```

`Generated` is the local calendar date of `generatedAt`. The third line is **exactly** that sentence (no extra medical or motivational copy).

### Section order (always all five, in this order)

1. `## Profile`
2. `## Recovery (current)`
3. `## Exercise stats`
4. `## Workouts`
5. `## Protein`

Empty sections still appear. Body is a single line: `None logged.`

### Profile

If `profile` is nil: `None logged.`

Otherwise, bullet list using display names:

- Goal, experience (one line, ` | ` separated)
- Location, split, session length minutes
- Training days (weekday display names, profile order)
- Equipment (display names, profile order)
- Limitations (display names). If `limitationNotes` is non-empty, a following bullet `Notes: …`
- Preferred / avoided muscle groups only if the arrays are non-nil and non-empty
- `Protein goal: {n} g`
- Body line only if at least one of age, heightCm, weightKg is present, omitting missing pieces. Example: `Body: 28y, 178 cm, 82 kg`

**Must omit:** `name`, UUID/`id`, `photoTrackingEnabled`, reminder/HealthKit/export toggles, `createdAt`/`updatedAt`.

### Recovery

Markdown table:

```
| Muscle | Preparedness | Last trained |
| Chest | 72 | 2026-09-06 |
```

- One row per recovery state.
- Muscle column: `MuscleGroup.displayName` (e.g. `Chest`, `LowerBack`).
- Preparedness: `recoveryPercentage` rounded to nearest integer.
- Last trained: `yyyy-MM-dd` or `—` if nil.
- Sort rows by `muscleGroup.rawValue` ascending so output is stable.

If `recovery` is empty: `None logged.`

### Exercise stats

One bullet per stat that has **at least one** of: `lastWeightKg`, `lastReps`, `estimatedOneRepMax`, non-empty `recentSets`. Skip empty shells.

Format:

```
- {name}: last {weight} kg × {reps}, e1RM {e1rm}, trend {trend}
```

- Name from `exerciseNames[exerciseId] ?? exerciseId`.
- Omit `last …` fragments whose values are nil.
- Omit `e1RM` if `estimatedOneRepMax` is nil (round to nearest integer kg if present).
- `trend` is `volumeTrend.displayName` (`Increasing`, `Stable`, `Decreasing`).
- If `preferVariation` is true, append `; prefer variation`.
- If `isInDeloadWeek(at: generatedAt)` is true, append `; in deload`.
- Sort by display name, then exercise id.

If none qualify: `None logged.`

### Workouts

Sort sessions by `completedAt ?? startedAt ?? .distantPast` **descending** (newest first). Stable tie-break: `id.uuidString`.

Each session:

```
### 2026-09-07 — Upper
Duration 48m | Difficulty 7/10 | Focus: Upper
- Bench press: 80×8, 80×7 (wu), 77.5×6
```

- Heading date: local date of `completedAt ?? startedAt`. If both nil, use `Unknown date`.
- Title after em dash: `session.title`. If title is empty, `Workout`.
- Meta line pieces only when present, ` | `-joined: `Duration {n}m` from `startedAt`/`completedAt` interval rounded to minutes if both exist, else `estimatedDurationMinutes`; `Difficulty {n}/10` if `perceivedDifficulty` exists; `Focus: {splitDayFocus.displayName}` if focus exists.
- If `notes` is non-empty, a following line `Notes: {notes}`.
- Exercises ordered by `orderIndex`. Skip exercises with no completed sets **and** not skipped. Skipped exercises: `- {name}: skipped` plus skip reason if present.
- Completed sets ordered by `setIndex`. Compact tokens joined by `, `:
  - Weight × reps: `{weight}×{reps}`. If `weightKg` is nil and `reps > 0`: `BW×{reps}`.
  - If `reps == 0` and `durationSeconds` is set: `{seconds}s` (and weight prefix if present).
  - If `distanceMeters` is set and reps are 0: `{meters}m`.
  - Append ` @ RPE {n}` if `rpe` is set. Whole numbers as integers (`8`); otherwise one decimal (`8.5`).
  - Append ` RIR {n}` if `rir` is set.
  - Suffixes: ` (wu)` if `isWarmup`, ` (cd)` if `isCooldown`, ` (fail)` if `isFailure`.

If no completed sessions: `None logged.`

### Protein

Aggregate `proteinEntries` by local start-of-day. **Include only days with at least one entry** (do not emit empty calendar days). Newest day first.

```
- 2026-09-07: 138 g (goal 145)
```

- Grams: sum of `proteinGrams` for the day, rounded to nearest integer.
- Goal: `proteinGoalGrams` from the snapshot, rounded to nearest integer.
- Do **not** use `ProteinComplianceCalculator.dailyTotals` — that helper fills a fixed rolling window with empty days and weekday labels. The exporter groups itself.

If no entries: `None logged.`

## File + share

- Filename: `hotbod-training-yyyy-MM-dd.md` using local calendar date of `generatedAt`.
- Write UTF-8 to `FileManager.default.temporaryDirectory`.
- Before write, delete existing temp files whose names match `hotbod-training-*.md` so exports do not accumulate.
- `TrainingDataExportError.fileWriteFailed` if write throws.
- Share sheet items: `[export.markdown, export.fileURL]` in that order.
- Do not add a second in-app Copy button.

## Settings UI

**Placement:** App section in `SettingsView+Profile.swift`, above Delete All Data (and above Version is fine if Delete is only shown in some configs — put Export **after** Version / Name and **before** any Delete All Data row so it is always visible, including when Supabase is configured and delete lives under Account).

Preferred order in App section:

1. Existing plan / haptics / sound / version / name rows (unchanged)
2. Divider
3. **Export training data** action row
4. Caption
5. Existing delete row when it already lives in this section

When delete lives only under Account (Supabase configured), still show Export in App so it is not tied to account deletion.

**Copy (L10n keys in `Localizable.xcstrings` + `L10n.Settings`):**

| Key | English |
|-----|---------|
| `settings.exportTrainingData` | Export training data |
| `settings.exportTrainingData.hint` | Workouts, protein, and recovery as markdown. Copy or share the file. |
| `settings.exportTrainingData.exporting` | Exporting… |
| `settings.exportTrainingData.failed` | Export could not be created. Try again. |

Action row uses accent color (not destructive). `accessibilityIdentifier`: `settings.exportTrainingData`.

**States:**

- Idle: title `Export training data`, enabled.
- In flight: title `Exporting…`, disabled. Do not present the sheet until the method returns.
- Failure: caption under the hint in `ForgeColors.destructive` using the failed string. Do not present the sheet.
- Success: present `ShareSheet`. Clear any previous export error.

Empty data is **success**, not an error.

No paywall. Do not call `canAccess(.workoutExport)`.

## Privacy and product rules

- Never include profile `name`, photos, photo paths, physique assessments, or illustration blobs.
- Never include exact body-fat claims (none exist in this dump).
- Header must include `Not medical advice.`
- Session `userId` and profile `id` do not appear in markdown.

## Testing

### Unit — `HotBod/Tests/UnitTests/TrainingDataMarkdownExporterTests.swift`

New algorithm → unit tests required. Cover:

- Omits `name` even if the snapshot profile still had a name (belt-and-suspenders: exporter blanks it if present).
- Planned / in-progress / cancelled sessions omitted; only completed included.
- Sessions newest-first.
- Protein daily totals; two meals on one day become one line; a day with no meals is absent.
- Warmup set tagged `(wu)`.
- Empty snapshot still contains all five `##` headings and `None logged.`
- Disclaimer sentence present.
- Filename/date formatting is **not** this type’s job; renderer tests pass a fixed `generatedAt`.

### Integration — `HotBod/Tests/Integration/TrainingDataExportIntegrationTests.swift`

New `AppEnvironment` method → integration test required. Dedicated file (do not grow `IntegrationFlowTests`).

- Seed onboarded profile **with a name**, one completed session with a known title, one protein entry, recovery defaults.
- `makeTrainingDataExport()` succeeds.
- `markdown` contains the session title and does **not** contain the profile name.
- `fileURL` exists on disk and contents equal `markdown`.
- Incomplete session is not in the markdown.

### UI — `SettingsUITests`

New user-facing flow → UI test.

- `testExportTrainingDataRowExists`: open Settings, scroll until `settings.exportTrainingData` exists.
- Do **not** assert the system share sheet (flaky). Identifier presence is the gate.

## Files

Create:

- `HotBod/Domain/Algorithms/TrainingDataMarkdownExporter.swift` — snapshot types + renderer + set/protein formatting
- `HotBod/App/AppEnvironment+TrainingExport.swift` — gather, write temp file
- `HotBod/Tests/UnitTests/TrainingDataMarkdownExporterTests.swift`
- `HotBod/Tests/Integration/TrainingDataExportIntegrationTests.swift`

Modify:

- `HotBod/Features/Settings/SettingsView.swift` — `@State` for exporting, error, share items, share sheet
- `HotBod/Features/Settings/SettingsView+Profile.swift` — App section rows
- `HotBod/Core/Localization/L10n.swift`
- `HotBod/Resources/Localizable.xcstrings`
- `HotBod/Tests/UITests/SettingsUITests.swift`
- `HotBod.xcodeproj/project.pbxproj` — add new Swift files to app and test targets
- `HotBod/Features/Settings/SettingsErrorMessages.swift` — do not add export errors here; use `L10n.Settings` for the failed caption.

Do not modify `ForgeSubscriptionProducts` / `ProFeature.workoutExport`.

## Implementation notes

- Keep `TrainingDataMarkdownExporter.swift` focused; if set-token formatting grows, a private enum in the same file is enough — do not split unless the file exceeds ~250 lines.
- Reuse `ShareSheet`; do not create a second representable.
- Calendar and locale in tests: `Calendar(identifier: .gregorian)` with a fixed time zone (`GMT`) so date headings do not flake.
- `AGENTS.md` validation: build must compile; empty state is a valid export; previews unchanged (Settings preview still works).

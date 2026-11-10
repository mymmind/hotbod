# Exercise Video Handoff + Merge Workflow

Date: 2026-11-10  
Status: Approved for planning

## Problem

HotBod has 96 seed exercises and 60 YouTube demo links in `YouTubeExerciseVideos.json`. The other 36 show no form demo. A tester offered to find videos if given a list. Today there is no regenerable missing list and no safe way to batch-merge new URLs into the catalog.

This is step 1 of the broader feedback thread. Kettlebell off-day circuits are out of scope here and will get their own design next.

## Goals

- Produce a regenerable handoff list of exercises missing YouTube demos.
- Accept contributor replies as simple `exercise_id URL` lines.
- Merge those lines into `YouTubeExerciseVideos.json` with the same validation the app/tests already assume.
- Keep playback code unchanged.

## Non-goals

- In-app contributor UI.
- CSV / spreadsheet round-trip.
- New exercises or kettlebell catalog expansion.
- Circuit / superset / off-day session types.
- Bundled MP4 production or rehosting YouTube files.
- Tightening license policy beyond “public embeddable YouTube URL” (same bar as the current 60).

## Design

### Handoff artifact

Path: `docs/exercise-video-handoff.md`

Generated from `ExerciseSeed.json` vs `YouTubeExerciseVideos.json`. Contents:

1. Short contributor instructions: reply with one `exercise_id` + YouTube URL per line; watch, youtu.be, embed, shorts, and m.youtube URLs are fine; any public embeddable clip is acceptable.
2. **Missing** section: every seed exercise without a catalog entry — `id`, display name, equipment.
3. Kettlebell-capable missing rows listed first (today: `kettlebell_swing`, `goblet_squat`, `farmers_carry`, `single_leg_rdl`).
4. **Covered** summary: count only (do not dump all 60 URLs), so contributors focus on gaps.

The file is regenerable after every merge so it stays accurate as coverage grows.

### Merge script

Path: `Scripts/merge_youtube_exercise_videos.py`

**Inputs**

- Existing `HotBod/Resources/YouTubeExerciseVideos.json`
- Seed IDs from `HotBod/Resources/ExerciseSeed.json`
- New pairs from stdin or a file: one `exercise_id <url>` per line

**Behavior**

- Parse YouTube video IDs from watch, youtu.be, embed, shorts, and m.youtube URLs (parity with `YouTubeVideoID` in Swift).
- Reject unknown exercise ids, non-YouTube hosts, and malformed video ids.
- Overwrite an existing entry for the same exercise id.
- Write sorted JSON mapping `exercise_id` → canonical `https://www.youtube.com/watch?v=VIDEO_ID`.
- On any bad row: exit non-zero with line-numbered errors; do not write a partial file.
- Empty input: no-op with a clear message; leave JSON unchanged.

**Report mode**

- `--report` regenerates `docs/exercise-video-handoff.md` from current seed + JSON (no merge).
- After a successful merge write, the script always regenerates the handoff so the checklist stays current.

### License note

Update `MEDIA_LICENSE_NOTES.md` to document this fill-in path: contributors supply public embeddable YouTube watch URLs; HotBod still embeds only and does not download or rehost.

### App / data model

No changes to:

- `YouTubeExerciseCatalog`
- `ExerciseDemoPlayerView` / `YouTubeEmbedPlayer`
- `ExerciseSeed.json` schema
- Playback fallback for unmatched exercises

## Errors

| Condition | Result |
|-----------|--------|
| Unknown exercise id | Fail batch; report line |
| Non-YouTube / unparseable URL | Fail batch; report line |
| Empty input | No-op message; exit 0 |
| Missing seed or JSON file | Fail fast |

## Verification

No new XCTest required for the script itself.

1. `--report` shows 36 missing against today’s catalog (or the current delta after merges).
2. Merge a fixture pair → JSON gains/updates that key with a canonical watch URL; handoff missing count drops.
3. Existing `YouTubeExerciseCatalogTests` pass on the updated JSON (every entry is a seed id + parseable YouTube URL).

## Follow-ups (separate designs)

- Expand kettlebell exercise coverage in the seed catalog.
- Off-day / home kettlebell circuit session type (5 exercises × 5 reps × 5 rounds, rest between rounds).

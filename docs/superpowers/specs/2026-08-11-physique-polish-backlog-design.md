# Physique Polish Backlog Design

**Date:** 2026-08-11  
**Status:** Approved for planning  
**Depends on:**  
- `docs/superpowers/specs/2026-08-11-physique-front-only-assessment-design.md`  
- `docs/superpowers/specs/2026-08-11-physique-reassess-cadence-design.md`

## Goal

Clear the parked Physique review backlog: optional-side analysis parity with back, edge prompt honesty for missing back, a positive stale-with-back unit test, small UI/test copy cleanup, and commit the pending `Localizable.xcstrings` sync. No new product surface.

## Constraints

- iOS 17+, SwiftUI, local-first patterns already in Physique.
- Prefer: “fuller read,” “better results,” “reassess,” “refresh your focus.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims, inventing posterior metrics without a back angle.
- Optional angles that fail analysis are omitted, not fatal (front remains required).
- App must compile; tests per AGENTS.md hygiene.
- Discard unrelated cadence plan working-tree doc tweak (not product).

## Non-goals

- Cadence Settings toggle / custom interval
- Harder program coupling
- Broader Today/Train/Settings polish
- Completeness meter redesign
- Changing illustration or assess gate rules beyond side omit-on-failure

## Decisions

| Topic | Choice |
|-------|--------|
| Scope | Review backlog bag A only |
| Side analysis | Same `optionalAnalysis` path as back |
| Edge | Prompt hard-rule only (validation already correct) |
| Localizable | Commit sync for shipped Physique strings |
| Cadence plan md dirty | Discard |

## 1. Hybrid side parity

- In `HybridPhysiqueAssessmentService.ensureMetrics`, analyze side via `optionalAnalysis` (not throwing `asyncMap`).
- In `regatePrepared`, omit side when `analysis == nil` (mirror back resolution).
- Front analysis failure remains fatal.
- Regression: front + unanalyzable side → assess succeeds with `sidePhotoId == nil`.

## 2. Edge prompt honesty

- In `buildPhysiqueSystemPrompt` (`physiqueSchemas.ts`), add one hard-rule bullet: when `anglesAvailable` does not include `"back"`, do not invent posterior/back musculature metrics or claim back-photo evidence.
- No change to `validatePhysiqueRequest` (already front-only capable).
- Deno: assert prompt text contains the rule (or a stable substring) if a prompt unit test already exists; otherwise add a small string assertion test.

## 3. Stale-with-back unit test

- Positive case: assessment with non-nil `backPhotoId`, `createdAt` in the past, newer back photo in library → `PhysiquePhotoGate.isStale == true`.
- Existing nil-`backPhotoId` ignore-newer-back test remains.

## 4. UI / test copy cleanup

- `PhysiqueView.emptyMessage`: default to “Add a front photo to get a focus plan.” (retire misleading “fuller read” else).
- `PhysiqueAnglesUpsellHiddenUITests` (or related) comment: history seed is front+back+side.

## 5. Localizable + working tree

- Commit `HotBod/Resources/Localizable.xcstrings` entries for new Physique strings (cadence due, front-only ready, angles upsell, etc.).
- `git checkout --` / discard `docs/superpowers/plans/2026-08-11-physique-reassess-cadence.md` working-tree edits.

## 6. Testing

- Unit: Hybrid side omit regression; positive stale-with-back.
- Deno: prompt rule presence.
- Spot: existing `PhysiquePhotoGateTests`, front-only assess orchestration, upsell UITests still pass.

## Out of scope follow-ups

- Optional-side hard-fail elsewhere outside Hybrid
- Cadence product settings
- Harder training coupling

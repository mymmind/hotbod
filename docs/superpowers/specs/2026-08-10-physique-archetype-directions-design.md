# Physique Archetype Directions Design

**Date:** 2026-08-10  
**Status:** Approved for planning  
**Depends on:** `docs/superpowers/specs/2026-08-10-physique-assessment-coach-replacement-design.md` (shipped Physique Focus assessment)

## Goal

Extend the Physique assessment report with **curated physique direction matches**: generic aesthetic labels as the primary signal, optional famous era/role references as secondary flavor, and short similarity rationales. Matching is catalog-gated (hybrid cloud + offline). **Report-only** — does not change training bias or program generation.

## Constraints

- iOS 17+, SwiftUI, local-first patterns already used by Physique assessment.
- Closed catalog only — model/offline may not invent archetype IDs or celebrity names outside the seed.
- Prefer wording: “physique direction,” “proportional similarity,” “reference.”
- Avoid: “you look like,” “celebrity twin,” identity/lookalike claims, exact body-fat %, genetic destiny.
- No celebrity images or competitor assets.
- Extend existing `physique-assess` edge function; do not add a second assess hop.
- Backward compatible decode for persisted assessments missing the new field.
- App must compile after each slice; tests per AGENTS.md hygiene.

## Non-goals

- Training bias / goal / split changes from archetype selection
- User “choose your direction” goal picker
- After-image / future physique generation
- Free-form celebrity invention outside the catalog
- Deleting dormant chat `coach` infra
- Subscription packaging changes

## 1. Product Surface

### Placement

Physique report only — after **Development Priorities**, before **Why today’s training**.

Not shown on Today, Progress, or workout generation surfaces.

### Section UI

| Element | Copy / behavior |
|---------|-----------------|
| Title | `Physique directions` |
| Subtitle | `Reference directions for proportions and silhouette — not a prediction.` |
| Rows | Up to 3 ranked matches |
| Primary line | Catalog `genericLabel` |
| Secondary line | Optional `Reference: {referenceLabel}` when present |
| Rationale | `similarityDimension` (one short line) |
| Footer | `These are physique directions, not identity matches. Bone structure, insertions, and training response differ.` |

Accessibility:

- Section: `physique.directions`
- Row: `physique.direction.<archetypeId>`

Show the section only when sanitized `physiqueDirections` is non-empty. Resolve display labels from the **local catalog** by id — never trust cloud-supplied display names.

## 2. Catalog

App-owned seed: `HotBod/Resources/PhysiqueArchetypeCatalog.json` (exact path may follow existing Resources seed conventions).

```text
PhysiqueArchetypeCatalogEntry
  id: String
  genericLabel: String
  referenceLabel: String?     // famous era/role, optional
  tags: [String]
  similarityHints: [String]
```

v1 size: ~8–12 curated entries covering lean fighter, classic athletic, compact athletic, men’s physique / fitness-model direction, muscular athletic, etc. Some entries may be generic-only (no `referenceLabel`).

Loader mirrors exercise-seed style; unit-testable; no network.

## 3. Domain Model

```text
PhysiqueArchetypeMatch
  archetypeId: String
  rank: Int
  similarityDimension: String
  confidence: PhysiqueObservationConfidence
```

Extend `PhysiqueAssessment`:

```text
physiqueDirections: [PhysiqueArchetypeMatch]  // ordered, max 3
```

Decoding: missing key → `[]` so older persisted assessments still load.

## 4. Assess Pipeline

### Cloud

- Request includes `allowedArchetypeIds` (and optionally compact label/tag summaries for the prompt).
- Response adds `physiqueDirections: [{ archetypeId, rank, similarityDimension, confidence }]`.
- JSON schema / validation: `archetypeId` must be in the allowed set.
- System prompt: rank only from allowed IDs; write similarity dimensions; forbid identity/lookalike claims and banned medical/BF%/genetic copy.

### Client sanitizer

- Drop unknown IDs
- Cap at 3; re-number ranks densely 1…n
- Scrub `similarityDimension` with the same free-text bans as other assessment strings
- If cloud returns empty/all-invalid → run offline matcher so the section can still populate

### Offline

- Deterministic tag/heuristic match from `PhysiqueBuildSummary` + development priorities
- Output only catalog IDs with short canned/templated `similarityDimension` strings
- Same max-3 ordering rules

### Persistence

Directions ride on the existing active `PhysiqueAssessment` document. Reassess refreshes them with the rest of the report.

## 5. Errors & Partial States

| Case | Behavior |
|------|----------|
| Catalog missing/unloadable | Omit section; rest of assessment unchanged |
| All cloud IDs unknown | Offline matcher; if still empty, omit section |
| Old assessment without field | Decode `[]`; next Reassess fills |
| Low photo confidence | Prefer fewer matches and/or lower confidence; still no lookalike claims |

## 6. Testing

### Unit

- Catalog load + expected entry count/shape
- Sanitizer: unknown IDs dropped, cap 3, rank densified, free-text scrub on `similarityDimension`
- Offline matcher: stable fixtures → stable top IDs
- Decode: assessment JSON without `physiqueDirections` → empty array

### Integration

- Mock remote returning directions → persisted on active assessment
- Unknown remote IDs stripped; offline fill when remote directions empty

### Edge (Deno)

- Allowed-ID contract / invalid id handling
- Prompt/schema includes directions field
- Auth/key gates unchanged

### UI

- Seeded assessment shows generic label, optional reference line, disclaimer
- No “you look like” / identity copy
- Regression: `trainingBias` / generation merge unchanged when directions present

## 7. Implementation Order

1. Catalog seed + domain types + decode compatibility  
2. Offline matcher + sanitizer extensions  
3. Edge schema/prompt + remote mapping  
4. PhysiqueView section + tests  

## 8. Success Criteria

- User with a completed assessment sees up to three catalog-backed physique directions with clear non-prediction framing.
- No archetype ID or celebrity name appears unless it exists in the local catalog.
- Offline/on-device assessment still can populate directions.
- Workout generation / soft bias behavior is unchanged by this feature.
- Persisted pre-feature assessments continue to decode and display (without the new section until reassess).

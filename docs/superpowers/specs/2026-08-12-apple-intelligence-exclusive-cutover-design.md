# Apple Intelligence Exclusive Cutover Design

**Date:** 2026-08-12  
**Status:** Approved for planning (umbrella)  
**Depends on:** Existing Physique / coach / local-first architecture  
**Supersedes:** OpenAI- and Gemini-backed coach, remote Physique assess, remote Physique illustration, USDA food search, and Supabase as product dependencies for intelligence/cloud.

## Goal

Make HotBod **exclusively Apple** for intelligence: on-device Foundation Models for coach, Private Cloud Compute (PCC) for Physique assessment, no OpenAI/Gemini/image APIs. End state is also **fully local** — no USDA, no Supabase. Cut illustrative direction. Raise the OS floor to **iOS 26.0** for Foundation Models; PCC remains first-class when available via `#available(iOS 27.0, *)`.

## Constraints

- Prefer: “on-device,” “Apple Intelligence,” “focus,” “why today’s training.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims, “guaranteed AI” marketing.
- Safety-first: rules workout generation, coach modification safety, Physique sanitizers, and validation **never** bypassed by the model.
- AI behind protocols with UITest / mock implementations (`-MockAI`).
- No hardcoding secrets (and no OpenAI/Gemini secrets once removed).
- App must compile after each phase; tests per AGENTS.md hygiene.

## Non-goals (umbrella)

- Exact `@Generable` / guided-generation schemas (phase specs)
- Final prompt copy (phase specs)
- PCC entitlement application steps beyond “required for Phase 2”
- Detailed Settings account UX after Supabase removal (Phase 5 design)
- Protein manual-entry UI polish (Phase 5 design)
- Keeping a dual-stack OpenAI feature flag

## Decisions

| Topic | Choice |
|-------|--------|
| Exclusivity | Hard cut — delete non-Apple LLM/image paths |
| Docs shape | Umbrella roadmap + per-phase design/plan |
| OS floor | Raise to **iOS 26.0** for on-device Foundation Models (set in Phase 1 against current Xcode SDK). PCC APIs are iOS 27+ and stay behind `#available(iOS 27.0, *)` until an iOS 27 SDK/runtime is available |
| Coach | On-device `LanguageModelSession` |
| Physique assess | PCC + Vision metrics + offline heuristic fallback |
| Illustration | Delete |
| Food | Local / manual only (no USDA) |
| Cloud | No Supabase auth/sync/edges |
| Keep non-AI | Rules generation, Vision, HealthKit, offline Physique, local repos |

## 1. End state

```text
Today workout     → RulesWorkoutGenerationService (unchanged owner)
Coach             → Apple on-device Foundation Models (+ offline/mock fallback)
Physique assess   → Vision → Apple PCC → OfflinePhysiqueAssessmentService fallback
Physique illustrate → removed
Food search       → local/manual only
Account / sync    → local wipe only; no cloud auth
```

## 2. Phase order (locked)

| Phase | Name | Outcome |
|-------|------|---------|
| **1** | Floor + FM scaffolding | Deployment target raised; thin Apple FM wrapper (availability, on-device session, PCC session, quota helpers); UITest mock; **no product cut yet** |
| **2** | Physique assess → PCC | Hybrid uses PCC then offline; delete `RemotePhysiqueAssessmentService` + edge `physique-assess`; quota/unavailable UX |
| **3** | Coach → on-device | Coach uses on-device FM; delete Gemini + `RemoteAIWorkoutService` + edge `coach` |
| **4** | Cut illustration | Remove UI, services, edge `physique-illustrate`, related strings |
| **5** | Local-only strip | Remove Supabase + USDA; simplify `BackendServices`; account = local wipe |

**Rule:** Do not start Phase N+1 until Phase N acceptance is green. Before each phase: short phase design (if needed) → implementation plan → implement → merge.

## 3. Kill list

| Artifact | Remove in |
|----------|-----------|
| `GeminiAIWorkoutService`, `GeminiConfig`, plist examples | Phase 3 |
| `RemoteAIWorkoutService`, edge `coach`, OpenAI coach wiring | Phase 3 |
| `RemotePhysiqueAssessmentService`, edge `physique-assess` | Phase 2 |
| `RemotePhysiqueIllustrationService`, `MockPhysiqueIllustrationService` (if unused), edge `physique-illustrate`, report illustration UI | Phase 4 |
| `USDAFoodSearchService`, `FoodAPIConfig` | Phase 5 |
| Supabase client, auth, cloud sync, `delete-account` edge, `SupabaseConfig` | Phase 5 |
| `OPENAI_*` / Gemini secrets and docs | Matching phase |

## 4. Keep through all phases

- `RulesWorkoutGenerationService` and domain algorithms / validators  
- `VisionBodyPhotoAnalyzer` (+ mock)  
- `OfflinePhysiqueAssessmentService`, `Domain/Physique/*` (sanitizer, bias merger, archetypes, split suggestion, etc.)  
- HealthKit readiness (optional)  
- Local repositories / SwiftData  
- Coach safety gates (`CoachModificationSafety`, etc.)  
- UITest flags: `-MockAI` maps to Apple session fake / offline paths  

## 5. Architecture (cross-phase)

### Apple wrapper (Phase 1)

Introduce a small protocol layer, e.g.:

```text
AppleLanguageModeling
  - availability (onDevice / pcc)
  - makeOnDeviceSession(...)
  - makePCCSession(...)
  - quota / isLimitReached (PCC)
```

Production: Foundation Models. UITesting / unsupported: no-op or fixture responder. Product features depend on this protocol — never import Foundation Models from feature views.

### Physique (Phase 2)

```text
photos → Vision metrics → PCC structured assess → PhysiqueAssessmentSanitizer
                         ↘ on failure / quota / unavailable → OfflinePhysiqueAssessmentService
```

Existing sanitizer and training-bias merge remain the source of truth for what the app trusts.

### Coach (Phase 3)

```text
user intent → on-device session → parse/propose → CoachModificationSafety → apply or reject
             ↘ unavailable → MockAIWorkoutService / CoachOfflineWorkoutProposer
```

Rules generation remains the owner of Today’s plan.

### Local-only (Phase 5)

- Protein: manual entry and/or small bundled local catalog — no USDA network.  
- Account: “Delete local data” only; remove cloud sign-in UI.  
- `BackendServices` collapses to local/mock factories.

## 6. Risks

| Risk | Mitigation |
|------|------------|
| PCC entitlement / eligibility (&lt;~2M downloads) | Apply early; Phase 2 ships offline assess if PCC not granted yet |
| OS floor drops devices | Accepted product choice; communicate in release notes |
| PCC daily quota | Check `quotaUsage`; clear unavailable UX; offline assess fallback |
| Losing cloud backup | Phase 5 explicit; local-first was already MVP principle |
| FM quality vs gpt-4o-mini | Structured output + sanitizer; offline heuristic floor |

## 7. Testing (umbrella rules)

- No live OpenAI/Gemini/PCC in CI.  
- Unit-test sanitizers, validators, offline assess, coach safety.  
- Protocol fakes for Apple sessions in unit/UI tests.  
- Each phase: build + focused tests green before merge.  
- Bug fixes: `testRegression_*` where applicable.

## 8. Out of scope follow-ups (post cutover)

- Re-introducing any non-Apple LLM  
- Cloud sync on a non-Supabase stack  
- Rebuilding generative illustration on a future Apple image API  
- Watch / multiplatform FM parity  

## 9. Next step after this umbrella

Write **Phase 1** design (if more detail needed) + implementation plan: raise deployment target, add Apple FM scaffolding/protocol, wire UITest mock, confirm build — **without** deleting product AI paths yet.

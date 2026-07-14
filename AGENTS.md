# AGENTS.md — HotBod

## Mission

Build a native iOS SwiftUI strength-training app inspired by Fitbod, but differentiated through AI coaching, protein tracking, body progress photos, and premium exercise video guidance.

## Product principles

- Premium black/white brutalist UI.
- Fast workout logging.
- Safety-first workout generation.
- AI explains and adapts but does not bypass validation.
- Local-first MVP.
- Backend-ready architecture.
- No competitor assets.
- No medical claims.
- No exact body-fat claims from selfies.

## Stack

- iOS 17+
- SwiftUI
- SwiftData
- MVVM + Services + Repositories
- AVKit
- PhotosUI
- Vision (optional, with mock fallback)
- HealthKit (optional, read-only readiness signal)
- Supabase (optional cloud sync/auth layer)
- OpenAI server-side later

## Coding rules

- Keep files small and focused.
- Prefer protocol abstractions for repositories/services.
- Use Codable models.
- Use mock/local implementations first.
- Add previews for major views.
- Add unit tests for algorithmic code.
- App must compile after each task.
- Do not introduce backend dependency in MVP.
- Do not hardcode secrets.
- Do not copy Fitbod assets, text, or data.

## UI rules

- Black/white brutalist base with minimal gray.
- Semantic accent palette via `ForgeColors`: `accent` (training/CTAs), `accentBlue` (protein), `accentGreen` / `accentAmber` (readiness), `destructive` (errors only).
- One signature gradient on primary CTAs (`accentGradient`); do not scatter gradients elsewhere.
- Reuse `ForgeHeroCard` for full-bleed inverted heroes across tabs.
- Strong typography.
- Large clear metrics.
- Fast one-handed workout logging.
- No cheesy motivational copy.
- No emoji-heavy UI.
- No random gradients.

## Validation

Before marking any task complete:
- Run build.
- Fix compile errors.
- Check navigation.
- Check empty states.
- Check local persistence.
- Check previews where possible.

## Test hygiene

- New algorithm → unit test required.
- New `AppEnvironment` method → integration test required.
- New user-facing flow → UI test or explicit exemption comment in the test file.
- Bug fix → regression test named `testRegression_<issue>`.
- UI tests launch with `-UITesting -ResetState -MockAI -MockFoodSearch`; use `-SkipOnboarding` unless exercising onboarding.
- Prefer stable `accessibilityIdentifier` values on primary CTAs; fall back to ForgeButton accessibility labels.
- Run PR tests via `HotBod.xctestplan` configuration **PR**; run full suite + property iterations (500+) on **Nightly**.
- Backend edge functions: add Deno tests beside `supabase/functions/` when changing validation or coach handlers.

### Coverage gates (ramp)

| Milestone | Gate |
|-----------|------|
| After Phase 1 | 60% |
| After Phase 3 | 70% |
| After Phase 4 | 80% |
| Domain/Algorithms | 90% (scoped gate on `HotBod/Domain/`) |

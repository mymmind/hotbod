# Implementation Backlog (Deduplicated)

Last updated: 2026-07-07

This backlog consolidates open implementation work from design audit files under `docs/design/subagents/*`.
It replaces broad checklist noise with a focused execution list.

## P0 - Critical

1. Dynamic Type foundation
   - Migrate `ForgeTypography` tokens from fixed `Font.system(size:)` to text-style driven tokens.
   - Spot-check core screens at large accessibility sizes.
   - Source: `E_accessibility.md` (SE-001, SE-002).

2. VoiceOver baseline coverage
   - Add labels/values/hints for primary navigation, Today actions, workout logging controls, disclosure sections.
   - Ensure selected state for tab items and expanded/collapsed disclosure state.
   - Source: `E_accessibility.md` (SE-003, SE-004, SE-008, SE-012).

3. Reduce Motion support
   - Add `accessibilityReduceMotion` handling in motion tokens and animated transitions.
   - Use opacity-only transitions when Reduce Motion is enabled.
   - Source: `E_accessibility.md` (SE-005).

4. Localization scaffold
   - Add `Localizable.xcstrings` and migrate high-impact strings first (tabs, CTAs, errors, empty states).
   - Source: `H_content.md` (SH-001).

5. User-facing error copy hardening
   - No raw system/API descriptions in UI.
   - Map auth/sync/settings failures to concise actionable messages.
   - Source: `H_content.md` (SH-003).

## P1 - High

6. 44pt interaction target audit
   - Ensure compact buttons and controls meet 44pt hit targets via `contentShape` or min frame.
   - Source: `E_accessibility.md` (SE-006, SE-009, SE-010).

7. CTA consistency pass
   - Standardize start/generate/apply wording across Today, Train, Coach.
   - Source: `H_content.md` (SH-004, SH-006, SH-010).

8. Case and tone normalization
   - Replace all-caps long labels and remove casual/slang coaching phrasing.
   - Source: `H_content.md` (SH-007, SH-008, SH-016).

9. Contrast token cleanup
   - Replace low-contrast muted text usage for small typography.
   - Raise inverse hero secondary contrast where needed.
   - Source: `E_accessibility.md` (SE-013, SE-014).

## P2 - Medium / Polish

10. Session logging accessibility polish
    - Disambiguate Skip actions and improve timer/action accessibility phrasing.
    - Source: `H_content.md` (SH-009), `E_accessibility.md` (SE-011).

11. Empty-state content harmonization
    - Use consistent templates and verb choices.
    - Source: `H_content.md` (SH-011, SH-015).

12. Body-progress disclaimer consistency
    - Keep visual-trend language clearly non-medical in all contexts.
    - Source: `H_content.md` (SH-012).

## Tracking Notes

- Keep detailed audits in `docs/design/subagents/*` as evidence artifacts.
- Use this file as the execution source of truth.
- When a backlog item is completed, add a short dated note under that item and link the implementing PR/commit.

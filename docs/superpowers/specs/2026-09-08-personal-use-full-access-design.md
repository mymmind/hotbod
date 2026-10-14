# Personal Use Full Access

Date: 2026-09-08  
Status: Approved for planning

## Problem

HotBod is currently a single-user app. Sign-in and Pro gates are overkill:

- Settings shows Account / Cloud backup whenever `SupabaseConfig.plist` is present.
- Cloud coach (`RemoteAIWorkoutService`) and remote physique/illustration refuse to run without a JWT, even though Gemini is already configured.
- Pro paywalls and weekly regen limits still apply in non-DEBUG builds.

The owner wants full local access and real coaching answers without signing in. Public release of accounts/paywalls is not in scope.

## Goals

- One compile-time flag, on until a later public release.
- Full Pro access in every build configuration (no paywall, no regen quota).
- No Sign In / Create Account / Sync / photo cloud backup UI.
- Real coach answers without an account: **Gemini** when configured, otherwise the existing mock/offline coach.
- Physique assessment still works via the existing Vision + offline heuristic path.
- Never show “Sign in” copy while the flag is on.
- Leave Supabase, StoreKit, and paywall code in the repo; do not select it.

## Non-goals

- Deleting Supabase, edge functions, or `SupabaseConfig.plist`.
- Wiring Apple Intelligence / Foundation Models into the coach.
- Changing `coach` / `physique-assess` / `physique-illustrate` edge functions.
- Anonymous or silent Supabase auth.
- USDA / food-search changes.
- Shipping-ready paywall or account UX.

## Locked decisions

| Topic | Decision |
|--------|----------|
| Flag | `PersonalUseConfig.isEnabled = true` (compile-time). Flip to `false` before public release. |
| Pro | `SubscriptionConfig.unrestrictedAccess` is true when personal use is on **or** DEBUG. Existing `unrestrictedAccessOverride` still wins in tests. |
| Coach | Personal use → Gemini if configured, else mock. Never `RemoteAIWorkoutService`. |
| Physique | Skip remote; go straight to offline hybrid. |
| Illustration | Use unavailable service; no “Sign in to generate.” |
| Cloud sync | Dormant. Do not restore a Supabase session at bootstrap. |
| Account UI | Hidden. Local “Delete All Data” stays in the App section. |
| Plan label | “Full access” (not “Pro” / regen counts). No Upgrade row. |

## Architecture

Three small units:

1. **`PersonalUseConfig`** — `isEnabled` plus a test override (`isEnabledOverride`), same pattern as `SubscriptionConfig.unrestrictedAccessOverride`. Always clear override in `defer`/tearDown.
2. **`AIWorkoutServiceSelection`** — pure function that picks `.remote` / `.gemini` / `.mock` from flags. `BackendServices.makeAIWorkoutService` calls it; tests do not need real clients.
3. **Settings visibility** — `PersonalUseConfig.shouldShowCloudAccountUI(supabaseConfigured:)` is `supabaseConfigured && !isEnabled`.

```
PersonalUseConfig.isEnabled
  ├─ SubscriptionConfig.unrestrictedAccess → true
  │     presentPaywall no-op; canAccess all Pro features
  ├─ Settings: hide Account + Cloud backup
  ├─ Bootstrap: skip authService.restoreSession
  ├─ Coach factory: Gemini or mock (never Remote)
  ├─ Physique factory: offline only (Hybrid remote = Unavailable)
  └─ Illustration factory: Unavailable
```

Supabase types remain behind `#if canImport(Supabase)`. Personal use simply does not instantiate them.

## Flag

New file `HotBod/App/PersonalUseConfig.swift` (keep `ForgeSubscriptionProducts.swift` focused on products/limits):

```swift
enum PersonalUseConfig {
    static let defaultIsEnabled = true

    nonisolated(unsafe) static var isEnabledOverride: Bool?

    static var isEnabled: Bool {
        isEnabledOverride ?? defaultIsEnabled
    }

    static func shouldShowCloudAccountUI(supabaseConfigured: Bool) -> Bool {
        supabaseConfigured && !isEnabled
    }

    static var shouldUseRemoteIntelligence: Bool { !isEnabled }
}
```

`shouldUseRemoteIntelligence` is the single gate for constructing Remote coach / remote physique / remote illustration. When it is false, those factories return Gemini/mock or Unavailable instead.

`SubscriptionConfig.unrestrictedAccess` becomes:

```swift
unrestrictedAccessOverride
    ?? (PersonalUseConfig.isEnabled || defaultUnrestrictedAccess)
```

`defaultUnrestrictedAccess` stays `true` in DEBUG / `false` in Release so that turning personal use off restores today’s DEBUG-unlocked / Release-gated behavior.

## Coach routing

```swift
enum AIWorkoutServiceSelection: Equatable {
    case remote, gemini, mock

    static func preferred(
        personalUse: Bool,
        supabaseConfigured: Bool,
        geminiConfigured: Bool
    ) -> Self {
        if personalUse {
            return geminiConfigured ? .gemini : .mock
        }
        if supabaseConfigured { return .remote }
        if geminiConfigured { return .gemini }
        return .mock
    }
}
```

`BackendServices.makeAIWorkoutService` switches on that result. UITest `-MockAI` continues to inject mocks at the `AppEnvironment` layer (unchanged).

Gemini general-chat intents that already fall through to `MockAIWorkoutService` stay as they are. That is accepted for personal use; do not expand Gemini coverage in this change.

## Physique and illustration

When `!PersonalUseConfig.shouldUseRemoteIntelligence`:

- `makeRemotePhysiqueAssessmentService` returns `UnavailablePhysiqueAssessmentService` so `HybridPhysiqueAssessmentService` does not wait on a 401.
- `makePhysiqueIllustrationService` returns `UnavailablePhysiqueIllustrationService`.
- Replace the illustration status string “Sign in to generate.” with “Illustration unavailable.” so `.notConfigured` is never framed as an account problem.

Offline physique quality gates (missing angles, quality failed) stay unchanged.

## Settings and bootstrap

**Settings** (`SettingsView.swift`):

- If `shouldShowCloudAccountUI`: existing Account + Cloud backup sections.
- Else: do not show the “Copy SupabaseConfig.plist…” debug cloud hint either. Cloud is intentionally unused.
- App section already shows Delete All Data when `!isSupabaseConfigured`. Change that to “when account UI is hidden” so local wipe remains available under personal use even if the plist is present.

**Bootstrap** (`AppEnvironment.bootstrap`): if personal use is on, skip `authService.restoreSession` / `pullFromCloud`. Local SwiftData stays the source of truth. A leftover session on device is ignored, not signed out as a side effect of this change (no extra `signOut` call required).

## Error handling

| Surface | Personal-use behavior |
|---------|------------------------|
| Coach, Gemini missing/fail | Existing mock/offline fallback. No “Sign in under Settings.” |
| Physique remote | Not called. Offline errors only. |
| Illustration | Unavailable copy. Never “Sign in to generate.” |
| Paywall | `presentPaywall` returns immediately. |
| Sync Now | Unreachable (Account hidden). |

`RemoteAIWorkoutService` may keep its sign-in guard for when personal use is later turned off. Do not change that string unless a test requires it for the personal-use path (that path must not instantiate Remote).

## Testing

Follow TDD. New algorithm → unit test.

| Behavior | Test |
|----------|------|
| Personal use + Gemini + Supabase → `.gemini` | `AIWorkoutServiceSelection` |
| Personal use + no Gemini → `.mock` | same |
| Personal use off + Supabase → `.remote` | same |
| Personal use off + only Gemini → `.gemini` | same |
| `unrestrictedAccess` true when personal use on, even if DEBUG default would be false | override seam |
| `presentPaywall` no-op / `canAccess` true under personal use | existing `AppEnvironment` subscription tests; set overrides |
| `shouldShowCloudAccountUI(true)` is false when personal use on | `PersonalUseConfig` |
| `shouldUseRemoteIntelligence` is false when personal use on | `PersonalUseConfig` |

`SubscriptionConfig.unrestrictedAccessOverride` remains the first `??` (highest priority). Existing paywall tests that set it to `false` keep working; they do **not** need a personal-use override.

UI tests: no new Account-flow tests. Existing UI tests already skip onboarding and grant Pro in several configurations; they should keep passing because unrestricted access stays on.

## Files

| File | Role |
|-------|------|
| `HotBod/App/PersonalUseConfig.swift` | Flag + test override |
| `HotBod/Services/AI/AIWorkoutServiceSelection.swift` | Pure coach routing |
| `HotBod/Services/Subscription/ForgeSubscriptionProducts.swift` | `unrestrictedAccess` includes personal use |
| `HotBod/Data/Remote/BackendServices.swift` | Use selection; skip remote physique/illustration |
| `HotBod/Features/Settings/SettingsView.swift` | Hide Account/Cloud; local delete still visible |
| `HotBod/Features/Settings/SettingsView+Profile.swift` | Plan label “Full access”; delete when account UI hidden |
| `HotBod/App/AppEnvironment.swift` | Skip session restore when personal use |
| `project.yml` | New Swift files; run `xcodegen generate` |
| `HotBod/App/AppEnvironment+Physique.swift` | Illustration copy: no sign-in |
| Unit tests for selection + unrestricted access | Required |

## Success criteria

- Launching a Release-configured build with the flag on: no Account UI, no paywall, coach uses Gemini, physique assess still returns an offline report.
- Flip `PersonalUseConfig.defaultIsEnabled` to `false` and behavior returns to today’s Supabase-first + DEBUG-only unrestricted access (Release paywalls return).
- `HotBod.xctestplan` PR tests pass.

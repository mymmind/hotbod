# Dark-Only App — Design Spec

**Date:** 2026-07-17  
**Status:** Approved for planning  
**Scope:** Force HotBod to a single dark appearance; remove light-mode palette support

---

## Goal

HotBod is a **dark-only** app:

- Always renders dark, regardless of the device Light/Dark setting
- System chrome (keyboard, alerts, pickers, share sheets) is dark
- No Appearance setting, no light palette, no adaptive color branching

---

## Decisions

| Decision | Choice |
|---|---|
| Lock strength | Collapse `ForgeColors` to dark-only constants (not adaptive) |
| System chrome | `UIUserInterfaceStyle = Dark` via generated Info.plist key |
| Visual polish | Minimal — no shadow/opacity redesign unless something is clearly broken after lock |
| Approach | Minimal lock (Info.plist + root preferred scheme + token collapse) |

---

## Technical design

### 1. Info.plist (generated)

Add to HotBod iOS target settings in `project.yml` (sync `HotBod.xcodeproj/project.pbxproj`):

```yaml
INFOPLIST_KEY_UIUserInterfaceStyle: Dark
```

This forces UIKit system chrome to dark.

### 2. App shell

On `RootView` in `HotBod/App/HotBodApp.swift`, add:

```swift
.preferredColorScheme(.dark)
```

Belt-and-suspenders with the Info.plist key for SwiftUI.

### 3. ForgeColors

In `HotBod/Core/DesignSystem/ForgeColors.swift`:

- Replace adaptive light/dark pairs with flat constants using the **current dark** hex values
- Delete private `adaptive(...)` helpers and light hex parameters
- Keep public token names unchanged (`backgroundPrimary`, `surface`, `accent`, legacy aliases, etc.) so call sites do not change

**Locked palette (from current dark side):**

| Token | Value |
|---|---|
| `backgroundPrimary` | `#121212` |
| `surface` | `#1C1C1E` |
| `surfaceInverse` | `#F2F2F7` |
| `textPrimary` | `#FFFFFF` |
| `textSecondary` | `#8E8E93` |
| `textOnInverse` | `#FFFFFF` |
| `borderSubtle` | white @ 20% |
| `accent` | `#FF5247` |
| `accentHot` | `#FF4D8A` |
| `accentBlue` | `#4D8BF7` |
| `accentGreen` | `#34C759` |
| `accentAmber` | `#FFB340` |
| `destructive` | `#FF453A` |

### 4. Call sites

No feature-screen rewrites. Views already consume `ForgeColors.*`.

---

## Out of scope

- Shadow / elevation polish pass
- Settings Appearance UI (none exists today)
- Asset-catalog color migration
- Watch target theming changes
- Updating historical design audit docs under `docs/design/` (optional follow-up)

---

## Validation

1. Build succeeds after token collapse + Info.plist key
2. Manual: device/simulator in **Light Mode** — app UI and system chrome stay dark
3. Smoke Today, Workout Session, and Settings for readable contrast
4. No new unit/UI tests required (no algorithmic change); existing UI tests should continue under forced dark

---

## Success criteria

- App never appears in light mode
- `ForgeColors` has no light/dark branching
- Keyboard, alerts, and system sheets render dark when the device is in Light Mode

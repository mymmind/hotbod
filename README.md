# HotBod

Native iOS strength-training app.

## Requirements

- Xcode 15+
- iOS 17+ Simulator

## Open & Run

```bash
open HotBod.xcodeproj
```

Select an iOS simulator and run `HotBod`.

Or from CLI:

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' build
```

## Project Structure

- `HotBod/App` — entry point, routing, dependency container
- `HotBod/Core` — design system and shared UI
- `HotBod/Domain` — models, enums, algorithms
- `HotBod/Data` — local repositories and seed loading
- `HotBod/Services` — workout generation, AI coach
- `HotBod/Features` — screens (onboarding, tabs, workout session)
- `HotBod/Resources` — `ExerciseSeed.json` (87 exercises)

## Phase 1 Scope

Local-first MVP with mock AI, rules-based workout generation, protein tracking, body photo import, and progress dashboard. No backend required.

## Phase 2

Status: implemented in the current local-first app.

- Recovery decay on bootstrap + soreness input on Today tab
- Stronger workout validation enforced before save
- Exercise substitution (algorithmic + seeded links) with working swap UI
- Progressive overload separates last weight vs suggested next weight
- Protein streak, compliance charts, editable goal in Settings
- Strength e1RM tracking on Progress dashboard
- Coach triggers workout regeneration for duration/injury requests (offline mock)

## Phase 3 — Supabase backend

Status: optional integration available (app still works fully offline).

### 1. Create a Supabase project

Create a project at [supabase.com](https://supabase.com), then apply the migration:

```bash
# Link your project (first time)
supabase link --project-ref YOUR_PROJECT_REF

# Push schema
supabase db push
```

Or paste `supabase/migrations/20250624120000_initial_schema.sql` into the SQL editor.

### 2. Configure the iOS app

```bash
cp HotBod/Resources/SupabaseConfig.plist.example HotBod/Resources/SupabaseConfig.plist
```

Edit `SupabaseConfig.plist` with your project URL and **publishable anon key** (never the service role key).

Add `SupabaseConfig.plist` to the Xcode target if not bundled automatically (it lives under `HotBod/Resources`).

### 3. What syncs

| Data | Local-first | Cloud when signed in |
|------|-------------|-------------------|
| Profile | Yes | Push + pull |
| Today's workout | Yes | `user_preferences.today_workout_json` |
| Completed workouts | Yes | Normalized tables |
| Protein entries | Yes | Push + pull (30 days on pull) |
| Body photos | Local by default | Opt-in via Settings → Photo cloud backup |
| Recovery / exercise stats / program rotation | Yes | Push + pull when signed in |

### 4. Auth

Settings → Account: sign up, sign in, sync now, sign out.

App works fully offline without `SupabaseConfig.plist`.

## Phase 4 — AI coach (Edge Functions)

Status: optional cloud mode available when Supabase + secrets are configured.

### 1. Set secrets and deploy

```bash
supabase secrets set OPENAI_API_KEY=sk-...
# optional: supabase secrets set OPENAI_MODEL=gpt-4o-mini

supabase functions deploy coach
```

The `coach` function requires a signed-in user JWT. It never exposes your OpenAI key to the iOS client.

### 2. How it works

| Mode | Coach behavior |
|------|----------------|
| No Supabase config | Offline mock coach |
| Configured, signed out | Offline mock coach |
| Configured, signed in | Calls `coach` edge function with `allowedExerciseIds` from local seed |

When the AI proposes a workout, Coach shows **Apply Workout** after server + client validation. Invalid proposals (unknown exercise IDs, etc.) are rejected.

Coach messages are persisted to `coach_messages` when using the cloud coach.

## Dashboard setup (no CLI)

Use this if you cannot run `supabase` locally.

### 1. Enable email auth

[Authentication → Providers → Email](https://supabase.com/dashboard/project/sikeiypsiewbznqwynpd/auth/providers) — ensure **Email** is enabled.

### 2. Run the database migration

1. Open the [SQL editor](https://supabase.com/dashboard/project/sikeiypsiewbznqwynpd/sql/new)
2. Copy the full contents of `supabase/migrations/20250624120000_initial_schema.sql`
3. Click **Run**

You should see tables like `profiles`, `workout_sessions`, `protein_entries`, `coach_messages`.

### 3. Create the storage bucket (if SQL didn't)

[Storage](https://supabase.com/dashboard/project/sikeiypsiewbznqwynpd/storage/buckets) — the migration creates private bucket `body-progress`. If missing, create a **private** bucket with that exact name.

### 4. Deploy the coach edge function

1. [Edge Functions](https://supabase.com/dashboard/project/sikeiypsiewbznqwynpd/functions) → **Create function** → name it `coach`
2. Replace the editor contents with the full file: `supabase/functions/coach/dashboard-bundle.ts`
3. Turn on **Verify JWT** (required)
4. **Deploy**

### 5. Add the OpenAI secret

[Edge Functions → Secrets](https://supabase.com/dashboard/project/sikeiypsiewbznqwynpd/functions/secrets)

| Name | Value |
|------|--------|
| `OPENAI_API_KEY` | your OpenAI API key |
| `OPENAI_MODEL` | optional, e.g. `gpt-4o-mini` |

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are injected automatically — do not add those manually.

### 6. iOS app

Ensure `HotBod/Resources/SupabaseConfig.plist` has your project URL and publishable anon key (not the service role key).

Rebuild → **Settings → Create Account** → **Sync Now** → test **Coach**.

Without the edge function + `OPENAI_API_KEY`, auth and sync still work; Coach uses the offline mock.

See `AGENTS.md` for coding rules.

## HealthKit setup (optional)

HotBod reads **sleep** and **resting heart rate** from Apple Health to show subtle recovery hints on the Today tab. This is read-only MVP — no medical claims, no write access.

### Enable in Xcode

1. Open `HotBod.xcodeproj` → select the **HotBod** target.
2. **Signing & Capabilities** → **+ Capability** → **HealthKit**.
3. Leave clinical health records off; only read access is used.
4. Rebuild and run on a physical device (Health data is limited in Simulator).

`NSHealthShareUsageDescription` is set via `project.yml`. Regenerate the project after editing:

```bash
xcodegen generate
```

### Without HealthKit capability

The app compiles and runs with `NoOpHealthKitReadinessService` fallback. Readiness still works from muscle recovery and manual soreness input.

### Vision body photos

Progress photos use Apple Vision (`VNDetectHumanBodyPoseRequest`) for pose/framing confidence and shoulder-to-waist **visual trend** comparison. Falls back to mock analysis when pose quality is poor. No body-fat or medical composition claims.

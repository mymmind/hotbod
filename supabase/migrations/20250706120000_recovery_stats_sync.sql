-- Recovery + exercise stats cloud sync (Phase 3 extension)

alter table public.user_preferences
  add column if not exists program_state_json jsonb;

create table if not exists public.user_exercise_stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id text not null,
  last_weight_kg numeric,
  last_reps int,
  suggested_next_weight_kg numeric,
  estimated_one_rep_max numeric,
  best_volume_set numeric,
  recent_sets jsonb default '[]',
  preferred_rep_range_min int default 8,
  preferred_rep_range_max int default 12,
  weekly_volume jsonb default '[]',
  weekly_max_sets int default 0,
  volume_trend text default 'stable',
  is_in_deload_week boolean default false,
  last_deload_date timestamptz,
  consecutive_high_volume_weeks int default 0,
  updated_at timestamptz default now(),
  unique (user_id, exercise_id)
);

create index if not exists idx_user_exercise_stats_user on public.user_exercise_stats(user_id);

alter table public.user_exercise_stats enable row level security;

create policy "exercise_stats_select_own" on public.user_exercise_stats
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "exercise_stats_insert_own" on public.user_exercise_stats
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "exercise_stats_update_own" on public.user_exercise_stats
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "exercise_stats_delete_own" on public.user_exercise_stats
  for delete to authenticated using ((select auth.uid()) = user_id);

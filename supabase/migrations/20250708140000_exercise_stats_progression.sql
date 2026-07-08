-- Progression hardening: dated deload, re-entry flag, goal stamp on exercise stats

alter table public.user_exercise_stats
  add column if not exists deload_started_at timestamptz,
  add column if not exists returning_from_break boolean default false,
  add column if not exists goal_at_last_update text;

-- Backfill dated deload from legacy columns when present
update public.user_exercise_stats
set deload_started_at = coalesce(deload_started_at, last_deload_date, case when is_in_deload_week then now() end)
where deload_started_at is null
  and (last_deload_date is not null or is_in_deload_week = true);

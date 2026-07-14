-- Parity sync: profile session settings, superset grouping, cooldown sets

alter table public.profiles
  add column if not exists include_warmup_sets boolean default true,
  add column if not exists include_cooldown boolean default false,
  add column if not exists preferred_exercise_grouping text default 'none',
  add column if not exists preferred_exercise_variability text default 'balanced',
  add column if not exists cardio_block_placement text default 'none',
  add column if not exists max_available_weight_kg jsonb default '{}',
  add column if not exists export_workouts_to_health_kit boolean default false;

alter table public.workout_exercises
  add column if not exists group_id uuid;

alter table public.completed_sets
  add column if not exists is_cooldown boolean default false;

alter table public.user_preferences
  add column if not exists exercise_preferences_json jsonb default '{}';

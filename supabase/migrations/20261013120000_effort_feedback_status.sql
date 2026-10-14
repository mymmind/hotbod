alter table public.profiles
  add column if not exists prompt_for_effort_feedback boolean not null default true,
  add column if not exists trust_historic_effort_feedback boolean not null default true;

alter table public.completed_sets
  add column if not exists effort_feedback_status text;

alter table public.workout_sessions
  add column if not exists session_mode text;

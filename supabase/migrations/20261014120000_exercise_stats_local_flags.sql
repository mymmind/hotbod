-- Local progression flags that a stats pull must not drop.

alter table public.user_exercise_stats
  add column if not exists is_orphaned boolean not null default false,
  add column if not exists last_max_effort_at timestamptz,
  add column if not exists sessions_since_max_effort int not null default 0,
  add column if not exists prefer_variation boolean not null default false;

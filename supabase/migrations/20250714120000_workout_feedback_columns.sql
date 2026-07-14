-- Workout feedback: RIR, timed/distance logging, session structure toggles

alter table public.profiles
  add column if not exists include_conditioning boolean default false,
  add column if not exists include_core_finisher boolean default true;

alter table public.completed_sets
  add column if not exists rir integer,
  add column if not exists duration_seconds integer,
  add column if not exists distance_meters double precision;

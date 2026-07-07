-- HotBod initial schema (Phase 3)

-- Profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  age int,
  height_cm numeric,
  weight_kg numeric,
  goal text not null default 'buildMuscle',
  experience_level text not null default 'intermediate',
  training_location text default 'commercialGym',
  training_days_per_week int default 4,
  preferred_session_length_minutes int default 45,
  preferred_split text default 'upperLower',
  protein_goal_grams numeric default 145,
  photo_tracking_enabled boolean default false,
  onboarding_complete boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- User preferences / sync settings
create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  photo_cloud_backup_enabled boolean default false,
  ai_insight_opt_in boolean default false,
  today_workout_json jsonb,
  updated_at timestamptz default now()
);

-- Global exercise catalog (seeded, read-only for clients)
create table if not exists public.exercises (
  id text primary key,
  name text not null,
  slug text not null unique,
  primary_muscles text[] not null default '{}',
  secondary_muscles text[] default '{}',
  equipment text[] default '{}',
  movement_pattern text,
  difficulty text,
  instructions jsonb default '[]',
  form_cues jsonb default '[]',
  common_mistakes jsonb default '[]',
  substitutions text[] default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.exercise_media (
  id uuid primary key default gen_random_uuid(),
  exercise_id text references public.exercises(id) on delete cascade,
  media_type text not null default 'video',
  angle text,
  url text not null,
  thumbnail_url text,
  duration_seconds int,
  license text,
  provider text,
  created_at timestamptz default now()
);

-- Workouts
create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  started_at timestamptz,
  completed_at timestamptz,
  estimated_duration_minutes int,
  perceived_difficulty int,
  notes text,
  status text not null default 'planned',
  today_workout_json jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  workout_session_id uuid not null references public.workout_sessions(id) on delete cascade,
  exercise_id text not null references public.exercises(id),
  order_index int not null default 0,
  rest_seconds int default 90,
  notes text,
  was_skipped boolean default false,
  skip_reason text,
  planned_sets jsonb default '[]',
  created_at timestamptz default now()
);

create table if not exists public.completed_sets (
  id uuid primary key default gen_random_uuid(),
  workout_exercise_id uuid not null references public.workout_exercises(id) on delete cascade,
  set_index int not null,
  weight_kg numeric,
  reps int not null,
  rpe numeric,
  is_warmup boolean default false,
  is_failure boolean default false,
  completed_at timestamptz default now()
);

create table if not exists public.muscle_recovery_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  muscle_group text not null,
  recovery_percentage numeric not null default 85,
  last_trained_at timestamptz,
  accumulated_fatigue numeric default 0,
  updated_at timestamptz default now(),
  unique (user_id, muscle_group)
);

create table if not exists public.protein_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null,
  meal_type text,
  food_name text not null,
  serving_description text,
  protein_grams numeric not null,
  calories numeric,
  carbs_grams numeric,
  fat_grams numeric,
  source text default 'manual',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.body_progress_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pose_type text not null,
  storage_path text,
  weight_kg numeric,
  notes text,
  analysis_json jsonb,
  captured_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.coach_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null,
  content text not null,
  intent text,
  created_at timestamptz default now()
);

-- Indexes
create index if not exists idx_workout_sessions_user_id on public.workout_sessions(user_id);
create index if not exists idx_protein_entries_user_date on public.protein_entries(user_id, entry_date);
create index if not exists idx_body_photos_user_id on public.body_progress_photos(user_id);

-- RLS
alter table public.profiles enable row level security;
alter table public.user_preferences enable row level security;
alter table public.exercises enable row level security;
alter table public.exercise_media enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.completed_sets enable row level security;
alter table public.muscle_recovery_states enable row level security;
alter table public.protein_entries enable row level security;
alter table public.body_progress_photos enable row level security;
alter table public.coach_messages enable row level security;

-- Profiles policies
create policy "profiles_select_own" on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy "profiles_update_own" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- User preferences policies
create policy "prefs_select_own" on public.user_preferences for select to authenticated using ((select auth.uid()) = user_id);
create policy "prefs_insert_own" on public.user_preferences for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "prefs_update_own" on public.user_preferences for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Exercises: read for authenticated users
create policy "exercises_read" on public.exercises for select to authenticated using (true);
create policy "exercise_media_read" on public.exercise_media for select to authenticated using (true);

-- Workout sessions
create policy "workouts_select_own" on public.workout_sessions for select to authenticated using ((select auth.uid()) = user_id);
create policy "workouts_insert_own" on public.workout_sessions for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "workouts_update_own" on public.workout_sessions for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "workouts_delete_own" on public.workout_sessions for delete to authenticated using ((select auth.uid()) = user_id);

-- Workout exercises (via session ownership)
create policy "workout_exercises_select" on public.workout_exercises for select to authenticated
  using (exists (select 1 from public.workout_sessions ws where ws.id = workout_session_id and ws.user_id = (select auth.uid())));
create policy "workout_exercises_insert" on public.workout_exercises for insert to authenticated
  with check (exists (select 1 from public.workout_sessions ws where ws.id = workout_session_id and ws.user_id = (select auth.uid())));
create policy "workout_exercises_update" on public.workout_exercises for update to authenticated
  using (exists (select 1 from public.workout_sessions ws where ws.id = workout_session_id and ws.user_id = (select auth.uid())))
  with check (exists (select 1 from public.workout_sessions ws where ws.id = workout_session_id and ws.user_id = (select auth.uid())));
create policy "workout_exercises_delete" on public.workout_exercises for delete to authenticated
  using (exists (select 1 from public.workout_sessions ws where ws.id = workout_session_id and ws.user_id = (select auth.uid())));

-- Completed sets (via exercise → session ownership)
create policy "completed_sets_select" on public.completed_sets for select to authenticated
  using (exists (
    select 1 from public.workout_exercises we
    join public.workout_sessions ws on ws.id = we.workout_session_id
    where we.id = workout_exercise_id and ws.user_id = (select auth.uid())
  ));
create policy "completed_sets_insert" on public.completed_sets for insert to authenticated
  with check (exists (
    select 1 from public.workout_exercises we
    join public.workout_sessions ws on ws.id = we.workout_session_id
    where we.id = workout_exercise_id and ws.user_id = (select auth.uid())
  ));
create policy "completed_sets_update" on public.completed_sets for update to authenticated
  using (exists (
    select 1 from public.workout_exercises we
    join public.workout_sessions ws on ws.id = we.workout_session_id
    where we.id = workout_exercise_id and ws.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.workout_exercises we
    join public.workout_sessions ws on ws.id = we.workout_session_id
    where we.id = workout_exercise_id and ws.user_id = (select auth.uid())
  ));
create policy "completed_sets_delete" on public.completed_sets for delete to authenticated
  using (exists (
    select 1 from public.workout_exercises we
    join public.workout_sessions ws on ws.id = we.workout_session_id
    where we.id = workout_exercise_id and ws.user_id = (select auth.uid())
  ));

-- Recovery states
create policy "recovery_select_own" on public.muscle_recovery_states for select to authenticated using ((select auth.uid()) = user_id);
create policy "recovery_insert_own" on public.muscle_recovery_states for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "recovery_update_own" on public.muscle_recovery_states for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "recovery_delete_own" on public.muscle_recovery_states for delete to authenticated using ((select auth.uid()) = user_id);

-- Protein entries
create policy "protein_select_own" on public.protein_entries for select to authenticated using ((select auth.uid()) = user_id);
create policy "protein_insert_own" on public.protein_entries for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "protein_update_own" on public.protein_entries for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "protein_delete_own" on public.protein_entries for delete to authenticated using ((select auth.uid()) = user_id);

-- Body photos (private — no public access)
create policy "photos_select_own" on public.body_progress_photos for select to authenticated using ((select auth.uid()) = user_id);
create policy "photos_insert_own" on public.body_progress_photos for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "photos_update_own" on public.body_progress_photos for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "photos_delete_own" on public.body_progress_photos for delete to authenticated using ((select auth.uid()) = user_id);

-- Coach messages
create policy "coach_select_own" on public.coach_messages for select to authenticated using ((select auth.uid()) = user_id);
create policy "coach_insert_own" on public.coach_messages for insert to authenticated with check ((select auth.uid()) = user_id);

-- Grants for Data API
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on public.exercises to anon;
grant select on public.exercise_media to anon;

-- Storage bucket for body progress photos (private)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('body-progress', 'body-progress', false, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "body_progress_storage_select" on storage.objects for select to authenticated
  using (bucket_id = 'body-progress' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "body_progress_storage_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'body-progress' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "body_progress_storage_update" on storage.objects for update to authenticated
  using (bucket_id = 'body-progress' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'body-progress' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "body_progress_storage_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'body-progress' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, goal, experience_level)
  values (new.id, 'buildMuscle', 'intermediate');
  insert into public.user_preferences (user_id)
  values (new.id);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

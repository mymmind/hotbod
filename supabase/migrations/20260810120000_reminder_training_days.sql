-- Reminder training days + local reminder preference (preferred days are not generation gates).
alter table public.profiles
  add column if not exists reminder_training_days integer[],
  add column if not exists workout_reminders_enabled boolean not null default true;

comment on column public.profiles.reminder_training_days is
  'Calendar weekday ints (1=Sun...7=Sat) used for workout reminders and Recovery framing.';
comment on column public.profiles.workout_reminders_enabled is
  'When true, clients may schedule local notifications on reminder_training_days.';
comment on column public.profiles.training_days_per_week is
  'Derived cache of reminder day count; clients treat reminder_training_days as source of truth.';

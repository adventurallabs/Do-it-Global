-- Crash reports from the app (lib/errors.dart): uncaught errors in release builds, so problems in the field
-- are visible. Signed-in users may only add rows for themselves; nobody can read them through the API
-- (read them in the dashboard / SQL editor). Rows older than 90 days are removed when new ones arrive.

create table if not exists public.client_errors (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  user_id uuid default auth.uid() references auth.users(id) on delete set null,
  platform text check (char_length(platform) <= 40),
  app_version text check (char_length(app_version) <= 40),
  message text not null check (char_length(message) <= 2000),
  stack text check (char_length(stack) <= 6000)
);
create index if not exists client_errors_created_idx on public.client_errors (created_at desc);
create index if not exists client_errors_user_idx on public.client_errors (user_id);

alter table public.client_errors enable row level security;
drop policy if exists client_errors_insert_own on public.client_errors;
create policy client_errors_insert_own on public.client_errors for insert to authenticated
  with check (user_id = (select auth.uid()));
revoke all on public.client_errors from anon;
grant insert on public.client_errors to authenticated;

create or replace function private.prune_client_errors() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.client_errors where created_at < now() - interval '90 days';
  return null;
end $$;
drop trigger if exists client_errors_prune on public.client_errors;
create trigger client_errors_prune after insert on public.client_errors for each statement execute function private.prune_client_errors();

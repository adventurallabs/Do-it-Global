-- Therapist and parent passwords are managed by the centre: only the admin can reset them (through the
-- accounts Edge Function), and the people themselves can no longer change them. Admins keep their own.

-- One-time permissions the Edge Function grants itself just before it sets a password. Not exposed
-- through the API; the function writes them through grant_password_change().
create table private.password_grants (
  user_id uuid primary key,
  expires_at timestamptz not null default now() + interval '2 minutes'
);

create or replace function public.grant_password_change(p_user uuid) returns void
language sql security definer set search_path = '' as $$
  insert into private.password_grants (user_id) values (p_user)
  on conflict (user_id) do update set expires_at = now() + interval '2 minutes'
$$;
revoke execute on function public.grant_password_change(uuid) from public, anon, authenticated;
grant execute on function public.grant_password_change(uuid) to service_role;

-- Blocks every password change on a therapist or parent login that doesn't come with a grant, including
-- a signed-in user calling the auth API (supabase.auth.updateUser) directly.
create or replace function private.guard_password_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.encrypted_password is not distinct from old.encrypted_password then return new; end if;
  if not exists (select 1 from public.profiles p where p.id = new.id and p.role in ('THERAPIST', 'PARENT')) then return new; end if;
  delete from private.password_grants where user_id = new.id and expires_at > now();
  if not found then
    raise exception 'Passwords are managed by the centre. Ask the admin to reset it.' using errcode = '42501';
  end if;
  return new;
end $$;

create trigger guard_password_change before update of encrypted_password on auth.users
  for each row execute function private.guard_password_change();

-- The "choose your own password on first sign-in" flow is gone.
drop function if exists public.password_changed();
alter table public.profiles drop column if exists must_change_password;

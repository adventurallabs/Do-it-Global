-- A therapist or parent signing in with the default password (new login, or after an admin reset) must
-- set their own before using the app. That one change is the only one they can make themselves: the
-- flag allows it and the change clears the flag. Any other change still needs the admin's reset.

alter table public.profiles add column must_change_password boolean not null default false;

-- Existing logins still on their default password (initial + date of birth) must choose their own.
update public.profiles p set must_change_password = true
from auth.users u, public.therapists t join public.therapist_details d on d.therapist_id = t.id
where p.role = 'THERAPIST' and u.id = p.id and t.profile_id = p.id and d.dob is not null
  and u.encrypted_password = extensions.crypt(upper(left(btrim(t.name), 1)) || to_char(d.dob, 'DDMMYYYY'), u.encrypted_password);

update public.profiles p set must_change_password = true
from auth.users u, public.children c
where p.role = 'PARENT' and u.id = p.id and c.id = p.child_id
  and u.encrypted_password = extensions.crypt(upper(left(btrim(c.name), 1)) || to_char(c.dob, 'DDMMYYYY'), u.encrypted_password);

create or replace function private.guard_password_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.encrypted_password is not distinct from old.encrypted_password then return new; end if;
  if not exists (select 1 from public.profiles p where p.id = new.id and p.role in ('THERAPIST', 'PARENT')) then return new; end if;
  -- The admin's reset (through the accounts Edge Function).
  delete from private.password_grants where user_id = new.id and expires_at > now();
  if found then return new; end if;
  -- The person replacing the default password with their own, once.
  update public.profiles set must_change_password = false where id = new.id and must_change_password;
  if found then return new; end if;
  raise exception 'Passwords are managed by the centre. Ask the admin to reset it.' using errcode = '42501';
end $$;

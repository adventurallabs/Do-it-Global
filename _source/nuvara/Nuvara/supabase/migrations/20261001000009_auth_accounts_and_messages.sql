-- Only emails on this list may create an admin account. No API policies: the accounts Edge
-- Function reads it with the service role; manage it from the Supabase dashboard.
create table public.admin_allowlist (
  email text primary key check (email = lower(btrim(email)) and email like '%@%'),
  added_at timestamptz not null default now()
);
alter table public.admin_allowlist enable row level security;
insert into public.admin_allowlist (email) values ('admin@newlife.test'), ('adventurallabs@gmail.com');

-- Logins: therapists sign in with their phone, parents with their child's ID. Accounts created with a
-- default password must set their own before using the app.
alter table public.profiles
  add column must_change_password boolean not null default false,
  add column child_id uuid unique references public.children(id) on delete cascade;

create or replace function public.password_changed() returns void language sql security definer set search_path = '' as
$$ update public.profiles set must_change_password = false where id = (select auth.uid()) $$;
revoke execute on function public.password_changed() from public, anon;
grant execute on function public.password_changed() to authenticated;

-- Messages between the centre (admins) and a child's family. Therapists have no access.
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete set null,
  from_admin boolean not null,
  body text not null check (length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index messages_thread_idx on public.messages (child_id, created_at desc);

alter table public.messages enable row level security;
create policy "Read" on public.messages for select to authenticated
  using ((select private.is_admin()) or private.is_my_child(child_id));
create policy "Send" on public.messages for insert to authenticated with check (
  sender_id = (select auth.uid()) and read_at is null and (
    ((select private.is_admin()) and from_admin)
    or (private.is_my_child(child_id) and not from_admin)
  )
);
create policy "Admin delete" on public.messages for delete to authenticated using ((select private.is_admin()));

create or replace function public.mark_thread_read(p_child uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_admin boolean := private.is_admin();
begin
  if not (v_admin or private.is_my_child(p_child)) then raise exception 'Not your conversation.'; end if;
  update public.messages set read_at = now()
  where child_id = p_child and read_at is null and from_admin = not v_admin;
end $$;
revoke execute on function public.mark_thread_read(uuid) from public, anon;
grant execute on function public.mark_thread_read(uuid) to authenticated;

alter publication supabase_realtime add table public.messages;

-- Redesign: remove the previous schema entirely, then recreate the login profiles table.
do $$
declare r record;
begin
  for r in select tablename from pg_tables where schemaname = 'public' loop
    execute format('drop table if exists public.%I cascade', r.tablename);
  end loop;
  for r in select p.oid::regprocedure as f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private') and p.prokind = 'f'
             and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e') loop
    execute format('drop function if exists %s cascade', r.f);
  end loop;
end $$;

create schema if not exists private;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('ADMIN', 'THERAPIST', 'PARENT')),
  full_name text not null,
  email text,
  phone text,
  created_at timestamptz not null default now()
);
insert into public.profiles (id, role, full_name, email)
select u.id, v.role, v.name, u.email
from (values ('admin@newlife.test', 'ADMIN', 'Lakshmi Narayanan'), ('priya@newlife.test', 'THERAPIST', 'Priya Raman'),
             ('neha@newlife.test', 'PARENT', 'Neha Sharma')) v(email, role, name)
join auth.users u on u.email = v.email;

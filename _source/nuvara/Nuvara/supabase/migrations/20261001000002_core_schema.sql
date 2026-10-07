
create extension if not exists btree_gist with schema extensions;

-- ---------------------------------------------------------------- helpers
create or replace function private.today() returns date language sql stable set search_path = '' as
$$ select (now() at time zone 'Asia/Kolkata')::date $$;

create or replace function private.digits10(p text) returns text language sql immutable set search_path = '' as
$$ select right(regexp_replace(coalesce(p, ''), '\D', '', 'g'), 10) $$;

-- ---------------------------------------------------------------- therapies
create table public.therapies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 80),
  base_fee numeric(10,2) not null default 0 check (base_fee >= 0),
  created_at timestamptz not null default now()
);
create unique index therapies_name_key on public.therapies (lower(btrim(name)));

-- ---------------------------------------------------------------- therapists
create table public.therapists (
  id uuid primary key default gen_random_uuid(),
  therapist_no integer generated always as identity unique,
  profile_id uuid unique references public.profiles(id) on delete set null,
  name text not null check (length(btrim(name)) between 1 and 80),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
-- Personal and pay details: admin (and the therapist themself) only.
create table public.therapist_details (
  therapist_id uuid primary key references public.therapists(id) on delete cascade,
  dob date,
  phone text not null default '',
  emergency_phone text not null default '',
  salary numeric(12,2) not null default 0 check (salary >= 0)
);
create table public.therapist_therapies (
  therapist_id uuid not null references public.therapists(id) on delete cascade,
  therapy_id uuid not null references public.therapies(id) on delete restrict,
  primary key (therapist_id, therapy_id)
);

-- ---------------------------------------------------------------- children
create table public.children (
  id uuid primary key default gen_random_uuid(),
  child_no integer generated always as identity unique,
  name text not null check (length(btrim(name)) between 1 and 80),
  dob date not null,
  father_name text not null default '',
  mother_name text not null default '',
  phone text not null check (length(private.digits10(phone)) = 10),
  alt_phone text not null default '',
  -- null = monthly fee follows the sum of therapy base fees; set = custom fee for this child only.
  fee_override numeric(10,2) check (fee_override >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.child_therapies (
  child_id uuid not null references public.children(id) on delete cascade,
  therapy_id uuid not null references public.therapies(id) on delete restrict,
  level integer not null default 0 check (level between 0 and 100),
  created_at timestamptz not null default now(),
  primary key (child_id, therapy_id)
);
create index child_therapies_therapy_idx on public.child_therapies (therapy_id);

-- ---------------------------------------------------------------- timetable
create table public.timetable_slots (
  id uuid primary key default gen_random_uuid(),
  slot_date date not null,
  start_time time not null,
  end_time time not null,
  created_at timestamptz not null default now(),
  check (end_time > start_time),
  unique (slot_date, start_time, end_time)
);

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  slot_id uuid not null references public.timetable_slots(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 80),
  therapist_id uuid not null references public.therapists(id) on delete restrict,
  during tsrange not null,
  created_at timestamptz not null default now(),
  -- A therapist can never be in two sessions that overlap in time.
  constraint therapist_double_booked exclude using gist (therapist_id with =, during with &&)
);
create index sessions_slot_idx on public.sessions (slot_id);

create table public.session_children (
  session_id uuid not null references public.sessions(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  during tsrange not null,
  primary key (session_id, child_id),
  -- A child can never be in two sessions that overlap in time.
  constraint child_double_booked exclude using gist (child_id with =, during with &&)
);
create index session_children_child_idx on public.session_children (child_id);

-- `during` is always derived from the slot, never trusted from the client.
create or replace function private.session_during() returns trigger language plpgsql set search_path = '' as $$
begin
  select tsrange(s.slot_date + s.start_time, s.slot_date + s.end_time, '[)') into new.during
  from public.timetable_slots s where s.id = new.slot_id;
  return new;
end $$;
create trigger session_during before insert or update of slot_id on public.sessions
  for each row execute function private.session_during();

create or replace function private.seat_during() returns trigger language plpgsql set search_path = '' as $$
begin
  select s.during into new.during from public.sessions s where s.id = new.session_id;
  return new;
end $$;
create trigger seat_during before insert or update of session_id on public.session_children
  for each row execute function private.seat_during();

create or replace function private.slot_times_locked() returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'A time slot''s date and time cannot be changed. Delete it and create a new one.';
end $$;
create trigger slot_times_locked before update of slot_date, start_time, end_time on public.timetable_slots
  for each row execute function private.slot_times_locked();

-- ---------------------------------------------------------------- fees
create table public.fee_charges (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  period text not null check (period ~ '^\d{4}-(0[1-9]|1[0-2])$'),
  base_fee numeric(10,2) not null check (base_fee >= 0),
  amount numeric(10,2) not null check (amount >= 0),
  updated_at timestamptz not null default now(),
  unique (child_id, period)
);
create table public.fee_payments (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null,
  period text not null,
  amount numeric(10,2) not null check (amount > 0),
  paid_on date not null default private.today(),
  method text not null default 'Cash',
  note text not null default '',
  created_at timestamptz not null default now(),
  foreign key (child_id, period) references public.fee_charges(child_id, period) on delete cascade
);
create index fee_payments_child_idx on public.fee_payments (child_id, period);

-- Current month's charge mirrors the child's plan; earlier months stay frozen as billed.
create or replace function private.sync_fee(p_child uuid) returns void language plpgsql security definer set search_path = '' as $$
declare v_base numeric; v_amount numeric; v_active boolean;
begin
  select coalesce(sum(t.base_fee), 0), bool_and(c.active), max(c.fee_override)
    into v_base, v_active, v_amount
  from public.children c
  left join public.child_therapies ct on ct.child_id = c.id
  left join public.therapies t on t.id = ct.therapy_id
  where c.id = p_child;
  if v_active is not true then return; end if;
  insert into public.fee_charges (child_id, period, base_fee, amount)
  values (p_child, to_char(private.today(), 'YYYY-MM'), v_base, coalesce(v_amount, v_base))
  on conflict (child_id, period) do update
    set base_fee = excluded.base_fee, amount = excluded.amount, updated_at = now()
    where (fee_charges.base_fee, fee_charges.amount) is distinct from (excluded.base_fee, excluded.amount);
end $$;

create or replace function private.on_child_fee() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform private.sync_fee(coalesce(new.id, old.id));
  return null;
end $$;
create trigger child_fee after insert or update of fee_override, active on public.children
  for each row execute function private.on_child_fee();

create or replace function private.on_child_therapy_fee() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    if exists (select 1 from public.children where id = old.child_id) then perform private.sync_fee(old.child_id); end if;
  else
    perform private.sync_fee(new.child_id);
  end if;
  return null;
end $$;
create trigger child_therapy_fee after insert or delete on public.child_therapies
  for each row execute function private.on_child_therapy_fee();

create or replace function private.on_therapy_fee() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform private.sync_fee(ct.child_id) from public.child_therapies ct where ct.therapy_id = new.id;
  return null;
end $$;
create trigger therapy_fee after update of base_fee on public.therapies
  for each row execute function private.on_therapy_fee();

-- ---------------------------------------------------------------- access helpers
create or replace function private.is_admin() returns boolean language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'ADMIN') $$;

create or replace function private.my_therapist_id() returns uuid language sql stable security definer set search_path = '' as
$$ select t.id from public.therapists t where t.profile_id = (select auth.uid()) $$;

-- Parents are linked to children by the contact numbers the centre recorded.
create or replace function private.is_my_child(p_child uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.children c join public.profiles p on p.id = (select auth.uid())
    where c.id = p_child and p.role = 'PARENT' and length(private.digits10(p.phone)) = 10
      and private.digits10(p.phone) in (private.digits10(c.phone), private.digits10(c.alt_phone))
  )
$$;

create or replace function private.therapist_has_child(p_child uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.session_children sc join public.sessions s on s.id = sc.session_id
    where sc.child_id = p_child and s.therapist_id = (select private.my_therapist_id())
  )
$$;

create or replace function private.is_my_session(p_session uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.sessions s where s.id = p_session and s.therapist_id = (select private.my_therapist_id()))
$$;

-- ---------------------------------------------------------------- RLS
do $$
declare t text;
begin
  foreach t in array array['profiles','therapies','therapists','therapist_details','therapist_therapies','children','child_therapies',
    'timetable_slots','sessions','session_children','fee_charges','fee_payments']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "Admins manage everything" on public.%I for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()))', t);
  end loop;
end $$;

create policy "Own profile" on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "Signed-in users read therapies" on public.therapies for select to authenticated using (true);
create policy "Signed-in users read therapists" on public.therapists for select to authenticated using (true);
create policy "Signed-in users read specialisations" on public.therapist_therapies for select to authenticated using (true);
create policy "Therapists read own details" on public.therapist_details for select to authenticated
  using (therapist_id = (select private.my_therapist_id()));
create policy "Signed-in users read timetable" on public.timetable_slots for select to authenticated using (true);
create policy "Signed-in users read sessions" on public.sessions for select to authenticated using (true);
create policy "Therapists and families read seats" on public.session_children for select to authenticated
  using (private.is_my_session(session_id) or private.is_my_child(child_id));
create policy "Therapists and families read children" on public.children for select to authenticated
  using (private.is_my_child(id) or private.therapist_has_child(id));
create policy "Therapists and families read child therapies" on public.child_therapies for select to authenticated
  using (private.is_my_child(child_id) or private.therapist_has_child(child_id));
create policy "Families read own charges" on public.fee_charges for select to authenticated using (private.is_my_child(child_id));
create policy "Families read own payments" on public.fee_payments for select to authenticated using (private.is_my_child(child_id));

-- ---------------------------------------------------------------- RPCs (admin only, atomic)
create or replace function private.require_admin() returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_admin() then raise exception 'Only the centre admin can do this.'; end if;
end $$;

create or replace function public.save_child(
  p_id uuid, p_name text, p_dob date, p_father text, p_mother text, p_phone text, p_alt_phone text,
  p_fee_override numeric, p_therapies jsonb
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := p_id;
begin
  perform private.require_admin();
  if length(btrim(coalesce(p_name, ''))) = 0 then raise exception 'Enter the child''s name.'; end if;
  if p_dob is null or p_dob > private.today() then raise exception 'Enter a valid date of birth.'; end if;
  if length(private.digits10(p_phone)) <> 10 then raise exception 'Enter a valid 10-digit contact number.'; end if;
  if jsonb_array_length(coalesce(p_therapies, '[]')) = 0 then raise exception 'Select at least one therapy.'; end if;
  if v_id is null then
    insert into public.children (name, dob, father_name, mother_name, phone, alt_phone, fee_override)
    values (btrim(p_name), p_dob, btrim(coalesce(p_father, '')), btrim(coalesce(p_mother, '')), btrim(p_phone), btrim(coalesce(p_alt_phone, '')), p_fee_override)
    returning id into v_id;
  else
    update public.children set name = btrim(p_name), dob = p_dob, father_name = btrim(coalesce(p_father, '')),
      mother_name = btrim(coalesce(p_mother, '')), phone = btrim(p_phone), alt_phone = btrim(coalesce(p_alt_phone, '')),
      fee_override = p_fee_override
    where id = v_id;
    if not found then raise exception 'Child not found.'; end if;
    delete from public.child_therapies ct where ct.child_id = v_id
      and ct.therapy_id not in (select (x->>'therapy_id')::uuid from jsonb_array_elements(p_therapies) x);
  end if;
  insert into public.child_therapies (child_id, therapy_id, level)
  select v_id, (x->>'therapy_id')::uuid, least(100, greatest(0, coalesce((x->>'level')::int, 0)))
  from jsonb_array_elements(p_therapies) x
  on conflict (child_id, therapy_id) do update set level = excluded.level;
  -- Fee row reflects the final plan exactly once everything above is in place.
  perform private.sync_fee(v_id);
  return v_id;
end $$;

create or replace function public.save_therapist(
  p_id uuid, p_name text, p_dob date, p_phone text, p_emergency text, p_salary numeric, p_therapies uuid[]
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := p_id;
begin
  perform private.require_admin();
  if length(btrim(coalesce(p_name, ''))) = 0 then raise exception 'Enter the therapist''s name.'; end if;
  if length(private.digits10(p_phone)) <> 10 then raise exception 'Enter a valid 10-digit contact number.'; end if;
  if coalesce(p_salary, 0) < 0 then raise exception 'Salary cannot be negative.'; end if;
  if v_id is null then
    insert into public.therapists (name) values (btrim(p_name)) returning id into v_id;
  else
    update public.therapists set name = btrim(p_name) where id = v_id;
    if not found then raise exception 'Therapist not found.'; end if;
  end if;
  insert into public.therapist_details (therapist_id, dob, phone, emergency_phone, salary)
  values (v_id, p_dob, btrim(p_phone), btrim(coalesce(p_emergency, '')), coalesce(p_salary, 0))
  on conflict (therapist_id) do update set dob = excluded.dob, phone = excluded.phone,
    emergency_phone = excluded.emergency_phone, salary = excluded.salary;
  delete from public.therapist_therapies where therapist_id = v_id and therapy_id <> all (coalesce(p_therapies, '{}'));
  insert into public.therapist_therapies (therapist_id, therapy_id)
  select v_id, x from unnest(coalesce(p_therapies, '{}')) x on conflict do nothing;
  return v_id;
end $$;

create or replace function public.create_slots(p_dates date[], p_start time, p_end time) returns integer
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  perform private.require_admin();
  if p_end <= p_start then raise exception 'End time must be after start time.'; end if;
  insert into public.timetable_slots (slot_date, start_time, end_time)
  select distinct d, p_start, p_end from unnest(p_dates) d on conflict do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

-- Turns exclusion-constraint failures into a sentence naming who is busy and when.
create or replace function private.clash_message(p_therapist uuid, p_children uuid[], p_during tsrange, p_except uuid default null) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select t.name || ' is already in "' || s.name || '" (' || to_char(lower(s.during), 'Dy DD Mon, HH12:MI') || '–' || to_char(upper(s.during), 'HH12:MI AM') || ').'
       from public.sessions s join public.therapists t on t.id = s.therapist_id
       where s.therapist_id = p_therapist and s.during && p_during and s.id is distinct from p_except limit 1),
    (select c.name || ' is already in "' || s.name || '" (' || to_char(lower(s.during), 'Dy DD Mon, HH12:MI') || '–' || to_char(upper(s.during), 'HH12:MI AM') || ').'
       from public.session_children sc join public.sessions s on s.id = sc.session_id join public.children c on c.id = sc.child_id
       where sc.child_id = any (p_children) and sc.during && p_during and sc.session_id is distinct from p_except limit 1),
    'Someone in this session is already booked at this time.')
$$;

create or replace function public.create_sessions(
  p_dates date[], p_start time, p_end time, p_name text, p_therapist uuid, p_children uuid[]
) returns integer language plpgsql security definer set search_path = '' as $$
declare d date; v_slot uuid; v_session uuid; n int := 0;
begin
  perform private.require_admin();
  if length(btrim(coalesce(p_name, ''))) = 0 then raise exception 'Enter a session name.'; end if;
  if coalesce(cardinality(p_children), 0) = 0 then raise exception 'Select at least one child.'; end if;
  if not exists (select 1 from public.therapists where id = p_therapist and active) then raise exception 'Select an active therapist.'; end if;
  if exists (select 1 from unnest(p_children) x where not exists (select 1 from public.children c where c.id = x and c.active)) then
    raise exception 'One of the selected children is no longer active.';
  end if;
  foreach d in array p_dates loop
    insert into public.timetable_slots (slot_date, start_time, end_time) values (d, p_start, p_end) on conflict do nothing;
    select id into v_slot from public.timetable_slots where slot_date = d and start_time = p_start and end_time = p_end;
    begin
      insert into public.sessions (slot_id, name, therapist_id) values (v_slot, btrim(p_name), p_therapist) returning id into v_session;
      insert into public.session_children (session_id, child_id) select v_session, x from unnest(p_children) x;
    exception when exclusion_violation then
      raise exception '%', private.clash_message(p_therapist, p_children, tsrange(d + p_start, d + p_end, '[)'));
    end;
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.update_session(p_session uuid, p_name text, p_therapist uuid, p_children uuid[]) returns void
language plpgsql security definer set search_path = '' as $$
declare v_during tsrange;
begin
  perform private.require_admin();
  if length(btrim(coalesce(p_name, ''))) = 0 then raise exception 'Enter a session name.'; end if;
  if coalesce(cardinality(p_children), 0) = 0 then raise exception 'Select at least one child.'; end if;
  select during into v_during from public.sessions where id = p_session for update;
  if not found then raise exception 'This session no longer exists.'; end if;
  begin
    update public.sessions set name = btrim(p_name), therapist_id = p_therapist where id = p_session;
    delete from public.session_children where session_id = p_session and child_id <> all (p_children);
    insert into public.session_children (session_id, child_id) select p_session, x from unnest(p_children) x on conflict do nothing;
  exception when exclusion_violation then
    raise exception '%', private.clash_message(p_therapist, p_children, v_during, p_session);
  end;
end $$;

-- Copies a whole week's slots and sessions into an empty week.
create or replace function public.copy_week(p_from date, p_to date) returns integer
language plpgsql security definer set search_path = '' as $$
declare off int := p_to - p_from; r record; v_slot uuid; v_session uuid; n int := 0;
begin
  perform private.require_admin();
  if extract(isodow from p_from) <> 1 or extract(isodow from p_to) <> 1 then raise exception 'Weeks start on Monday.'; end if;
  if exists (select 1 from public.timetable_slots where slot_date between p_to and p_to + 6) then
    raise exception 'The target week already has time slots.';
  end if;
  insert into public.timetable_slots (slot_date, start_time, end_time)
  select slot_date + off, start_time, end_time from public.timetable_slots where slot_date between p_from and p_from + 6;
  for r in
    select s.*, ts.slot_date, ts.start_time, ts.end_time from public.sessions s
    join public.timetable_slots ts on ts.id = s.slot_id
    join public.therapists t on t.id = s.therapist_id and t.active
    where ts.slot_date between p_from and p_from + 6
  loop
    select id into v_slot from public.timetable_slots
      where slot_date = r.slot_date + off and start_time = r.start_time and end_time = r.end_time;
    insert into public.sessions (slot_id, name, therapist_id) values (v_slot, r.name, r.therapist_id) returning id into v_session;
    insert into public.session_children (session_id, child_id)
    select v_session, sc.child_id from public.session_children sc join public.children c on c.id = sc.child_id and c.active
    where sc.session_id = r.id;
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.ensure_fee_charges() returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.sync_fee(c.id) from public.children c
  where c.active and not exists (select 1 from public.fee_charges f where f.child_id = c.id and f.period = to_char(private.today(), 'YYYY-MM'));
end $$;

create or replace function public.record_payment(p_child uuid, p_period text, p_amount numeric, p_method text, p_note text, p_paid_on date)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_amount numeric; v_paid numeric; v_id uuid;
begin
  perform private.require_admin();
  if coalesce(p_amount, 0) <= 0 then raise exception 'Enter an amount greater than zero.'; end if;
  select amount into v_amount from public.fee_charges where child_id = p_child and period = p_period for update;
  if not found then raise exception 'No fee has been billed for this month.'; end if;
  select coalesce(sum(amount), 0) into v_paid from public.fee_payments where child_id = p_child and period = p_period;
  if p_amount > v_amount - v_paid then
    raise exception 'Only ₹% is remaining for this month.', to_char(greatest(v_amount - v_paid, 0), 'FM999G999G990');
  end if;
  insert into public.fee_payments (child_id, period, amount, method, note, paid_on)
  values (p_child, p_period, p_amount, coalesce(nullif(btrim(p_method), ''), 'Cash'), btrim(coalesce(p_note, '')), coalesce(p_paid_on, private.today()))
  returning id into v_id;
  return v_id;
end $$;

revoke execute on all functions in schema private from public, anon;
grant usage on schema private to authenticated;
-- RLS policies call these as the signed-in user.
grant execute on function private.is_admin(), private.my_therapist_id(), private.is_my_child(uuid),
  private.therapist_has_child(uuid), private.is_my_session(uuid), private.digits10(text), private.today() to authenticated;
revoke execute on function public.save_child, public.save_therapist, public.create_slots, public.create_sessions,
  public.update_session, public.copy_week, public.ensure_fee_charges, public.record_payment from public, anon;

-- ---------------------------------------------------------------- realtime
alter publication supabase_realtime add table public.therapies, public.therapists, public.therapist_therapies,
  public.children, public.child_therapies, public.timetable_slots, public.sessions, public.session_children,
  public.fee_charges, public.fee_payments;

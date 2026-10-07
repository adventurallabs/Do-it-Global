-- Weekly fees from attended sessions, UPI payments, per-session progress ratings and reschedule requests.
--
-- * A session now belongs to one therapy. Each child pays a per-session rate for that therapy: the
--   therapy's base fee, or a rate the admin set for this child only (child_therapies.session_fee).
-- * Attendance snapshots the rate onto the seat (session_children.rate) when a child is marked present
--   or late, so later price changes never rewrite a past week. A week's bill = sum of those rates.
-- * Attendance can be changed from 15 minutes before the start until the session ends. After the end a
--   therapist can still mark a child who was never marked (once), but not change a mark. Nothing in a
--   week can change once a payment for that week is verifying or confirmed.
-- * Parents pay a finished week through UPI. Every attempt is a row with a one-time reference, the amount
--   fixed by the server and the payee UPI ID copied from the active account at that moment, so the admin
--   switching UPI IDs mid-payment can't redirect or break it.
-- * Progress is a 0–10 rating plus a description per child per session, given only by that session's
--   therapist. The old 0–100 levels and the monthly fee tables are removed.

-- ============================================================ 1. remove monthly fees and 0–100 levels
drop function if exists public.ensure_fee_charges() cascade;
drop function if exists public.record_payment(uuid, text, numeric, text, text, date) cascade;
drop function if exists private.sync_fee(uuid) cascade;
drop function if exists private.on_child_fee() cascade;
drop function if exists private.on_child_therapy_fee() cascade;
drop function if exists private.on_therapy_fee() cascade;
alter publication supabase_realtime drop table public.fee_payments, public.fee_charges, public.child_level_history;
drop table public.fee_payments;
drop table public.fee_charges;

drop function if exists public.set_level(uuid, uuid, int) cascade;
drop function if exists private.log_level() cascade;
drop table public.child_level_history;
alter table public.child_therapies drop column level;

drop function if exists public.save_child(uuid, text, date, text, text, text, text, numeric, jsonb);
alter table public.children drop column fee_override;

-- null = the therapy's base fee; set = this child's own per-session rate.
alter table public.child_therapies add column session_fee numeric(10,2) check (session_fee >= 0);

comment on column public.therapies.base_fee is 'Standard fee per attended session.';

-- ============================================================ 2. helpers
create or replace function private.now_ist() returns timestamp language sql stable set search_path = '' as
$$ select (now() at time zone 'Asia/Kolkata')::timestamp $$;

-- The per-session rate a child pays for a therapy right now.
create or replace function private.rate_of(p_child uuid, p_therapy uuid) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select ct.session_fee from public.child_therapies ct where ct.child_id = p_child and ct.therapy_id = p_therapy),
    (select t.base_fee from public.therapies t where t.id = p_therapy),
    0)
$$;

-- One lock per child and week: payments and attendance changes for the same week never interleave.
create or replace function private.lock_week(p_child uuid, p_day date) returns void language sql set search_path = '' as
$$ select pg_advisory_xact_lock(hashtextextended(p_child::text || '|' || date_trunc('week', p_day)::date::text, 0)) $$;

-- ============================================================ 3. sessions carry their therapy
alter table public.sessions add column therapy_id uuid references public.therapies(id) on delete restrict;
update public.sessions s set therapy_id = coalesce(
  (select tt.therapy_id from public.therapist_therapies tt
     join public.child_therapies ct on ct.therapy_id = tt.therapy_id
     join public.session_children sc on sc.child_id = ct.child_id and sc.session_id = s.id
   where tt.therapist_id = s.therapist_id limit 1),
  (select tt.therapy_id from public.therapist_therapies tt where tt.therapist_id = s.therapist_id limit 1),
  (select ct.therapy_id from public.session_children sc join public.child_therapies ct on ct.child_id = sc.child_id where sc.session_id = s.id limit 1),
  (select t.id from public.therapies t order by t.created_at limit 1));
alter table public.sessions alter column therapy_id set not null;
create index sessions_therapy_idx on public.sessions (therapy_id);

alter table public.session_children
  add column rate numeric(10,2) check (rate >= 0),
  add column marked_by uuid references public.profiles(id) on delete set null,
  add column rating smallint check (rating between 0 and 10),
  add column rated_at timestamptz;

update public.session_children sc set rate = private.rate_of(sc.child_id, s.therapy_id)
from public.sessions s where s.id = sc.session_id and sc.attendance in ('present', 'late');

-- ============================================================ 4. UPI accounts
create table public.upi_accounts (
  id uuid primary key default gen_random_uuid(),
  vpa text not null check (vpa ~ '^[A-Za-z0-9._-]{2,255}@[A-Za-z][A-Za-z0-9.-]{1,63}$'),
  payee_name text not null check (length(btrim(payee_name)) between 1 and 60),
  label text not null default '' check (length(label) <= 60),
  active boolean not null default false,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  check (not (active and archived))
);
create unique index upi_accounts_vpa_key on public.upi_accounts (lower(vpa));
-- At most one active UPI ID, enforced by the database.
create unique index upi_accounts_one_active on public.upi_accounts ((true)) where active;

-- ============================================================ 5. payments
create sequence public.receipt_no_seq;

create table public.fee_payments (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  week_start date not null check (extract(isodow from week_start) = 1),
  amount numeric(10,2) not null check (amount > 0),
  method text not null check (method in ('UPI', 'Cash', 'Bank transfer', 'Card', 'Cheque')),
  -- initiated: UPI app opened, outcome unknown · verifying: waiting for the admin · confirmed: counts as paid
  -- failed / cancelled: never counted · reversed: was confirmed, later found invalid by the admin
  status text not null check (status in ('initiated', 'verifying', 'confirmed', 'failed', 'cancelled', 'reversed')),
  -- Our one-time reference, sent to the UPI app as `tr` and in the note.
  txn_ref text not null unique,
  upi_account_id uuid references public.upi_accounts(id) on delete restrict,
  payee_vpa text,
  payee_name text,
  -- The bank's UPI reference (UTR / RRN), when known.
  utr text check (utr ~ '^[A-Za-z0-9]{6,35}$'),
  upi_app text check (length(upi_app) <= 120),
  upi_response text check (length(upi_response) <= 2000),
  verified_by text check (verified_by in ('upi_app', 'admin')),
  note text not null default '' check (length(note) <= 300),
  paid_on date,
  receipt_no bigint unique,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null,
  check ((status = 'confirmed') = (receipt_no is not null) or status = 'reversed')
);
create index fee_payments_child_week_idx on public.fee_payments (child_id, week_start);
-- A bank reference can pay for one thing only.
create unique index fee_payments_utr_key on public.fee_payments (upper(utr)) where utr is not null and status in ('verifying', 'confirmed');
-- One unfinished UPI attempt per child and week.
create unique index fee_payments_one_open on public.fee_payments (child_id, week_start) where status = 'initiated';

-- A UPI ID that has received payments keeps its address (payments point at it); change the label or archive it instead.
create or replace function private.upi_vpa_locked() returns trigger language plpgsql set search_path = '' as $$
begin
  if lower(new.vpa) <> lower(old.vpa) and exists (select 1 from public.fee_payments p where p.upi_account_id = old.id) then
    raise exception 'This UPI ID has payments, so its address can''t change. Add a new UPI ID instead.';
  end if;
  return new;
end $$;
create trigger upi_vpa_locked before update of vpa on public.upi_accounts for each row execute function private.upi_vpa_locked();

create or replace function private.week_paid(p_child uuid, p_day date) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.fee_payments p
    where p.child_id = p_child and p.week_start = date_trunc('week', p_day)::date and p.status in ('verifying', 'confirmed'))
$$;

-- A week's money for one child: attended total, seats still open, and what is paid or being verified.
create or replace function private.week_bill(p_child uuid, p_week date, out amount numeric, out open_seats int, out paid numeric, out verifying numeric)
language sql stable security definer set search_path = '' as $$
  select
    coalesce((select sum(sc.rate) from public.session_children sc join public.sessions s on s.id = sc.session_id
      join public.timetable_slots ts on ts.id = s.slot_id
      where sc.child_id = p_child and date_trunc('week', ts.slot_date)::date = p_week and sc.attendance in ('present', 'late')), 0),
    (select count(*)::int from public.session_children sc join public.sessions s on s.id = sc.session_id
      join public.timetable_slots ts on ts.id = s.slot_id
      where sc.child_id = p_child and date_trunc('week', ts.slot_date)::date = p_week and sc.attendance is null),
    coalesce((select sum(p.amount) from public.fee_payments p where p.child_id = p_child and p.week_start = p_week and p.status = 'confirmed'), 0),
    coalesce((select sum(p.amount) from public.fee_payments p where p.child_id = p_child and p.week_start = p_week and p.status = 'verifying'), 0)
$$;

-- ============================================================ 6. attendance with locks and rate snapshots
create or replace function public.mark_attendance(p_session uuid, p_children uuid[], p_status text) returns void
language plpgsql security definer set search_path = '' as $$
declare v record; v_now timestamp := private.now_ist(); c uuid;
begin
  if not private.can_run_session(p_session) then raise exception 'Only this session''s therapist or the admin can mark attendance.'; end if;
  if p_status is not null and p_status not in ('present', 'late', 'absent') then raise exception 'Unknown attendance status.'; end if;
  select s.during, s.therapy_id, ts.slot_date into v from public.sessions s join public.timetable_slots ts on ts.id = s.slot_id where s.id = p_session;
  if not found then raise exception 'This session no longer exists.'; end if;
  if lower(v.during) - interval '15 minutes' > v_now then raise exception 'Attendance opens 15 minutes before the session starts.'; end if;
  foreach c in array coalesce(p_children, '{}') loop
    perform private.lock_week(c, v.slot_date);
    if private.week_paid(c, v.slot_date) then
      raise exception 'This week''s fee has already been paid, so its attendance can no longer change.';
    end if;
  end loop;
  -- After the session: an unmarked child can still be marked once; marks already given are final.
  if upper(v.during) <= v_now and not private.is_admin() then
    if p_status is null then raise exception 'This session is over, so attendance can no longer be cleared.'; end if;
    if exists (select 1 from public.session_children where session_id = p_session and child_id = any (p_children) and attendance is not null) then
      raise exception 'This session is over, so attendance that was already marked is locked.';
    end if;
  end if;
  update public.session_children sc set
    attendance = p_status,
    marked_at = case when p_status is null then null else now() end,
    marked_by = case when p_status is null then null else (select auth.uid()) end,
    rate = case when p_status in ('present', 'late') then private.rate_of(sc.child_id, v.therapy_id) end,
    rating = case when p_status in ('present', 'late') then sc.rating end,
    rated_at = case when p_status in ('present', 'late') then sc.rated_at end
  where sc.session_id = p_session and sc.child_id = any (p_children);
  if not found then raise exception 'These children are not in this session.'; end if;
end $$;

-- Removing a child's attended seat (directly, or by deleting its session or slot) would change a paid bill.
create or replace function private.guard_paid_seat() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.attendance is not null and exists (select 1 from public.children c where c.id = old.child_id)
     and private.week_paid(old.child_id, lower(old.during)::date) then
    raise exception '%''s fee for that week is already paid, so this session can no longer be removed.',
      (select c.name from public.children c where c.id = old.child_id);
  end if;
  return old;
end $$;
create trigger seat_paid_guard before delete on public.session_children for each row execute function private.guard_paid_seat();

-- ============================================================ 7. notes and ratings (the session's therapist only)
create or replace function public.save_session_note(p_session uuid, p_child uuid, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_my_session(p_session) then raise exception 'Only this session''s therapist can write its notes.'; end if;
  update public.session_children set note = btrim(coalesce(p_note, '')) where session_id = p_session and child_id = p_child;
  if not found then raise exception 'This child is not in the session.'; end if;
end $$;

create or replace function public.rate_session(p_session uuid, p_child uuid, p_rating int, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare v record; v_now timestamp := private.now_ist();
begin
  if not private.is_my_session(p_session) then raise exception 'Only this session''s therapist can rate it.'; end if;
  if p_rating is not null and (p_rating < 0 or p_rating > 10) then raise exception 'Ratings go from 0 to 10.'; end if;
  select s.during, sc.attendance into v from public.sessions s
    join public.session_children sc on sc.session_id = s.id and sc.child_id = p_child where s.id = p_session;
  if not found then raise exception 'This child is not in this session.'; end if;
  if lower(v.during) > v_now then raise exception 'You can rate a session once it has started.'; end if;
  if upper(v.during) + interval '24 hours' < v_now then raise exception 'Ratings can be given until 24 hours after the session ends.'; end if;
  if p_rating is not null and coalesce(v.attendance, '') not in ('present', 'late') then
    raise exception 'Mark the child present or late before rating the session.';
  end if;
  update public.session_children set
    rating = p_rating,
    rated_at = case when p_rating is null then null else now() end,
    note = case when p_note is null then note else btrim(p_note) end
  where session_id = p_session and child_id = p_child;
end $$;

-- Every rated or noted session of a child, oldest first, for the progress charts.
create or replace function public.progress_points(p_child uuid)
returns table (session_id uuid, day date, start_time time, end_time time, session_name text, therapy_id uuid, therapist_id uuid,
  attendance text, rating smallint, note text, rated_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if not (private.is_admin() or private.is_my_child(p_child) or private.therapist_has_child(p_child)) then
    raise exception 'You can only see progress for your own children.';
  end if;
  return query
  select s.id, ts.slot_date, ts.start_time, ts.end_time, s.name, s.therapy_id, s.therapist_id, sc.attendance, sc.rating, sc.note, sc.rated_at
  from public.session_children sc join public.sessions s on s.id = sc.session_id join public.timetable_slots ts on ts.id = s.slot_id
  where sc.child_id = p_child and (sc.rating is not null or btrim(sc.note) <> '')
  order by ts.slot_date, ts.start_time;
end $$;

-- ============================================================ 8. weekly bills
create or replace function public.fee_weeks(p_from date, p_to date, p_child uuid default null)
returns table (child_id uuid, week_start date, allocated int, attended int, absent int, unmarked int, upcoming int,
  amount numeric, paid numeric, verifying numeric, lines jsonb, closed boolean)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare v_admin boolean := private.is_admin(); v_now timestamp := private.now_ist(); v_from date := date_trunc('week', p_from)::date;
begin
  if not v_admin and not exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'PARENT') then
    raise exception 'Fees are only visible to the centre and families.';
  end if;
  return query
  with seats as (
    select sc.child_id, date_trunc('week', ts.slot_date)::date as wk, s.therapy_id, sc.attendance, sc.rate, s.during
    from public.session_children sc join public.sessions s on s.id = sc.session_id join public.timetable_slots ts on ts.id = s.slot_id
    where ts.slot_date between v_from and p_to and (p_child is null or sc.child_id = p_child)
      and (v_admin or private.is_my_child(sc.child_id))
  ), per_therapy as (
    select child_id, wk, therapy_id,
      count(*)::int as allocated,
      (count(*) filter (where attendance in ('present', 'late')))::int as attended,
      (count(*) filter (where attendance = 'absent'))::int as absent,
      (count(*) filter (where attendance is null and upper(during) <= v_now))::int as unmarked,
      (count(*) filter (where attendance is null and upper(during) > v_now))::int as upcoming,
      coalesce(sum(rate) filter (where attendance in ('present', 'late')), 0) as amount
    from seats group by child_id, wk, therapy_id
  ), rates as (
    select child_id, wk, therapy_id, jsonb_agg(jsonb_build_object('rate', rate, 'count', n) order by rate) as rates
    from (select child_id, wk, therapy_id, rate, count(*)::int as n from seats where attendance in ('present', 'late') group by 1, 2, 3, 4) x
    group by child_id, wk, therapy_id
  ), weeks as (
    select pt.child_id, pt.wk, sum(pt.allocated)::int as allocated, sum(pt.attended)::int as attended, sum(pt.absent)::int as absent,
      sum(pt.unmarked)::int as unmarked, sum(pt.upcoming)::int as upcoming, sum(pt.amount) as amount,
      jsonb_agg(jsonb_build_object('therapy_id', pt.therapy_id, 'allocated', pt.allocated, 'attended', pt.attended, 'absent', pt.absent,
        'unmarked', pt.unmarked, 'upcoming', pt.upcoming, 'amount', pt.amount, 'rates', coalesce(r.rates, '[]'::jsonb))) as lines
    from per_therapy pt left join rates r on r.child_id = pt.child_id and r.wk = pt.wk and r.therapy_id = pt.therapy_id
    group by pt.child_id, pt.wk
  ), pays as (
    select p.child_id, p.week_start as wk,
      coalesce(sum(p.amount) filter (where p.status = 'confirmed'), 0) as paid,
      coalesce(sum(p.amount) filter (where p.status = 'verifying'), 0) as verifying
    from public.fee_payments p
    where p.week_start between v_from and p_to and (p_child is null or p.child_id = p_child) and (v_admin or private.is_my_child(p.child_id))
    group by p.child_id, p.week_start
  )
  select coalesce(w.child_id, p.child_id), coalesce(w.wk, p.wk), coalesce(w.allocated, 0), coalesce(w.attended, 0), coalesce(w.absent, 0),
    coalesce(w.unmarked, 0), coalesce(w.upcoming, 0), coalesce(w.amount, 0), coalesce(p.paid, 0), coalesce(p.verifying, 0),
    coalesce(w.lines, '[]'::jsonb),
    (coalesce(w.wk, p.wk) + 7)::timestamp <= v_now and coalesce(w.unmarked, 0) = 0 and coalesce(w.upcoming, 0) = 0
  from weeks w full join pays p on p.child_id = w.child_id and p.wk = w.wk;
end $$;

-- ============================================================ 9. paying with UPI
create or replace function private.new_txn_ref() returns text language sql volatile set search_path = '' as
$$ select 'NL' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 18)) $$;

-- Opens a UPI attempt for a finished week. The amount is what is still due, decided here, never by the app.
create or replace function public.start_upi_payment(p_child uuid, p_week date) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare b record; v_acc public.upi_accounts; v_due numeric; v_row public.fee_payments; v_open public.fee_payments;
begin
  if not (private.is_admin() or private.is_my_child(p_child)) then raise exception 'You can only pay for your own child.'; end if;
  if p_week is null or extract(isodow from p_week) <> 1 then raise exception 'Choose a week to pay for.'; end if;
  perform private.lock_week(p_child, p_week);
  -- An earlier attempt whose outcome we never heard about must be settled first, so nobody pays twice.
  select * into v_open from public.fee_payments where child_id = p_child and week_start = p_week and status = 'initiated';
  if found then raise exception 'UNFINISHED:%', v_open.id; end if;
  if (p_week + 7)::timestamp > private.now_ist() then raise exception 'This week isn''t over yet. You can pay once it ends on Sunday.'; end if;
  select * into b from private.week_bill(p_child, p_week);
  if b.open_seats > 0 then
    raise exception 'Some of this week''s sessions are still waiting for attendance. You can pay once the centre has marked them.';
  end if;
  v_due := b.amount - b.paid - b.verifying;
  if v_due <= 0 and b.verifying > 0 then raise exception 'A payment for this week is already being verified.'; end if;
  if v_due <= 0 then raise exception 'Nothing is due for this week.'; end if;
  select * into v_acc from public.upi_accounts where active;
  if not found then raise exception 'The centre hasn''t set up UPI payments yet. Please pay at the centre.'; end if;
  insert into public.fee_payments (child_id, week_start, amount, method, status, txn_ref, upi_account_id, payee_vpa, payee_name, created_by)
  values (p_child, p_week, v_due, 'UPI', 'initiated', private.new_txn_ref(), v_acc.id, v_acc.vpa, v_acc.payee_name, (select auth.uid()))
  returning * into v_row;
  return jsonb_build_object('id', v_row.id, 'txn_ref', v_row.txn_ref, 'amount', v_row.amount, 'vpa', v_row.payee_vpa, 'name', v_row.payee_name);
end $$;

-- The UPI app's reply ("txnId=..&responseCode=..&Status=SUCCESS&txnRef=..&ApprovalRefNo=.."), checked here:
-- SUCCESS with a bank reference confirms; FAILURE fails; anything else leaves the attempt open so the
-- parent can say what happened. Calling it again returns the same result.
create or replace function public.complete_upi_payment(p_payment uuid, p_response text, p_app text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v public.fee_payments; kv jsonb; v_status text; v_ref text; v_utr text; v_no bigint;
begin
  select * into v from public.fee_payments where id = p_payment for update;
  if not found then raise exception 'Payment not found.'; end if;
  if not (private.is_admin() or private.is_my_child(v.child_id)) then raise exception 'Payment not found.'; end if;
  if v.status <> 'initiated' then return jsonb_build_object('status', v.status, 'receipt_no', v.receipt_no); end if;

  select coalesce(jsonb_object_agg(lower(btrim(split_part(x, '=', 1))), btrim(split_part(x, '=', 2))), '{}'::jsonb) into kv
  from unnest(string_to_array(coalesce(p_response, ''), '&')) x where position('=' in x) > 1;
  v_status := upper(coalesce(kv->>'status', ''));
  v_ref := nullif(kv->>'txnref', '');
  v_utr := coalesce(nullif(kv->>'approvalrefno', ''), nullif(kv->>'txnid', ''));
  if v_utr is not null and v_utr !~ '^[A-Za-z0-9]{6,35}$' then v_utr := null; end if;

  update public.fee_payments set upi_response = left(coalesce(p_response, ''), 2000), upi_app = left(nullif(btrim(p_app), ''), 120) where id = v.id;

  -- A reply for some other transaction is never accepted.
  if v_ref is not null and v_ref <> v.txn_ref then
    update public.fee_payments set status = 'failed', note = 'The UPI app replied for a different transaction.', resolved_at = now() where id = v.id;
    return jsonb_build_object('status', 'failed', 'reason', 'mismatch');
  end if;
  if v_status = 'SUCCESS' and v_utr is not null then
    if exists (select 1 from public.fee_payments p where upper(p.utr) = upper(v_utr) and p.status in ('verifying', 'confirmed')) then
      update public.fee_payments set status = 'failed', note = 'This UPI reference was already used for another payment.', resolved_at = now() where id = v.id;
      return jsonb_build_object('status', 'failed', 'reason', 'duplicate');
    end if;
    v_no := nextval('public.receipt_no_seq');
    update public.fee_payments set status = 'confirmed', utr = v_utr, verified_by = 'upi_app', paid_on = private.today(),
      receipt_no = v_no, resolved_at = now() where id = v.id;
    return jsonb_build_object('status', 'confirmed', 'receipt_no', v_no);
  end if;
  if v_status in ('FAILURE', 'FAILED') then
    update public.fee_payments set status = 'failed', resolved_at = now() where id = v.id;
    return jsonb_build_object('status', 'failed', 'reason', 'declined');
  end if;
  if v_status in ('SUBMITTED', 'PENDING') and v_utr is not null
     and not exists (select 1 from public.fee_payments p where upper(p.utr) = upper(v_utr) and p.status in ('verifying', 'confirmed')) then
    update public.fee_payments set status = 'verifying', utr = v_utr where id = v.id;
    return jsonb_build_object('status', 'verifying');
  end if;
  return jsonb_build_object('status', 'initiated', 'reason', 'unknown');
end $$;

-- The parent paid but the UPI app didn't say so: they give the bank reference and the admin confirms it.
create or replace function public.submit_upi_reference(p_payment uuid, p_utr text) returns void
language plpgsql security definer set search_path = '' as $$
declare v public.fee_payments; v_utr text := upper(btrim(coalesce(p_utr, '')));
begin
  select * into v from public.fee_payments where id = p_payment for update;
  if not found or not (private.is_admin() or private.is_my_child(v.child_id)) then raise exception 'Payment not found.'; end if;
  if v.status <> 'initiated' then raise exception 'This payment has already been settled.'; end if;
  if v_utr !~ '^[A-Z0-9]{6,35}$' then raise exception 'Enter the UPI reference number (UTR) shown in your UPI app.'; end if;
  if exists (select 1 from public.fee_payments p where upper(p.utr) = v_utr and p.status in ('verifying', 'confirmed')) then
    raise exception 'This UPI reference number was already used for another payment.';
  end if;
  update public.fee_payments set status = 'verifying', utr = v_utr where id = v.id;
end $$;

-- The parent didn't pay (closed the UPI app, changed their mind).
create or replace function public.cancel_upi_payment(p_payment uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v public.fee_payments;
begin
  select * into v from public.fee_payments where id = p_payment for update;
  if not found or not (private.is_admin() or private.is_my_child(v.child_id)) then raise exception 'Payment not found.'; end if;
  if v.status <> 'initiated' then return; end if;
  update public.fee_payments set status = 'cancelled', resolved_at = now() where id = v.id;
end $$;

-- Admin: confirm or reject a payment waiting for verification, or reverse a confirmed one found to be invalid.
create or replace function public.review_payment(p_payment uuid, p_action text, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare v public.fee_payments;
begin
  perform private.require_admin();
  select * into v from public.fee_payments where id = p_payment for update;
  if not found then raise exception 'Payment not found.'; end if;
  perform private.lock_week(v.child_id, v.week_start);
  if p_action = 'confirm' and v.status in ('verifying', 'initiated') then
    update public.fee_payments set status = 'confirmed', verified_by = 'admin', paid_on = private.today(),
      receipt_no = nextval('public.receipt_no_seq'), resolved_at = now(), resolved_by = (select auth.uid()),
      note = coalesce(nullif(btrim(p_note), ''), note) where id = v.id;
  elsif p_action = 'reject' and v.status in ('verifying', 'initiated') then
    update public.fee_payments set status = 'failed', resolved_at = now(), resolved_by = (select auth.uid()),
      note = coalesce(nullif(btrim(p_note), ''), 'Not received by the centre.') where id = v.id;
  elsif p_action = 'reverse' and v.status = 'confirmed' then
    if length(btrim(coalesce(p_note, ''))) = 0 then raise exception 'Say why this payment is being reversed.'; end if;
    update public.fee_payments set status = 'reversed', resolved_at = now(), resolved_by = (select auth.uid()), note = btrim(p_note) where id = v.id;
  else
    raise exception 'This payment can''t be changed that way any more.';
  end if;
end $$;

-- Admin: money received at the centre (cash, bank transfer, ...). Never more than is still due.
create or replace function public.record_payment(p_child uuid, p_week date, p_amount numeric, p_method text, p_note text, p_paid_on date)
returns uuid language plpgsql security definer set search_path = '' as $$
declare b record; v_id uuid; v_due numeric;
begin
  perform private.require_admin();
  if p_week is null or extract(isodow from p_week) <> 1 then raise exception 'Choose a week.'; end if;
  if coalesce(p_amount, 0) <= 0 then raise exception 'Enter an amount greater than zero.'; end if;
  perform private.lock_week(p_child, p_week);
  select * into b from private.week_bill(p_child, p_week);
  v_due := b.amount - b.paid - b.verifying;
  if p_amount > v_due then
    raise exception 'Only ₹% is due for this week.', to_char(greatest(v_due, 0), 'FM999G999G990D00');
  end if;
  insert into public.fee_payments (child_id, week_start, amount, method, status, txn_ref, verified_by, note, paid_on, receipt_no,
    created_by, resolved_at, resolved_by)
  values (p_child, p_week, p_amount, coalesce(nullif(btrim(p_method), ''), 'Cash'), 'confirmed', private.new_txn_ref(), 'admin',
    btrim(coalesce(p_note, '')), coalesce(p_paid_on, private.today()), nextval('public.receipt_no_seq'),
    (select auth.uid()), now(), (select auth.uid()))
  returning id into v_id;
  return v_id;
end $$;

-- Admin: switch the UPI ID that receives payments. Attempts already started keep the ID they were given.
create or replace function public.set_active_upi(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  if p_id is not null and not exists (select 1 from public.upi_accounts where id = p_id) then raise exception 'UPI ID not found.'; end if;
  update public.upi_accounts set active = false where active and id is distinct from p_id;
  if p_id is not null then update public.upi_accounts set active = true, archived = false where id = p_id; end if;
end $$;

-- ============================================================ 10. reschedule requests
create table public.reschedule_requests (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  session_id uuid references public.sessions(id) on delete set null,
  -- once: this session only · series: this and later sessions at the same time with the same therapist
  scope text not null check (scope in ('once', 'series')),
  from_date date not null,
  from_start time not null,
  from_end time not null,
  session_name text not null,
  therapist_id uuid references public.therapists(id) on delete set null,
  therapy_id uuid references public.therapies(id) on delete set null,
  preferred_date date,
  preferred_start time,
  preferred_end time,
  reason text not null default '' check (length(reason) <= 500),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  admin_note text not null default '' check (length(admin_note) <= 500),
  moved int not null default 0,
  new_date date,
  new_start time,
  new_end time,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  check (preferred_end is null or preferred_start is null or preferred_end > preferred_start)
);
create unique index reschedule_one_pending on public.reschedule_requests (child_id, session_id) where status = 'pending';
create index reschedule_requests_status_idx on public.reschedule_requests (status, created_at);

create or replace function public.request_reschedule(p_session uuid, p_child uuid, p_scope text, p_date date, p_start time, p_end time, p_reason text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v record; v_id uuid;
begin
  if not (private.is_admin() or private.is_my_child(p_child)) then raise exception 'You can only ask for your own child.'; end if;
  if p_scope not in ('once', 'series') then raise exception 'Choose whether to move this session or all sessions at this time.'; end if;
  select s.name, s.therapist_id, s.therapy_id, s.during, ts.slot_date, ts.start_time, ts.end_time into v
  from public.sessions s join public.timetable_slots ts on ts.id = s.slot_id
  join public.session_children sc on sc.session_id = s.id and sc.child_id = p_child where s.id = p_session;
  if not found then raise exception 'Your child is not in this session.'; end if;
  if lower(v.during) <= private.now_ist() then raise exception 'This session has already started.'; end if;
  if p_date is not null and p_date < private.today() then raise exception 'Choose a day from today on.'; end if;
  if p_start is not null and p_end is not null and p_end <= p_start then raise exception 'The end time must be after the start time.'; end if;
  begin
    insert into public.reschedule_requests (child_id, session_id, scope, from_date, from_start, from_end, session_name, therapist_id, therapy_id,
      preferred_date, preferred_start, preferred_end, reason, created_by)
    values (p_child, p_session, p_scope, v.slot_date, v.start_time, v.end_time, v.name, v.therapist_id, v.therapy_id,
      p_date, p_start, p_end, btrim(coalesce(p_reason, '')), (select auth.uid()))
    returning id into v_id;
  exception when unique_violation then
    raise exception 'You have already asked to move this session. The centre will reply soon.';
  end;
  return v_id;
end $$;

create or replace function public.cancel_reschedule(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v public.reschedule_requests;
begin
  select * into v from public.reschedule_requests where id = p_id for update;
  if not found or not (private.is_admin() or private.is_my_child(v.child_id)) then raise exception 'Request not found.'; end if;
  if v.status <> 'pending' then raise exception 'The centre has already answered this request.'; end if;
  update public.reschedule_requests set status = 'cancelled', resolved_at = now(), resolved_by = (select auth.uid()) where id = p_id;
end $$;

-- Moves one child's seat to the same kind of session (same therapist and therapy) at a new date and time,
-- joining a session already there or creating one. The old session goes if nobody is left in it.
create or replace function private.move_seat(p_child uuid, p_session uuid, p_date date, p_start time, p_end time) returns void
language plpgsql security definer set search_path = '' as $$
declare s record; v_slot uuid; v_target uuid;
begin
  select x.id, x.name, x.therapist_id, x.therapy_id, x.slot_id, x.during into s from public.sessions x where x.id = p_session;
  if not found then raise exception 'The session to move no longer exists.'; end if;
  if lower(s.during) <= private.now_ist() then raise exception 'A session that has started can''t be moved.'; end if;
  if (p_date + p_start) <= private.now_ist() then raise exception 'The new time must be in the future.'; end if;
  insert into public.timetable_slots (slot_date, start_time, end_time) values (p_date, p_start, p_end) on conflict do nothing;
  select id into v_slot from public.timetable_slots where slot_date = p_date and start_time = p_start and end_time = p_end;
  if v_slot = s.slot_id then return; end if;
  delete from public.session_children where session_id = s.id and child_id = p_child;
  delete from public.sessions x where x.id = s.id and not exists (select 1 from public.session_children sc where sc.session_id = s.id);
  select id into v_target from public.sessions where slot_id = v_slot and therapist_id = s.therapist_id and therapy_id = s.therapy_id limit 1;
  begin
    if v_target is null then
      insert into public.sessions (slot_id, name, therapist_id, therapy_id) values (v_slot, s.name, s.therapist_id, s.therapy_id) returning id into v_target;
    end if;
    insert into public.session_children (session_id, child_id) values (v_target, p_child);
  exception when exclusion_violation then
    raise exception '%', private.clash_message(s.therapist_id, array[p_child], tsrange(p_date + p_start, p_date + p_end, '[)'), v_target);
  end;
end $$;

-- Admin: approve (moving the session, or every later one at the same time) or reject. All or nothing.
create or replace function public.resolve_reschedule(p_id uuid, p_approve boolean, p_date date, p_start time, p_end time, p_note text)
returns int language plpgsql security definer set search_path = '' as $$
declare v public.reschedule_requests; src record; r record; n int := 0; v_offset int;
begin
  perform private.require_admin();
  select * into v from public.reschedule_requests where id = p_id for update;
  if not found then raise exception 'Request not found.'; end if;
  if v.status <> 'pending' then raise exception 'This request has already been answered.'; end if;
  if not p_approve then
    update public.reschedule_requests set status = 'rejected', admin_note = btrim(coalesce(p_note, '')), resolved_at = now(), resolved_by = (select auth.uid())
    where id = p_id;
    return 0;
  end if;
  if p_date is null or p_start is null or p_end is null then raise exception 'Choose the new day and time.'; end if;
  if p_end <= p_start then raise exception 'The end time must be after the start time.'; end if;
  select s.id, s.therapist_id, s.therapy_id, ts.slot_date, ts.start_time, ts.end_time into src
  from public.sessions s join public.timetable_slots ts on ts.id = s.slot_id where s.id = v.session_id;
  if not found then raise exception 'The original session no longer exists. Reject this request and ask the family to send a new one.'; end if;
  v_offset := p_date - src.slot_date;
  for r in
    select s.id, ts.slot_date from public.sessions s join public.timetable_slots ts on ts.id = s.slot_id
    join public.session_children sc on sc.session_id = s.id and sc.child_id = v.child_id
    where lower(s.during) > private.now_ist() and (
      s.id = src.id or (v.scope = 'series' and s.therapist_id = src.therapist_id and s.therapy_id = src.therapy_id
        and ts.start_time = src.start_time and ts.end_time = src.end_time and ts.slot_date > src.slot_date))
    order by ts.slot_date
  loop
    perform private.move_seat(v.child_id, r.id, r.slot_date + v_offset, p_start, p_end);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'Nothing left to move: the session has already started.'; end if;
  update public.reschedule_requests set status = 'approved', admin_note = btrim(coalesce(p_note, '')), moved = n,
    new_date = p_date, new_start = p_start, new_end = p_end, resolved_at = now(), resolved_by = (select auth.uid())
  where id = p_id;
  return n;
end $$;

-- ============================================================ 11. children, sessions and weeks with therapies
-- Items in p_therapies: {"therapy_id": uuid, "session_fee": number | null}; null uses the therapy's base fee.
create or replace function public.save_child(p_id uuid, p_name text, p_dob date, p_father text, p_mother text, p_phone text, p_alt_phone text, p_therapies jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := p_id;
begin
  perform private.require_admin();
  if length(btrim(coalesce(p_name, ''))) = 0 then raise exception 'Enter the child''s name.'; end if;
  if p_dob is null or p_dob > private.today() then raise exception 'Enter a valid date of birth.'; end if;
  if length(private.digits10(p_phone)) <> 10 then raise exception 'Enter a valid 10-digit contact number.'; end if;
  if jsonb_array_length(coalesce(p_therapies, '[]')) = 0 then raise exception 'Select at least one therapy.'; end if;
  if exists (select 1 from jsonb_array_elements(p_therapies) x where (x->>'session_fee') is not null and (x->>'session_fee')::numeric < 0) then
    raise exception 'A session fee can''t be negative.';
  end if;
  if v_id is null then
    insert into public.children (name, dob, father_name, mother_name, phone, alt_phone)
    values (btrim(p_name), p_dob, btrim(coalesce(p_father, '')), btrim(coalesce(p_mother, '')), btrim(p_phone), btrim(coalesce(p_alt_phone, '')))
    returning id into v_id;
  else
    update public.children set name = btrim(p_name), dob = p_dob, father_name = btrim(coalesce(p_father, '')),
      mother_name = btrim(coalesce(p_mother, '')), phone = btrim(p_phone), alt_phone = btrim(coalesce(p_alt_phone, ''))
    where id = v_id;
    if not found then raise exception 'Child not found.'; end if;
    delete from public.child_therapies ct where ct.child_id = v_id
      and ct.therapy_id not in (select (x->>'therapy_id')::uuid from jsonb_array_elements(p_therapies) x);
  end if;
  insert into public.child_therapies (child_id, therapy_id, session_fee)
  select v_id, (x->>'therapy_id')::uuid, round((x->>'session_fee')::numeric, 2) from jsonb_array_elements(p_therapies) x
  on conflict (child_id, therapy_id) do update set session_fee = excluded.session_fee;
  return v_id;
end $$;

drop function if exists public.create_sessions(date[], time, time, text, uuid, uuid[]);
create or replace function public.create_sessions(p_dates date[], p_start time, p_end time, p_name text, p_therapist uuid, p_therapy uuid, p_children uuid[])
returns integer language plpgsql security definer set search_path = '' as $$
declare d date; v_slot uuid; v_session uuid; n int := 0;
begin
  perform private.require_admin();
  if length(btrim(coalesce(p_name, ''))) = 0 then raise exception 'Enter a session name.'; end if;
  if coalesce(cardinality(p_children), 0) = 0 then raise exception 'Select at least one child.'; end if;
  if not exists (select 1 from public.therapies where id = p_therapy) then raise exception 'Select a therapy.'; end if;
  if not exists (select 1 from public.therapists where id = p_therapist and active) then raise exception 'Select an active therapist.'; end if;
  if exists (select 1 from unnest(p_children) x where not exists (select 1 from public.children c where c.id = x and c.active)) then
    raise exception 'One of the selected children is no longer active.';
  end if;
  foreach d in array p_dates loop
    insert into public.timetable_slots (slot_date, start_time, end_time) values (d, p_start, p_end) on conflict do nothing;
    select id into v_slot from public.timetable_slots where slot_date = d and start_time = p_start and end_time = p_end;
    begin
      insert into public.sessions (slot_id, name, therapist_id, therapy_id) values (v_slot, btrim(p_name), p_therapist, p_therapy) returning id into v_session;
      insert into public.session_children (session_id, child_id) select v_session, x from unnest(p_children) x;
    exception when exclusion_violation then
      raise exception '%', private.clash_message(p_therapist, p_children, tsrange(d + p_start, d + p_end, '[)'));
    end;
    n := n + 1;
  end loop;
  return n;
end $$;

drop function if exists public.update_session(uuid, text, uuid, uuid[]);
create or replace function public.update_session(p_session uuid, p_name text, p_therapist uuid, p_therapy uuid, p_children uuid[]) returns void
language plpgsql security definer set search_path = '' as $$
declare v_during tsrange;
begin
  perform private.require_admin();
  if length(btrim(coalesce(p_name, ''))) = 0 then raise exception 'Enter a session name.'; end if;
  if coalesce(cardinality(p_children), 0) = 0 then raise exception 'Select at least one child.'; end if;
  if not exists (select 1 from public.therapies where id = p_therapy) then raise exception 'Select a therapy.'; end if;
  select during into v_during from public.sessions where id = p_session for update;
  if not found then raise exception 'This session no longer exists.'; end if;
  if p_therapy is distinct from (select therapy_id from public.sessions where id = p_session)
     and exists (select 1 from public.session_children where session_id = p_session and attendance is not null) then
    raise exception 'Attendance is already marked for this session, so its therapy can''t change.';
  end if;
  begin
    update public.sessions set name = btrim(p_name), therapist_id = p_therapist, therapy_id = p_therapy where id = p_session;
    delete from public.session_children where session_id = p_session and child_id <> all (p_children);
    insert into public.session_children (session_id, child_id) select p_session, x from unnest(p_children) x on conflict do nothing;
  exception when exclusion_violation then
    raise exception '%', private.clash_message(p_therapist, p_children, v_during, p_session);
  end;
end $$;

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
    insert into public.sessions (slot_id, name, therapist_id, therapy_id) values (v_slot, r.name, r.therapist_id, r.therapy_id) returning id into v_session;
    insert into public.session_children (session_id, child_id)
    select v_session, sc.child_id from public.session_children sc join public.children c on c.id = sc.child_id and c.active
    where sc.session_id = r.id;
    n := n + 1;
  end loop;
  return n;
end $$;

-- ============================================================ 12. access
alter table public.upi_accounts enable row level security;
alter table public.fee_payments enable row level security;
alter table public.reschedule_requests enable row level security;

-- UPI IDs: the admin manages them directly; families only ever get the active one through start_upi_payment.
create policy "Read" on public.upi_accounts for select to authenticated using ((select private.is_admin()));
create policy "Admin insert" on public.upi_accounts for insert to authenticated with check ((select private.is_admin()) and not active);
create policy "Admin update" on public.upi_accounts for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admin delete" on public.upi_accounts for delete to authenticated using ((select private.is_admin()) and not active);

-- Payments and requests: read-only through the API; every change goes through the functions above.
create policy "Read" on public.fee_payments for select to authenticated
  using ((select private.is_admin()) or private.is_my_child(child_id));
create policy "Read" on public.reschedule_requests for select to authenticated
  using ((select private.is_admin()) or private.is_my_child(child_id));

revoke execute on all functions in schema private from public, anon;
revoke execute on function public.mark_attendance, public.save_session_note, public.rate_session, public.progress_points, public.fee_weeks,
  public.start_upi_payment, public.complete_upi_payment, public.submit_upi_reference, public.cancel_upi_payment, public.review_payment,
  public.record_payment, public.set_active_upi, public.request_reschedule, public.cancel_reschedule, public.resolve_reschedule,
  public.save_child, public.create_sessions, public.update_session, public.copy_week from public, anon;
grant execute on function public.mark_attendance, public.save_session_note, public.rate_session, public.progress_points, public.fee_weeks,
  public.start_upi_payment, public.complete_upi_payment, public.submit_upi_reference, public.cancel_upi_payment, public.review_payment,
  public.record_payment, public.set_active_upi, public.request_reschedule, public.cancel_reschedule, public.resolve_reschedule,
  public.save_child, public.create_sessions, public.update_session, public.copy_week to authenticated;
revoke all on sequence public.receipt_no_seq from public, anon, authenticated;

alter publication supabase_realtime add table public.fee_payments, public.upi_accounts, public.reschedule_requests;

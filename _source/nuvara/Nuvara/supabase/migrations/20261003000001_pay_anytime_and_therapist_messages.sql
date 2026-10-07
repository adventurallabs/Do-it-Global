-- 1. Fees can be paid at any time, not only after the week ends.
--    A week's bill is what the child has attended so far. Families can pay it (with UPI) and the admin can
--    record money for it the same day, mid-week or later. More sessions attended later in the week simply
--    add to what is due. Paying no longer freezes the rest of the week's attendance; the only change refused
--    is one that would make the bill smaller than what has already been paid (or is being paid) for it.
-- 2. The admin can record one amount for a child and have it settle the oldest unpaid weeks first.
-- 3. Messages: besides each child's family, the admin and each therapist have their own conversation.
--    Therapists and families never message each other.

-- ============================================================ 1. fees: pay any time
-- Money already counted for the week, or on its way: confirmed, being verified, or a UPI attempt in progress.
create or replace function private.week_committed(p_child uuid, p_week date) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(p.amount), 0) from public.fee_payments p
  where p.child_id = p_child and p.week_start = p_week and p.status in ('initiated', 'verifying', 'confirmed')
$$;

-- What the child's attended sessions in the week add up to (seats visible to this statement).
create or replace function private.week_attended_amount(p_child uuid, p_week date) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(sc.rate), 0) from public.session_children sc
  where sc.child_id = p_child and date_trunc('week', lower(sc.during))::date = p_week and sc.attendance in ('present', 'late')
$$;

create or replace function private.money_text(p numeric) returns text language sql immutable set search_path = '' as
$$ select '₹' || to_char(greatest(p, 0), 'FM999G999G990D00') $$;

create or replace function public.mark_attendance(p_session uuid, p_children uuid[], p_status text) returns void
language plpgsql security definer set search_path = '' as $$
declare v record; v_now timestamp := private.now_ist(); c uuid; v_week date; v_committed numeric;
begin
  if not private.can_run_session(p_session) then raise exception 'Only this session''s therapist or the admin can mark attendance.'; end if;
  if p_status is not null and p_status not in ('present', 'late', 'absent') then raise exception 'Unknown attendance status.'; end if;
  select s.during, s.therapy_id, ts.slot_date into v from public.sessions s join public.timetable_slots ts on ts.id = s.slot_id where s.id = p_session;
  if not found then raise exception 'This session no longer exists.'; end if;
  if lower(v.during) - interval '15 minutes' > v_now then raise exception 'Attendance opens 15 minutes before the session starts.'; end if;
  v_week := date_trunc('week', v.slot_date)::date;
  foreach c in array coalesce(p_children, '{}') loop
    perform private.lock_week(c, v.slot_date);
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
    -- Present ↔ late keeps the rate already charged; a newly attended seat takes today's rate.
    rate = case when p_status in ('present', 'late') then
             coalesce(case when sc.attendance in ('present', 'late') then sc.rate end, private.rate_of(sc.child_id, v.therapy_id)) end,
    rating = case when p_status in ('present', 'late') then sc.rating end,
    rated_at = case when p_status in ('present', 'late') then sc.rated_at end
  where sc.session_id = p_session and sc.child_id = any (p_children);
  if not found then raise exception 'These children are not in this session.'; end if;
  -- A bill can't drop below what was already paid for that week.
  foreach c in array coalesce(p_children, '{}') loop
    v_committed := private.week_committed(c, v_week);
    if v_committed > 0 and private.week_attended_amount(c, v_week) < v_committed - 0.005 then
      raise exception '% has already paid % for this week, so this session can''t be changed to not attended. Reverse or reject that payment in Fees first.',
        (select ch.name from public.children ch where ch.id = c), private.money_text(v_committed);
    end if;
  end loop;
end $$;

-- Removing an attended seat (directly, or by deleting its session or slot) must not leave a week's bill
-- below what was paid for it. Checked after the delete, when every removed seat is gone.
create or replace function private.guard_paid_seat() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_week date := date_trunc('week', lower(old.during))::date; v_committed numeric;
begin
  if coalesce(old.attendance, '') not in ('present', 'late') or not exists (select 1 from public.children c where c.id = old.child_id) then return old; end if;
  v_committed := private.week_committed(old.child_id, v_week);
  if v_committed > 0 and private.week_attended_amount(old.child_id, v_week) < v_committed - 0.005 then
    raise exception '% has paid % for the week of %, so this attended session can no longer be removed.',
      (select c.name from public.children c where c.id = old.child_id), private.money_text(v_committed), to_char(v_week, 'DD Mon');
  end if;
  return old;
end $$;
drop trigger if exists seat_paid_guard on public.session_children;
create trigger seat_paid_guard after delete on public.session_children for each row execute function private.guard_paid_seat();

-- UPI: pay what is due now for any week up to this one, without waiting for the week to end.
create or replace function public.start_upi_payment(p_child uuid, p_week date) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare b record; v_acc public.upi_accounts; v_due numeric; v_row public.fee_payments; v_open public.fee_payments;
begin
  if not (private.is_admin() or private.is_my_child(p_child)) then raise exception 'You can only pay for your own child.'; end if;
  if p_week is null or extract(isodow from p_week) <> 1 then raise exception 'Choose a week to pay for.'; end if;
  if p_week > date_trunc('week', private.today())::date then raise exception 'That week hasn''t started yet.'; end if;
  if (select count(*) from public.fee_payments where created_by = (select auth.uid()) and created_at > now() - interval '1 hour' and method = 'UPI') >= 12 then
    raise exception 'Too many payment attempts. Please wait a while and try again, or pay at the centre.';
  end if;
  perform private.lock_week(p_child, p_week);
  select * into v_open from public.fee_payments where child_id = p_child and week_start = p_week and status = 'initiated';
  if found then raise exception 'UNFINISHED:%', v_open.id; end if;
  select * into b from private.week_bill(p_child, p_week);
  v_due := b.amount - b.paid - b.verifying;
  if v_due <= 0 and b.verifying > 0 then raise exception 'A payment for this week is already being verified.'; end if;
  if v_due <= 0 then raise exception 'Nothing is due for this week yet. Fees are added as sessions are attended.'; end if;
  if v_due > 100000 then raise exception 'UPI payments are limited to ₹1,00,000 at a time. Please pay this week at the centre.'; end if;
  select * into v_acc from public.upi_accounts where active and not archived;
  if not found then raise exception 'The centre hasn''t set up UPI payments yet. Please pay at the centre.'; end if;
  insert into public.fee_payments (child_id, week_start, amount, method, status, txn_ref, upi_account_id, payee_vpa, payee_name, payee_kind, payee_mc, created_by)
  values (p_child, p_week, v_due, 'UPI', 'initiated', private.new_txn_ref(), v_acc.id, v_acc.vpa, v_acc.payee_name, v_acc.kind, v_acc.merchant_code, (select auth.uid()))
  returning * into v_row;
  return jsonb_build_object('id', v_row.id, 'txn_ref', v_row.txn_ref, 'amount', v_row.amount, 'vpa', v_row.payee_vpa, 'name', v_row.payee_name,
    'kind', v_row.payee_kind, 'mc', v_row.payee_mc);
end $$;

-- Admin: one amount received for a child, settling the oldest unpaid weeks first (one receipt per week).
-- Returns how many weeks it went to. All or nothing.
create or replace function public.record_child_payment(p_child uuid, p_amount numeric, p_method text, p_note text, p_paid_on date)
returns integer language plpgsql security definer set search_path = '' as $$
declare w record; v_left numeric := round(coalesce(p_amount, 0), 2); v_part numeric; n int := 0;
begin
  perform private.require_admin();
  if v_left <= 0 then raise exception 'Enter an amount greater than zero.'; end if;
  if p_paid_on is not null and p_paid_on > private.today() then raise exception 'The date received can''t be in the future.'; end if;
  if not exists (select 1 from public.children where id = p_child) then raise exception 'Child not found.'; end if;
  for w in
    select distinct date_trunc('week', lower(sc.during))::date as wk from public.session_children sc
    where sc.child_id = p_child and sc.attendance in ('present', 'late') order by 1
  loop
    exit when v_left <= 0.005;
    perform private.lock_week(p_child, w.wk);
    v_part := private.week_attended_amount(p_child, w.wk)
      - coalesce((select sum(p.amount) from public.fee_payments p where p.child_id = p_child and p.week_start = w.wk and p.status in ('confirmed', 'verifying')), 0);
    continue when v_part <= 0.005;
    if exists (select 1 from public.fee_payments where child_id = p_child and week_start = w.wk and status = 'initiated') then
      raise exception 'A UPI payment for the week of % is in progress. Confirm or reject it in Fees → Verify payments first.', to_char(w.wk, 'DD Mon');
    end if;
    v_part := least(v_part, v_left);
    insert into public.fee_payments (child_id, week_start, amount, method, status, txn_ref, verified_by, note, paid_on, receipt_no,
      created_by, resolved_at, resolved_by, reconciled_at, reconciled_by)
    values (p_child, w.wk, v_part, coalesce(nullif(btrim(p_method), ''), 'Cash'), 'confirmed', private.new_txn_ref(), 'admin',
      btrim(coalesce(p_note, '')), coalesce(p_paid_on, private.today()), nextval('public.receipt_no_seq'),
      (select auth.uid()), now(), (select auth.uid()), now(), (select auth.uid()));
    v_left := v_left - v_part;
    n := n + 1;
  end loop;
  if v_left > 0.005 then
    raise exception 'Only % is due for this child right now.', private.money_text(round(coalesce(p_amount, 0), 2) - v_left);
  end if;
  return n;
end $$;
revoke execute on function public.record_child_payment(uuid, numeric, text, text, date) from public, anon;
grant execute on function public.record_child_payment(uuid, numeric, text, text, date) to authenticated;
revoke execute on function private.week_committed(uuid, date), private.week_attended_amount(uuid, date), private.money_text(numeric) from public, anon, authenticated;

-- ============================================================ 2. messages with therapists
alter table public.messages
  alter column child_id drop not null,
  add column therapist_id uuid references public.therapists(id) on delete cascade,
  add constraint messages_one_thread check (num_nonnulls(child_id, therapist_id) = 1);
create index messages_therapist_thread_idx on public.messages (therapist_id, created_at desc) where therapist_id is not null;

drop policy "Read" on public.messages;
drop policy "Send" on public.messages;
create policy "Read" on public.messages for select to authenticated using (
  (select private.is_admin())
  or (child_id is not null and private.is_my_child(child_id))
  or (therapist_id is not null and therapist_id = (select private.my_therapist_id()))
);
-- The admin writes to families and therapists; a family writes only in its child's thread and a therapist
-- only in their own. There is no family ↔ therapist thread.
create policy "Send" on public.messages for insert to authenticated with check (
  sender_id = (select auth.uid()) and read_at is null and (
    ((select private.is_admin()) and from_admin)
    or (not from_admin and child_id is not null and private.is_my_child(child_id))
    or (not from_admin and therapist_id is not null and therapist_id = (select private.my_therapist_id()))
  )
);

create or replace function public.mark_therapist_thread_read(p_therapist uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_admin boolean := private.is_admin();
begin
  if not (v_admin or p_therapist = private.my_therapist_id()) then raise exception 'Not your conversation.'; end if;
  update public.messages set read_at = now()
  where therapist_id = p_therapist and read_at is null and from_admin = not v_admin;
end $$;
revoke execute on function public.mark_therapist_thread_read(uuid) from public, anon;
grant execute on function public.mark_therapist_thread_read(uuid) to authenticated;

-- UPI payments, hardened. Any UPI ID works: a personal one (person-to-person) or a merchant/business one,
-- and the admin can keep as many as they like with one active. The trust decision stays as agreed: a clear
-- SUCCESS from the UPI app confirms the payment straight away. Everything around it is tightened:
--
-- * Each payment remembers whether its payee was personal or merchant. Merchant links carry our reference
--   (`tr`) and the app must echo it back; personal links can't carry it, so the app's own txnRef is ignored
--   unless it names another of our payments.
-- * Auto-confirm needs SUCCESS, a real bank reference (12-digit RRN) and a reply within 30 minutes of
--   starting, from the person who started it. Anything weaker (SUCCESS without an RRN, a late reply, a
--   merchant reply without our reference, PENDING) goes to the admin as "verifying".
-- * The UPI app's own transaction ID is kept apart from the bank reference (it is not a UTR) and can't be
--   reused either. A bank reference the admin already rejected or reversed can't be submitted again.
-- * App-confirmed payments stay "not yet seen in bank" until the admin ticks them off (reconciled).
-- * While a UPI attempt is open, the week's attendance and cash entries are frozen, so the amount the
--   parent is paying can't drift from the bill. Starting attempts is rate-limited, and capped at the UPI
--   per-transaction limit.

-- ============================================================ 1. UPI IDs: personal or merchant
alter table public.upi_accounts
  add column kind text not null default 'personal' check (kind in ('personal', 'merchant')),
  -- Merchant category code (4 digits) from the bank/PSP, sent as `mc`; optional.
  add column merchant_code text check (merchant_code ~ '^[0-9]{4}$'),
  add constraint upi_accounts_mc_merchant_only check (kind = 'merchant' or merchant_code is null);

-- UPI IDs are case-insensitive; store them trimmed and lower-case so the same ID always matches.
create or replace function private.upi_vpa_normalise() returns trigger language plpgsql set search_path = '' as $$
begin
  new.vpa := lower(btrim(new.vpa));
  new.payee_name := btrim(new.payee_name);
  new.label := btrim(new.label);
  return new;
end $$;
create trigger upi_vpa_normalise before insert or update on public.upi_accounts for each row execute function private.upi_vpa_normalise();
update public.upi_accounts set vpa = vpa;

-- ============================================================ 2. payments
alter table public.fee_payments
  add column payee_kind text check (payee_kind in ('personal', 'merchant')),
  add column payee_mc text,
  -- The UPI app's own transaction ID (not a bank reference).
  add column upi_txn_id text check (upi_txn_id ~ '^[A-Za-z0-9._-]{4,64}$'),
  -- App-confirmed payments: when the admin saw the money in the bank.
  add column reconciled_at timestamptz,
  add column reconciled_by uuid references public.profiles(id) on delete set null;
update public.fee_payments set payee_kind = 'personal' where payee_vpa is not null and payee_kind is null;
-- Admin-confirmed and cash payments were checked by the admin when confirmed.
update public.fee_payments set reconciled_at = coalesce(resolved_at, created_at) where status = 'confirmed' and verified_by = 'admin';

comment on column public.fee_payments.txn_ref is 'Our one-time reference: in the UPI note always, and as `tr` for merchant UPI IDs.';
create unique index fee_payments_txn_id_key on public.fee_payments (upi_txn_id) where upi_txn_id is not null and status in ('verifying', 'confirmed');
create index fee_payments_created_by_idx on public.fee_payments (created_by, created_at);

-- ============================================================ 3. an open UPI attempt freezes its week
-- "Settled or in progress": confirmed, verifying, or a UPI attempt whose outcome isn't known yet.
create or replace function private.week_paid(p_child uuid, p_day date) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.fee_payments p
    where p.child_id = p_child and p.week_start = date_trunc('week', p_day)::date and p.status in ('initiated', 'verifying', 'confirmed'))
$$;

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
      raise exception 'This week''s fee is paid or a payment for it is in progress, so its attendance can no longer change. (Admin: settle open payments in Fees → Verify first.)';
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

create or replace function private.guard_paid_seat() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.attendance is not null and exists (select 1 from public.children c where c.id = old.child_id)
     and private.week_paid(old.child_id, lower(old.during)::date) then
    raise exception '%''s fee for that week is paid or being paid, so this session can no longer be removed.',
      (select c.name from public.children c where c.id = old.child_id);
  end if;
  return old;
end $$;

-- ============================================================ 4. starting a UPI payment
create or replace function public.start_upi_payment(p_child uuid, p_week date) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare b record; v_acc public.upi_accounts; v_due numeric; v_row public.fee_payments; v_open public.fee_payments;
begin
  if not (private.is_admin() or private.is_my_child(p_child)) then raise exception 'You can only pay for your own child.'; end if;
  if p_week is null or extract(isodow from p_week) <> 1 then raise exception 'Choose a week to pay for.'; end if;
  -- Scripts can't flood the payments table.
  if (select count(*) from public.fee_payments where created_by = (select auth.uid()) and created_at > now() - interval '1 hour' and method = 'UPI') >= 12 then
    raise exception 'Too many payment attempts. Please wait a while and try again, or pay at the centre.';
  end if;
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
  if v_due > 100000 then raise exception 'UPI payments are limited to ₹1,00,000 at a time. Please pay this week at the centre.'; end if;
  select * into v_acc from public.upi_accounts where active and not archived;
  if not found then raise exception 'The centre hasn''t set up UPI payments yet. Please pay at the centre.'; end if;
  insert into public.fee_payments (child_id, week_start, amount, method, status, txn_ref, upi_account_id, payee_vpa, payee_name, payee_kind, payee_mc, created_by)
  values (p_child, p_week, v_due, 'UPI', 'initiated', private.new_txn_ref(), v_acc.id, v_acc.vpa, v_acc.payee_name, v_acc.kind, v_acc.merchant_code, (select auth.uid()))
  returning * into v_row;
  return jsonb_build_object('id', v_row.id, 'txn_ref', v_row.txn_ref, 'amount', v_row.amount, 'vpa', v_row.payee_vpa, 'name', v_row.payee_name,
    'kind', v_row.payee_kind, 'mc', v_row.payee_mc);
end $$;

-- ============================================================ 5. the UPI app's reply
-- A bank reference (or app transaction ID) can stand for one payment only, and one the admin already
-- turned down can't come back.
create or replace function private.ref_burned(p_utr text, p_txn_id text, p_except uuid) returns text
language sql stable security definer set search_path = '' as $$
  select case
    when p_utr is not null and exists (select 1 from public.fee_payments p where p.id <> p_except and upper(p.utr) = upper(p_utr) and p.status in ('verifying', 'confirmed'))
      then 'This UPI reference was already used for another payment.'
    when p_utr is not null and exists (select 1 from public.fee_payments p where p.id <> p_except and upper(p.utr) = upper(p_utr) and p.status in ('failed', 'reversed') and p.resolved_by is not null)
      then 'This UPI reference was already checked by the centre and not accepted.'
    when p_txn_id is not null and exists (select 1 from public.fee_payments p where p.id <> p_except and p.upi_txn_id = p_txn_id and p.status in ('verifying', 'confirmed', 'reversed'))
      then 'This UPI transaction was already used for another payment.'
  end
$$;

-- The reply ("txnId=..&responseCode=..&Status=SUCCESS&txnRef=..&ApprovalRefNo=..") is only what the
-- parent's phone says. Clear, fresh SUCCESS with a bank reference confirms (the agreed trade-off; the admin
-- reconciles these later). Weaker signals go to the admin. Calling it again returns the same result.
create or replace function public.complete_upi_payment(p_payment uuid, p_response text, p_app text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v public.fee_payments; kv jsonb; v_status text; v_ref text; v_utr text; v_txn text; v_no bigint; v_burned text; v_why text;
  v_fresh boolean; v_linked boolean;
begin
  select * into v from public.fee_payments where id = p_payment for update;
  if not found then raise exception 'Payment not found.'; end if;
  -- Only the person who opened the UPI app (or the admin) reports what it said.
  if not (private.is_admin() or (v.created_by = (select auth.uid()) and private.is_my_child(v.child_id))) then raise exception 'Payment not found.'; end if;
  if v.status <> 'initiated' then return jsonb_build_object('status', v.status, 'receipt_no', v.receipt_no); end if;

  select coalesce(jsonb_object_agg(lower(btrim(split_part(x, '=', 1))), btrim(substr(x, position('=' in x) + 1))), '{}'::jsonb) into kv
  from unnest(string_to_array(coalesce(p_response, ''), '&')) x where position('=' in x) > 1;
  v_status := upper(coalesce(kv->>'status', ''));
  v_ref := nullif(kv->>'txnref', '');
  v_utr := upper(nullif(kv->>'approvalrefno', ''));
  if v_utr is not null and v_utr !~ '^[A-Z0-9]{6,35}$' then v_utr := null; end if;
  v_txn := nullif(kv->>'txnid', '');
  if v_txn is not null and v_txn !~ '^[A-Za-z0-9._-]{4,64}$' then v_txn := null; end if;

  update public.fee_payments set upi_response = left(coalesce(p_response, ''), 2000), upi_app = left(nullif(btrim(p_app), ''), 120) where id = v.id;

  -- A reply naming another of our payments is never accepted. (On a personal UPI ID any other txnRef is the app's own.)
  if v_ref is not null and v_ref <> v.txn_ref and exists (select 1 from public.fee_payments p where p.txn_ref = v_ref) then
    update public.fee_payments set status = 'failed', note = 'The UPI app replied for a different transaction.', resolved_at = now() where id = v.id;
    return jsonb_build_object('status', 'failed', 'reason', 'mismatch');
  end if;

  if v_status in ('FAILURE', 'FAILED') then
    update public.fee_payments set status = 'failed', resolved_at = now() where id = v.id;
    return jsonb_build_object('status', 'failed', 'reason', 'declined');
  end if;
  if v_status not in ('SUCCESS', 'SUBMITTED', 'PENDING') then
    return jsonb_build_object('status', 'initiated', 'reason', 'unknown');
  end if;

  v_burned := private.ref_burned(v_utr, v_txn, v.id);
  if v_burned is not null then
    update public.fee_payments set status = 'failed', note = v_burned, resolved_at = now() where id = v.id;
    return jsonb_build_object('status', 'failed', 'reason', 'duplicate');
  end if;

  v_fresh := now() - v.created_at <= interval '30 minutes';
  -- Merchant links carry our reference and the app must echo it; personal links can't carry one.
  -- (coalesce: a missing txnRef must count as "not linked", never as unknown.)
  v_linked := coalesce(v.payee_kind, 'personal') = 'personal' or coalesce(v_ref = v.txn_ref, false);
  v_why := case
    when v_status <> 'SUCCESS' then 'The UPI app said the payment is still processing.'
    when v_utr is null or v_utr !~ '^[0-9]{12}$' then 'The UPI app said paid but gave no bank reference.'
    when not v_fresh then 'The UPI app''s reply came more than 30 minutes after the payment started.'
    when not v_linked then 'The UPI app''s reply didn''t carry this payment''s reference.'
  end;

  begin
    if v_why is null then
      v_no := nextval('public.receipt_no_seq');
      update public.fee_payments set status = 'confirmed', utr = v_utr, upi_txn_id = v_txn, verified_by = 'upi_app', paid_on = private.today(),
        receipt_no = v_no, resolved_at = now() where id = v.id;
      return jsonb_build_object('status', 'confirmed', 'receipt_no', v_no);
    end if;
    update public.fee_payments set status = 'verifying', utr = v_utr, upi_txn_id = v_txn, note = v_why where id = v.id;
    return jsonb_build_object('status', 'verifying', 'reason', v_why);
  exception when unique_violation then
    -- Another payment took the same reference at the same moment.
    update public.fee_payments set status = 'failed', note = 'This UPI reference was already used for another payment.', resolved_at = now() where id = v.id;
    return jsonb_build_object('status', 'failed', 'reason', 'duplicate');
  end;
end $$;

-- The parent paid but the UPI app didn't say so: they give the bank reference and the admin confirms it.
create or replace function public.submit_upi_reference(p_payment uuid, p_utr text) returns void
language plpgsql security definer set search_path = '' as $$
declare v public.fee_payments; v_utr text := upper(regexp_replace(coalesce(p_utr, ''), '[^A-Za-z0-9]', '', 'g')); v_burned text;
begin
  select * into v from public.fee_payments where id = p_payment for update;
  if not found or not (private.is_admin() or private.is_my_child(v.child_id)) then raise exception 'Payment not found.'; end if;
  if v.status <> 'initiated' then raise exception 'This payment has already been settled.'; end if;
  if v_utr !~ '^[A-Z0-9]{6,35}$' then raise exception 'Enter the UPI reference number (UTR) shown in your UPI app.'; end if;
  v_burned := private.ref_burned(v_utr, null, v.id);
  if v_burned is not null then raise exception '%', v_burned; end if;
  begin
    update public.fee_payments set status = 'verifying', utr = v_utr, note = 'The family entered the UPI reference.' where id = v.id;
  exception when unique_violation then
    raise exception 'This UPI reference was already used for another payment.';
  end;
end $$;

-- ============================================================ 6. the admin's side
-- confirm / reject a payment waiting for verification, reverse a confirmed one found to be invalid, or
-- reconcile: tick off an app-confirmed payment once it is seen in the bank.
create or replace function public.review_payment(p_payment uuid, p_action text, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare v public.fee_payments;
begin
  perform private.require_admin();
  select * into v from public.fee_payments where id = p_payment for update;
  if not found then raise exception 'Payment not found.'; end if;
  perform private.lock_week(v.child_id, v.week_start);
  if p_action = 'confirm' and v.status in ('verifying', 'initiated') then
    -- The admin has checked the bank, so an earlier rejection of this reference doesn't block them; a
    -- reference already counted for another payment still does (unique index).
    begin
      update public.fee_payments set status = 'confirmed', verified_by = 'admin', paid_on = private.today(),
        receipt_no = nextval('public.receipt_no_seq'), resolved_at = now(), resolved_by = (select auth.uid()),
        reconciled_at = now(), reconciled_by = (select auth.uid()),
        note = coalesce(nullif(btrim(p_note), ''), note) where id = v.id;
    exception when unique_violation then
      raise exception 'This UPI reference is already counted for another payment, so this one can''t be confirmed. Reject it instead.';
    end;
  elsif p_action = 'reject' and v.status in ('verifying', 'initiated') then
    update public.fee_payments set status = 'failed', resolved_at = now(), resolved_by = (select auth.uid()),
      note = coalesce(nullif(btrim(p_note), ''), 'Not received by the centre.') where id = v.id;
  elsif p_action = 'reconcile' and v.status = 'confirmed' then
    update public.fee_payments set reconciled_at = coalesce(reconciled_at, now()), reconciled_by = coalesce(reconciled_by, (select auth.uid())) where id = v.id;
  elsif p_action = 'reverse' and v.status = 'confirmed' then
    if length(btrim(coalesce(p_note, ''))) = 0 then raise exception 'Say why this payment is being reversed.'; end if;
    update public.fee_payments set status = 'reversed', resolved_at = now(), resolved_by = (select auth.uid()), note = btrim(p_note) where id = v.id;
  else
    raise exception 'This payment can''t be changed that way any more.';
  end if;
end $$;

-- Money received at the centre (cash, bank transfer, ...). Never more than is still due, and never while a
-- UPI payment for the week is open: it might go through too, and the family would pay twice.
create or replace function public.record_payment(p_child uuid, p_week date, p_amount numeric, p_method text, p_note text, p_paid_on date)
returns uuid language plpgsql security definer set search_path = '' as $$
declare b record; v_id uuid; v_due numeric;
begin
  perform private.require_admin();
  if p_week is null or extract(isodow from p_week) <> 1 then raise exception 'Choose a week.'; end if;
  if coalesce(p_amount, 0) <= 0 then raise exception 'Enter an amount greater than zero.'; end if;
  if p_paid_on is not null and p_paid_on > private.today() then raise exception 'The date received can''t be in the future.'; end if;
  perform private.lock_week(p_child, p_week);
  if exists (select 1 from public.fee_payments where child_id = p_child and week_start = p_week and status = 'initiated') then
    raise exception 'A UPI payment for this week is in progress. Confirm or reject it in Fees → Verify payments first.';
  end if;
  select * into b from private.week_bill(p_child, p_week);
  v_due := b.amount - b.paid - b.verifying;
  if p_amount > v_due then
    raise exception 'Only ₹% is due for this week.', to_char(greatest(v_due, 0), 'FM999G999G990D00');
  end if;
  insert into public.fee_payments (child_id, week_start, amount, method, status, txn_ref, verified_by, note, paid_on, receipt_no,
    created_by, resolved_at, resolved_by, reconciled_at, reconciled_by)
  values (p_child, p_week, round(p_amount, 2), coalesce(nullif(btrim(p_method), ''), 'Cash'), 'confirmed', private.new_txn_ref(), 'admin',
    btrim(coalesce(p_note, '')), coalesce(p_paid_on, private.today()), nextval('public.receipt_no_seq'),
    (select auth.uid()), now(), (select auth.uid()), now(), (select auth.uid()))
  returning id into v_id;
  return v_id;
end $$;

-- ============================================================ 7. money records are never deleted
-- Deleting a child used to cascade away their payments and receipts. A child with any money record is
-- deactivated instead; failed and cancelled attempts alone don't count.
create or replace function private.guard_child_payments() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.fee_payments p where p.child_id = old.id and p.status in ('initiated', 'verifying', 'confirmed', 'reversed')) then
    raise exception '% has fee payments on record, so they can''t be deleted. Mark them inactive instead.', old.name;
  end if;
  return old;
end $$;
create trigger child_payments_guard before delete on public.children for each row execute function private.guard_child_payments();

-- ============================================================ 8. access
-- Payments change only through the functions above. Writes and TRUNCATE (which RLS doesn't cover) are
-- taken away from the API roles so a missing policy can never open them up.
revoke insert, update, delete, truncate, references, trigger on public.fee_payments from anon, authenticated;
revoke truncate, references, trigger on public.upi_accounts from anon, authenticated;
revoke all on public.fee_payments, public.upi_accounts from anon;
revoke execute on function private.ref_burned(text, text, uuid), private.upi_vpa_normalise(), private.guard_child_payments() from public, anon, authenticated;

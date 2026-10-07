-- UPI links are person-to-person: the centre's UPI ID is a personal account, and apps reject merchant
-- fields (`tr`) for those. Without `tr` the app fills the reply's txnRef with its own number, so a txnRef
-- that isn't ours no longer means "wrong transaction". Only a reply that names a *different payment of
-- ours* is refused; the UTR duplicate check still stops one bank payment being used twice.
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

  -- A reply naming another of our payments is never accepted. (Any other txnRef is the UPI app's own.)
  if v_ref is not null and v_ref <> v.txn_ref and exists (select 1 from public.fee_payments p where p.txn_ref = v_ref) then
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

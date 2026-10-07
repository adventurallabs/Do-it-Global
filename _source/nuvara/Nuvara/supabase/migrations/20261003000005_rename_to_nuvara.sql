-- The app is now Nuvara. Everything that still carried the old "New Life" name moves over in one go:
-- * Login emails: parents child-N@parent.nuvara.app, therapists tNNNNNNNNNN@therapist.nuvara.app (the app and
--   the accounts Edge Function derive the same addresses from what people type), test admin admin@nuvara.test.
--   Passwords, sessions and user IDs are unchanged, so nobody has to sign in again or reset anything.
-- * The payee name on the UPI IDs and on past payments.
-- * New payment references start with NV (references already sent to banks keep their NL prefix, so they still
--   match the bank statements).
-- * An internal setting name used while a therapist rates a session.

-- ============================================================ 1. logins
create or replace function pg_temp.nuvara_email(e text) returns text language sql immutable as $$
  select replace(replace(replace(e, '@parent.newlife.app', '@parent.nuvara.app'), '@therapist.newlife.app', '@therapist.nuvara.app'),
    'admin@newlife.test', 'admin@nuvara.test')
$$;

update auth.users set
  email = pg_temp.nuvara_email(email),
  raw_user_meta_data = case when raw_user_meta_data ? 'email'
    then jsonb_set(raw_user_meta_data, '{email}', to_jsonb(pg_temp.nuvara_email(raw_user_meta_data->>'email'))) else raw_user_meta_data end
where email like '%newlife%';

update auth.identities set identity_data = jsonb_set(identity_data, '{email}', to_jsonb(pg_temp.nuvara_email(identity_data->>'email')))
where identity_data->>'email' like '%newlife%';

update public.profiles set email = pg_temp.nuvara_email(email) where email like '%newlife%';
update public.admin_allowlist set email = 'admin@nuvara.test' where email = 'admin@newlife.test';

-- ============================================================ 2. payee name
update public.upi_accounts set payee_name = 'Nuvara' where payee_name ilike 'new life%';
update public.fee_payments set payee_name = 'Nuvara' where payee_name ilike 'new life%';

-- ============================================================ 3. payment references
create or replace function private.new_txn_ref() returns text language sql volatile set search_path = '' as
$$ select 'NV' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 18)) $$;

-- ============================================================ 4. rating permission flag
create or replace function private.guard_seat_update() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_week date; v_committed numeric;
begin
  if new.rating is distinct from old.rating and new.rating is not null and current_setting('nuvara.rating_ok', true) is distinct from 'on' then
    raise exception 'Only the session''s therapist can rate a session.';
  end if;
  if old.attendance in ('present', 'late') then
    v_week := date_trunc('week', lower(old.during))::date;
    v_committed := private.week_committed(old.child_id, v_week);
    if v_committed > 0 and private.week_attended_amount(old.child_id, v_week) < v_committed - 0.005 then
      raise exception '% has already paid % for this week, so this session can''t be changed to not attended. Reverse or reject that payment in Fees first.',
        (select c.name from public.children c where c.id = old.child_id), private.money_text(v_committed);
    end if;
  end if;
  return new;
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
  if p_rating is not null and coalesce(v.attendance, '') not in ('present', 'late') then
    raise exception 'Mark the child present or late before rating the session.';
  end if;
  perform set_config('nuvara.rating_ok', 'on', true);
  update public.session_children set
    rating = p_rating,
    rated_at = case when p_rating is null then null else now() end,
    note = case when p_note is null then note else btrim(p_note) end
  where session_id = p_session and child_id = p_child;
  perform set_config('nuvara.rating_ok', 'off', true);
end $$;

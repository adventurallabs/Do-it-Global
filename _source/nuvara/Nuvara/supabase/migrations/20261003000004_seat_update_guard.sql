-- Direct edits of a seat (the admin's table access) follow the same rules as the app's functions:
-- * a week's bill can never drop below what was paid (or is being paid) for it, and
-- * ratings are the session therapist's: they change only through rate_session (or are cleared with the attendance).
create or replace function private.guard_seat_update() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_week date; v_committed numeric;
begin
  if new.rating is distinct from old.rating and new.rating is not null and current_setting('nl.rating_ok', true) is distinct from 'on' then
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
drop trigger if exists seat_update_guard on public.session_children;
create constraint trigger seat_update_guard after update on public.session_children
  deferrable initially immediate for each row execute function private.guard_seat_update();
revoke execute on function private.guard_seat_update() from public, anon, authenticated;

-- rate_session marks its own update as allowed.
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
  perform set_config('nl.rating_ok', 'on', true);
  update public.session_children set
    rating = p_rating,
    rated_at = case when p_rating is null then null else now() end,
    note = case when p_note is null then note else btrim(p_note) end
  where session_id = p_session and child_id = p_child;
  perform set_config('nl.rating_ok', 'off', true);
end $$;

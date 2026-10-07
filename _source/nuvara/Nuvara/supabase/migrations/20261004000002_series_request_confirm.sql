-- A "Regularly" (series) change request answers for the later sessions it will move too.
--
-- resolve_reschedule moves, for a pending request with scope 'series', the original session and every later
-- upcoming session of the same child with the same therapist, therapy, start and end time (on a later date).
-- Those later seats are already answered by the request, so "Confirm all" must not confirm them behind the
-- family's back: confirm_sessions now skips any seat covered by such a request, as well as seats with a
-- request of their own. The app mirrors this rule in AppStore.requestCovering.

create or replace function public.confirm_sessions(p_child uuid, p_sessions uuid[]) returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  if not (private.is_admin() or private.is_my_child(p_child)) then raise exception 'You can only confirm your own child''s sessions.'; end if;
  update public.session_children sc set confirmed_at = now()
  where sc.child_id = p_child and sc.session_id = any (coalesce(p_sessions, '{}'))
    and sc.confirmed_at is null and sc.absence_reason is null
    and lower(sc.during) > private.now_ist()
    and not exists (select 1 from public.reschedule_requests r where r.child_id = p_child and r.session_id = sc.session_id and r.status = 'pending')
    -- A later session of a series a pending "Regularly" request will move (the same rule as resolve_reschedule).
    and not exists (
      select 1 from public.reschedule_requests r
      join public.sessions src on src.id = r.session_id
      join public.timetable_slots sts on sts.id = src.slot_id
      join public.sessions s on s.id = sc.session_id
      join public.timetable_slots ts on ts.id = s.slot_id
      where r.child_id = p_child and r.status = 'pending' and r.scope = 'series'
        and s.therapist_id = src.therapist_id and s.therapy_id = src.therapy_id
        and ts.start_time = sts.start_time and ts.end_time = sts.end_time and ts.slot_date > sts.slot_date);
  get diagnostics n = row_count;
  return n;
end $$;

-- create or replace keeps the existing grants; restated so this file stands on its own.
revoke execute on function public.confirm_sessions(uuid, uuid[]) from public, anon;
grant execute on function public.confirm_sessions(uuid, uuid[]) to authenticated;

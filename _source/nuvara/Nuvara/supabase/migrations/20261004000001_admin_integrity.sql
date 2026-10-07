-- Admin integrity fixes (QA round, 2026-10-04).
--
-- * A family's pending request to move a session is turned down, with a note telling them why, when the centre
--   deletes that session (or its time slot). Before, the request kept pointing at nothing and stayed "waiting".
--   Seats moved away by an approved request are left alone: by then the child has no seat in the old session.
-- * A therapist can't be marked inactive while they still have sessions ahead: those sessions would keep an
--   inactive therapist that nobody can pick or move them to. The app checks first; this is the backstop.
-- * remove_child_from_sessions: takes a child out of upcoming sessions in one step (used before marking a child
--   inactive, so seats that would still be billed don't linger). Sessions left without children are deleted.
-- * copy_week no longer copies sessions whose children are all inactive (they used to come over empty).

-- ============================================================ 1. deleting a session answers its requests
create or replace function private.reject_requests_of_deleted_session() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.reschedule_requests r
  set status = 'rejected',
      admin_note = 'The centre removed this session from the timetable, so there is nothing to move. Check the schedule for your child''s sessions.',
      resolved_at = now(),
      resolved_by = (select auth.uid())
  where r.session_id = old.id and r.status = 'pending'
    -- Only children still seated here: a seat moved away by resolve_reschedule (move_seat) has gone already.
    and exists (select 1 from public.session_children sc where sc.session_id = old.id and sc.child_id = r.child_id);
  return old;
end $$;
drop trigger if exists session_deleted_rejects_requests on public.sessions;
-- BEFORE: the seats are still there (they cascade away after the session row goes).
create trigger session_deleted_rejects_requests before delete on public.sessions
  for each row execute function private.reject_requests_of_deleted_session();

-- ============================================================ 2. no retiring a therapist with sessions ahead
create or replace function private.guard_therapist_retire() returns trigger
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  if old.active and not new.active then
    select count(*) into n from public.sessions s where s.therapist_id = new.id and lower(s.during) > private.now_ist();
    if n > 0 then
      raise exception '% still has % upcoming %. Give them to another therapist (or remove them), then mark them as inactive.',
        new.name, n, case when n = 1 then 'session' else 'sessions' end;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists therapist_retire_guard on public.therapists;
create trigger therapist_retire_guard before update of active on public.therapists
  for each row execute function private.guard_therapist_retire();

-- ============================================================ 3. taking a child out of upcoming sessions
-- Admin: removes [p_child] from those of [p_sessions] that haven't started and aren't marked. Their pending
-- requests for those sessions are turned down; a session left with no children is deleted. Returns how many
-- sessions the child left.
create or replace function public.remove_child_from_sessions(p_child uuid, p_sessions uuid[]) returns int
language plpgsql security definer set search_path = '' as $$
declare v_ids uuid[]; n int;
begin
  perform private.require_admin();
  select coalesce(array_agg(sc.session_id), '{}') into v_ids from public.session_children sc
  where sc.child_id = p_child and sc.session_id = any (coalesce(p_sessions, '{}'))
    and sc.attendance is null and lower(sc.during) > private.now_ist();
  update public.reschedule_requests
  set status = 'rejected', admin_note = 'The centre took your child out of this session, so there is nothing to move.',
      resolved_at = now(), resolved_by = (select auth.uid())
  where child_id = p_child and session_id = any (v_ids) and status = 'pending';
  delete from public.session_children where child_id = p_child and session_id = any (v_ids);
  get diagnostics n = row_count;
  delete from public.sessions s where s.id = any (v_ids) and not exists (select 1 from public.session_children sc where sc.session_id = s.id);
  return n;
end $$;
revoke execute on function public.remove_child_from_sessions(uuid, uuid[]) from public, anon;
grant execute on function public.remove_child_from_sessions(uuid, uuid[]) to authenticated;

-- ============================================================ 4. copy_week skips sessions with nobody left
-- Same as 20261002000001, except a session is copied only if at least one of its children is still active.
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
      and exists (select 1 from public.session_children sc join public.children c on c.id = sc.child_id and c.active where sc.session_id = s.id)
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

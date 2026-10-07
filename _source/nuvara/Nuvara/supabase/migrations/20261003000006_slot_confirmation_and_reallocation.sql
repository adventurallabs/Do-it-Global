-- Families confirm the sessions the centre plans for their child, or ask for another slot.
--
-- * Every seat starts unconfirmed. The parent confirms it (one session, or every open one in a week at once),
--   reports the child away, or asks for a re-allocation. "Confirm all" never touches a seat that is marked away
--   or has a request waiting, so a bulk tap can't quietly undo either.
-- * A seat needs confirming again when the centre changes what the family agreed to: a new therapist on the
--   session, or a move to a different time.
-- * A re-allocation request can name an existing session to join: an upcoming session of the same therapy on
--   the same day (families can't read other sessions, so `reschedule_options` lists them without other
--   children's details). Otherwise the parent suggests a time. "For this day" moves one session, "Regularly"
--   moves this one and the later ones at the same time.
-- * Asking un-confirms the seat. When the centre approves exactly what was asked, the new seat is confirmed;
--   when it chooses another time or therapist, the family confirms the new slot themselves.
-- * The admin can move the child into another therapist's session, or create one for them, in the same slot.
--   (move_seat used to skip a move within the same slot even when the therapist changed.)

-- ============================================================ 1. columns
alter table public.session_children add column confirmed_at timestamptz;

alter table public.reschedule_requests
  add column target_session_id uuid references public.sessions(id) on delete set null,
  add column target_therapist_id uuid references public.therapists(id) on delete set null,
  add column new_therapist_id uuid references public.therapists(id) on delete set null;

-- Seats already in the past or attended don't need a confirmation; mark them so counts start clean.
update public.session_children set confirmed_at = now() where lower(during) <= private.now_ist() or attendance is not null;

-- ============================================================ 2. confirming
-- Confirms [p_sessions] for [p_child]: only seats that haven't started, aren't marked away and have no request
-- waiting. Returns how many were confirmed.
create or replace function public.confirm_sessions(p_child uuid, p_sessions uuid[]) returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  if not (private.is_admin() or private.is_my_child(p_child)) then raise exception 'You can only confirm your own child''s sessions.'; end if;
  update public.session_children sc set confirmed_at = now()
  where sc.child_id = p_child and sc.session_id = any (coalesce(p_sessions, '{}'))
    and sc.confirmed_at is null and sc.absence_reason is null
    and lower(sc.during) > private.now_ist()
    and not exists (select 1 from public.reschedule_requests r where r.child_id = p_child and r.session_id = sc.session_id and r.status = 'pending');
  get diagnostics n = row_count;
  return n;
end $$;

-- ============================================================ 3. what a family may move into
-- Upcoming sessions of the same therapy on the same day as [p_session], that [p_child] isn't in and that don't
-- clash with the child's other sessions. Only what a family needs to choose: no other children.
create or replace function public.reschedule_options(p_session uuid, p_child uuid)
returns table (session_id uuid, name text, therapist_id uuid, slot_date date, start_time time, end_time time)
language plpgsql stable security definer set search_path = '' as $$
declare src record;
begin
  if not (private.is_admin() or private.is_my_child(p_child)) then raise exception 'You can only ask for your own child.'; end if;
  select s.therapy_id, ts.slot_date into src from public.sessions s join public.timetable_slots ts on ts.id = s.slot_id
    join public.session_children sc on sc.session_id = s.id and sc.child_id = p_child where s.id = p_session;
  if not found then raise exception 'Your child is not in this session.'; end if;
  return query
    select s.id, s.name, s.therapist_id, ts.slot_date, ts.start_time, ts.end_time
    from public.sessions s join public.timetable_slots ts on ts.id = s.slot_id
    join public.therapists t on t.id = s.therapist_id and t.active
    where s.therapy_id = src.therapy_id and ts.slot_date = src.slot_date and s.id <> p_session
      and lower(s.during) > private.now_ist()
      and not exists (select 1 from public.session_children sc where sc.session_id = s.id and sc.child_id = p_child)
      and not exists (select 1 from public.session_children sc where sc.child_id = p_child and sc.session_id <> p_session and sc.during && s.during)
    order by ts.start_time, s.name;
end $$;

-- ============================================================ 4. asking
drop function if exists public.request_reschedule(uuid, uuid, text, date, time, time, text);
create or replace function public.request_reschedule(p_session uuid, p_child uuid, p_scope text, p_target uuid, p_date date, p_start time, p_end time, p_reason text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v record; t record; v_id uuid; v_target_therapist uuid;
begin
  if not (private.is_admin() or private.is_my_child(p_child)) then raise exception 'You can only ask for your own child.'; end if;
  if p_scope not in ('once', 'series') then raise exception 'Choose whether this is for this day only or regularly.'; end if;
  select s.name, s.therapist_id, s.therapy_id, s.during, ts.slot_date, ts.start_time, ts.end_time into v
  from public.sessions s join public.timetable_slots ts on ts.id = s.slot_id
  join public.session_children sc on sc.session_id = s.id and sc.child_id = p_child where s.id = p_session;
  if not found then raise exception 'Your child is not in this session.'; end if;
  if lower(v.during) <= private.now_ist() then raise exception 'This session has already started.'; end if;
  if p_target is not null then
    select o.therapist_id, o.slot_date, o.start_time, o.end_time into t from public.reschedule_options(p_session, p_child) o where o.session_id = p_target;
    if not found then raise exception 'That session is no longer available. Pick another one or suggest a time.'; end if;
    p_date := t.slot_date; p_start := t.start_time; p_end := t.end_time; v_target_therapist := t.therapist_id;
  else
    if p_start is null then raise exception 'Choose a time that suits you.'; end if;
    if p_end is null or p_end <= p_start then raise exception 'The end time must be after the start time.'; end if;
    if p_scope = 'series' then p_date := null; end if;
    if p_date is not null and p_date < private.today() then raise exception 'Choose a day from today on.'; end if;
    if p_date is not null and (p_date + p_start) <= private.now_ist() then raise exception 'Choose a time that is still ahead.'; end if;
  end if;
  begin
    insert into public.reschedule_requests (child_id, session_id, scope, from_date, from_start, from_end, session_name, therapist_id, therapy_id,
      target_session_id, target_therapist_id, preferred_date, preferred_start, preferred_end, reason, created_by)
    values (p_child, p_session, p_scope, v.slot_date, v.start_time, v.end_time, v.name, v.therapist_id, v.therapy_id,
      p_target, v_target_therapist, p_date, p_start, p_end, btrim(coalesce(p_reason, '')), (select auth.uid()))
    returning id into v_id;
  exception when unique_violation then
    raise exception 'You have already asked to change this session. The centre will reply soon.';
  end;
  -- The family isn't keeping this slot as it is.
  update public.session_children set confirmed_at = null where session_id = p_session and child_id = p_child;
  return v_id;
end $$;

-- ============================================================ 5. moving
drop function if exists private.move_seat(uuid, uuid, date, time, time);
-- Moves one child's seat to [p_therapist]'s session of the same therapy at a new date and time, joining a
-- session already there or creating one. The old session goes if nobody is left in it.
create or replace function private.move_seat(p_child uuid, p_session uuid, p_date date, p_start time, p_end time, p_therapist uuid, p_confirm boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare s record; v_slot uuid; v_target uuid;
begin
  select x.id, x.name, x.therapist_id, x.therapy_id, x.slot_id, x.during into s from public.sessions x where x.id = p_session;
  if not found then raise exception 'The session to move no longer exists.'; end if;
  if lower(s.during) <= private.now_ist() then raise exception 'A session that has started can''t be moved.'; end if;
  if (p_date + p_start) <= private.now_ist() then raise exception 'The new time must be in the future.'; end if;
  if not exists (select 1 from public.therapists where id = p_therapist and active) then raise exception 'Choose an active therapist.'; end if;
  insert into public.timetable_slots (slot_date, start_time, end_time) values (p_date, p_start, p_end) on conflict do nothing;
  select id into v_slot from public.timetable_slots where slot_date = p_date and start_time = p_start and end_time = p_end;
  if v_slot = s.slot_id and p_therapist = s.therapist_id then
    if p_confirm then update public.session_children set confirmed_at = now() where session_id = s.id and child_id = p_child; end if;
    return;
  end if;
  delete from public.session_children where session_id = s.id and child_id = p_child;
  delete from public.sessions x where x.id = s.id and not exists (select 1 from public.session_children sc where sc.session_id = s.id);
  select id into v_target from public.sessions where slot_id = v_slot and therapist_id = p_therapist and therapy_id = s.therapy_id limit 1;
  begin
    if v_target is null then
      insert into public.sessions (slot_id, name, therapist_id, therapy_id) values (v_slot, s.name, p_therapist, s.therapy_id) returning id into v_target;
    end if;
    insert into public.session_children (session_id, child_id, confirmed_at) values (v_target, p_child, case when p_confirm then now() end);
  exception when exclusion_violation then
    raise exception '%', private.clash_message(p_therapist, array[p_child], tsrange(p_date + p_start, p_date + p_end, '[)'), v_target);
  end;
end $$;

-- ============================================================ 6. answering
drop function if exists public.resolve_reschedule(uuid, boolean, date, time, time, text);
-- Admin: approve (moving the session, or every later one at the same time) or reject. All or nothing.
-- [p_therapist] null keeps the therapist the family picked (or the original one).
create or replace function public.resolve_reschedule(p_id uuid, p_approve boolean, p_date date, p_start time, p_end time, p_therapist uuid, p_note text)
returns int language plpgsql security definer set search_path = '' as $$
declare v public.reschedule_requests; src record; r record; n int := 0; v_offset int; v_therapist uuid; v_confirm boolean;
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
  v_therapist := coalesce(p_therapist, v.target_therapist_id, src.therapist_id);
  -- Exactly what the family asked for: no need for them to confirm it again.
  v_confirm := coalesce(v.preferred_start = p_start and v.preferred_end = p_end and (v.preferred_date is null or v.preferred_date = p_date)
    and v_therapist = coalesce(v.target_therapist_id, v_therapist), false);
  v_offset := p_date - src.slot_date;
  for r in
    select s.id, ts.slot_date from public.sessions s join public.timetable_slots ts on ts.id = s.slot_id
    join public.session_children sc on sc.session_id = s.id and sc.child_id = v.child_id
    where lower(s.during) > private.now_ist() and (
      s.id = src.id or (v.scope = 'series' and s.therapist_id = src.therapist_id and s.therapy_id = src.therapy_id
        and ts.start_time = src.start_time and ts.end_time = src.end_time and ts.slot_date > src.slot_date))
    order by ts.slot_date
  loop
    perform private.move_seat(v.child_id, r.id, r.slot_date + v_offset, p_start, p_end, v_therapist, v_confirm);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'Nothing left to move: the session has already started.'; end if;
  update public.reschedule_requests set status = 'approved', admin_note = btrim(coalesce(p_note, '')), moved = n,
    new_date = p_date, new_start = p_start, new_end = p_end, new_therapist_id = v_therapist, resolved_at = now(), resolved_by = (select auth.uid())
  where id = p_id;
  return n;
end $$;

-- ============================================================ 7. a new therapist means a new agreement
create or replace function public.update_session(p_session uuid, p_name text, p_therapist uuid, p_therapy uuid, p_children uuid[]) returns void
language plpgsql security definer set search_path = '' as $$
declare v_during tsrange; v_therapist uuid;
begin
  perform private.require_admin();
  if length(btrim(coalesce(p_name, ''))) = 0 then raise exception 'Enter a session name.'; end if;
  if coalesce(cardinality(p_children), 0) = 0 then raise exception 'Select at least one child.'; end if;
  if not exists (select 1 from public.therapies where id = p_therapy) then raise exception 'Select a therapy.'; end if;
  select during, therapist_id into v_during, v_therapist from public.sessions where id = p_session for update;
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
  if p_therapist is distinct from v_therapist and lower(v_during) > private.now_ist() then
    update public.session_children set confirmed_at = null where session_id = p_session;
  end if;
end $$;

-- ============================================================ 8. access
revoke execute on function public.confirm_sessions(uuid, uuid[]), public.reschedule_options(uuid, uuid),
  public.request_reschedule(uuid, uuid, text, uuid, date, time, time, text), public.resolve_reschedule(uuid, boolean, date, time, time, uuid, text),
  public.update_session(uuid, text, uuid, uuid, uuid[]) from public, anon;
grant execute on function public.confirm_sessions(uuid, uuid[]), public.reschedule_options(uuid, uuid),
  public.request_reschedule(uuid, uuid, text, uuid, date, time, time, text), public.resolve_reschedule(uuid, boolean, date, time, time, uuid, text),
  public.update_session(uuid, text, uuid, uuid, uuid[]) to authenticated;
revoke execute on function private.move_seat(uuid, uuid, date, time, time, uuid, boolean) from public, anon, authenticated;

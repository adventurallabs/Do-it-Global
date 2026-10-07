-- Session reports: the therapist rates (0–10) and describes every attended session. A session the child
-- attended stays "report pending" until its therapist has rated it, however late that is: ratings no longer
-- close 24 hours after the session, so nothing is left unreported for good.

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
  update public.session_children set
    rating = p_rating,
    rated_at = case when p_rating is null then null else now() end,
    note = case when p_note is null then note else btrim(p_note) end
  where session_id = p_session and child_id = p_child;
end $$;

-- Every session of a child with attendance marked (attended, absent, rated or still waiting for its
-- report), plus any noted one, oldest first: the progress charts and the day-by-day view.
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
  where sc.child_id = p_child and (sc.attendance is not null or sc.rating is not null or btrim(sc.note) <> '')
  order by ts.slot_date, ts.start_time;
end $$;

-- Attended sessions still waiting for their report: a therapist sees their own, the admin everyone's.
create or replace function public.pending_reports()
returns table (session_id uuid, child_id uuid, day date, start_time time, end_time time, session_name text, therapy_id uuid, therapist_id uuid)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare v_admin boolean := private.is_admin(); v_me uuid := private.my_therapist_id();
begin
  if not v_admin and v_me is null then raise exception 'Only therapists and the centre see session reports.'; end if;
  return query
  select s.id, sc.child_id, ts.slot_date, ts.start_time, ts.end_time, s.name, s.therapy_id, s.therapist_id
  from public.session_children sc join public.sessions s on s.id = sc.session_id join public.timetable_slots ts on ts.id = s.slot_id
  where sc.attendance in ('present', 'late') and sc.rating is null and lower(s.during) <= private.now_ist()
    and (v_admin or s.therapist_id = v_me)
  order by ts.slot_date, ts.start_time;
end $$;
revoke execute on function public.pending_reports() from public, anon;
grant execute on function public.pending_reports() to authenticated;

create index if not exists session_children_pending_idx on public.session_children (session_id) where attendance in ('present', 'late') and rating is null;

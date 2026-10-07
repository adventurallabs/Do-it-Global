-- Parents see only sessions their child is in; staff see the timetable.
drop policy "Read" on public.sessions;
create policy "Read" on public.sessions for select to authenticated using (
  (select private.is_admin()) or (select private.my_therapist_id()) is not null
  or exists (select 1 from public.session_children sc where sc.session_id = id and private.is_my_child(sc.child_id))
);

-- A therapist may only change levels in therapies they deliver, for children in their sessions.
create or replace function public.set_level(p_child uuid, p_therapy uuid, p_level int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not (private.is_admin() or (
    private.therapist_has_child(p_child)
    and exists (select 1 from public.therapist_therapies tt where tt.therapist_id = private.my_therapist_id() and tt.therapy_id = p_therapy)
  )) then
    raise exception 'You can only update levels in your own therapies for children in your sessions.';
  end if;
  update public.child_therapies set level = least(100, greatest(0, p_level)) where child_id = p_child and therapy_id = p_therapy;
  if not found then raise exception 'This child does not take that therapy.'; end if;
end $$;

-- Attendance opens 15 minutes before the session starts, and a missing session is an error.
create or replace function public.mark_attendance(p_session uuid, p_children uuid[], p_status text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_start timestamp;
begin
  if not private.can_run_session(p_session) then raise exception 'Only this session''s therapist or the admin can mark attendance.'; end if;
  if p_status is not null and p_status not in ('present', 'late', 'absent') then raise exception 'Unknown attendance status.'; end if;
  select lower(during) into v_start from public.sessions where id = p_session;
  if v_start is null then raise exception 'This session no longer exists.'; end if;
  if v_start - interval '15 minutes' > (now() at time zone 'Asia/Kolkata') then
    raise exception 'Attendance opens 15 minutes before the session starts.';
  end if;
  update public.session_children set attendance = p_status, marked_at = case when p_status is null then null else now() end
  where session_id = p_session and child_id = any (p_children);
  if not found then raise exception 'These children are not in this session.'; end if;
end $$;

-- Editing a child keeps the levels therapists recorded unless the admin sent a new value.
-- Items in p_therapies: {"therapy_id": uuid, "level": int?}; omit "level" to keep the current one.
create or replace function public.save_child(
  p_id uuid, p_name text, p_dob date, p_father text, p_mother text, p_phone text, p_alt_phone text,
  p_fee_override numeric, p_therapies jsonb
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := p_id;
begin
  perform private.require_admin();
  if length(btrim(coalesce(p_name, ''))) = 0 then raise exception 'Enter the child''s name.'; end if;
  if p_dob is null or p_dob > private.today() then raise exception 'Enter a valid date of birth.'; end if;
  if length(private.digits10(p_phone)) <> 10 then raise exception 'Enter a valid 10-digit contact number.'; end if;
  if jsonb_array_length(coalesce(p_therapies, '[]')) = 0 then raise exception 'Select at least one therapy.'; end if;
  if v_id is null then
    insert into public.children (name, dob, father_name, mother_name, phone, alt_phone, fee_override)
    values (btrim(p_name), p_dob, btrim(coalesce(p_father, '')), btrim(coalesce(p_mother, '')), btrim(p_phone), btrim(coalesce(p_alt_phone, '')), p_fee_override)
    returning id into v_id;
  else
    update public.children set name = btrim(p_name), dob = p_dob, father_name = btrim(coalesce(p_father, '')),
      mother_name = btrim(coalesce(p_mother, '')), phone = btrim(p_phone), alt_phone = btrim(coalesce(p_alt_phone, '')),
      fee_override = p_fee_override
    where id = v_id;
    if not found then raise exception 'Child not found.'; end if;
    delete from public.child_therapies ct where ct.child_id = v_id
      and ct.therapy_id not in (select (x->>'therapy_id')::uuid from jsonb_array_elements(p_therapies) x);
  end if;
  insert into public.child_therapies (child_id, therapy_id, level)
  select v_id, (x->>'therapy_id')::uuid, least(100, greatest(0, coalesce((x->>'level')::int, 0)))
  from jsonb_array_elements(p_therapies) x
  on conflict (child_id, therapy_id) do nothing;
  update public.child_therapies ct set level = least(100, greatest(0, (x->>'level')::int))
  from jsonb_array_elements(p_therapies) x
  where ct.child_id = v_id and ct.therapy_id = (x->>'therapy_id')::uuid and x ? 'level' and ct.level <> (x->>'level')::int;
  perform private.sync_fee(v_id);
  return v_id;
end $$;

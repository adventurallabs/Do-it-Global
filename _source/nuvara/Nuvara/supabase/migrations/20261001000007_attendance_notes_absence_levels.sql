-- Per-child record of each dated session: attendance, the therapist's note (shared with the family),
-- and an absence notice a parent can send ahead of time.
alter table public.session_children
  add column attendance text check (attendance in ('present', 'late', 'absent')),
  add column marked_at timestamptz,
  add column note text not null default '' check (length(note) <= 1000),
  add column absence_reason text check (length(absence_reason) <= 300),
  add column absence_at timestamptz;

-- Every change to a child's level, so progress can be charted over time.
create table public.child_level_history (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  therapy_id uuid not null references public.therapies(id) on delete cascade,
  level integer not null check (level between 0 and 100),
  recorded_at timestamptz not null default now(),
  recorded_by uuid references public.profiles(id) on delete set null
);
create index child_level_history_child_idx on public.child_level_history (child_id, recorded_at);
create index child_level_history_therapy_idx on public.child_level_history (therapy_id);

create or replace function private.log_level() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' or new.level is distinct from old.level then
    insert into public.child_level_history (child_id, therapy_id, level, recorded_by)
    values (new.child_id, new.therapy_id, new.level, (select auth.uid()));
  end if;
  return null;
end $$;
create trigger child_level_logged after insert or update of level on public.child_therapies
  for each row execute function private.log_level();

insert into public.child_level_history (child_id, therapy_id, level, recorded_at)
select child_id, therapy_id, level, created_at from public.child_therapies;

alter table public.child_level_history enable row level security;
create policy "Read" on public.child_level_history for select to authenticated
  using ((select private.is_admin()) or private.is_my_child(child_id) or private.therapist_has_child(child_id));
create policy "Admin delete" on public.child_level_history for delete to authenticated using ((select private.is_admin()));

create or replace function private.can_run_session(p_session uuid) returns boolean language sql stable security definer set search_path = '' as
$$ select private.is_admin() or private.is_my_session(p_session) $$;

create or replace function public.mark_attendance(p_session uuid, p_children uuid[], p_status text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_start timestamp;
begin
  if not private.can_run_session(p_session) then raise exception 'Only this session''s therapist or the admin can mark attendance.'; end if;
  if p_status is not null and p_status not in ('present', 'late', 'absent') then raise exception 'Unknown attendance status.'; end if;
  select lower(during) into v_start from public.sessions where id = p_session;
  if v_start::date > private.today() then raise exception 'Attendance can be marked from the day of the session.'; end if;
  update public.session_children set attendance = p_status, marked_at = case when p_status is null then null else now() end
  where session_id = p_session and child_id = any (p_children);
end $$;

create or replace function public.save_session_note(p_session uuid, p_child uuid, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.can_run_session(p_session) then raise exception 'Only this session''s therapist or the admin can add notes.'; end if;
  update public.session_children set note = btrim(coalesce(p_note, '')) where session_id = p_session and child_id = p_child;
  if not found then raise exception 'This child is not in the session.'; end if;
end $$;

create or replace function public.report_absence(p_session uuid, p_child uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_end timestamp;
begin
  if not (private.is_admin() or private.is_my_child(p_child)) then raise exception 'You can only report absence for your own child.'; end if;
  select upper(during) into v_end from public.sessions where id = p_session;
  if v_end is null then raise exception 'This session no longer exists.'; end if;
  if v_end < (now() at time zone 'Asia/Kolkata') then raise exception 'This session has already finished.'; end if;
  update public.session_children
    set absence_reason = case when p_reason is null then null else coalesce(nullif(btrim(p_reason), ''), 'Not attending') end,
        absence_at = case when p_reason is null then null else now() end
  where session_id = p_session and child_id = p_child;
  if not found then raise exception 'Your child is not in this session.'; end if;
end $$;

create or replace function public.set_level(p_child uuid, p_therapy uuid, p_level int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not (private.is_admin() or private.therapist_has_child(p_child)) then raise exception 'You can only update levels for children in your sessions.'; end if;
  update public.child_therapies set level = least(100, greatest(0, p_level)) where child_id = p_child and therapy_id = p_therapy;
  if not found then raise exception 'This child does not take that therapy.'; end if;
end $$;

revoke execute on function public.mark_attendance, public.save_session_note, public.report_absence, public.set_level from public, anon;
grant execute on function public.mark_attendance, public.save_session_note, public.report_absence, public.set_level to authenticated;
revoke execute on function private.log_level(), private.can_run_session(uuid) from public, anon;

alter publication supabase_realtime add table public.child_level_history;

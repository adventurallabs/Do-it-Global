-- Fixes from reviewing the assessment module.
--
-- 1. Deleting a therapist sets therapist_id to null on their assessments (on delete set null). The guard that keeps
--    a completed assessment complete took that for an edit and refused the delete. The therapist check now only
--    applies when the assessment had no therapist before the update; a therapist removed from the centre leaves
--    their completed assessments as they are.
-- 2. create_assessed_child attached any completed intake to whichever child was being created. It must now be the
--    same child: the name and date of birth on the form must match the assessment.
-- 3. create_assessment takes the name and date of birth typed on the Add child form, so starting an intake is one
--    step (before, a second call filled them in, and a dropped connection in between left blank drafts behind).

-- ============================================================ 1
create or replace function private.assessment_gaps(p_id uuid, p_require_therapist boolean default true) returns text
language plpgsql stable security definer set search_path = '' as $$
declare a public.assessments; gaps text[] := '{}';
begin
  select * into a from public.assessments where id = p_id;
  if p_require_therapist and a.therapist_id is null then gaps := gaps || 'Choose the therapist who did the assessment.'; end if;
  if a.assessment_date > private.today() then gaps := gaps || 'The assessment date is in the future.'; end if;
  if btrim(a.child_name) = '' then gaps := gaps || 'Enter the child''s name.'; end if;
  if a.dob is null then gaps := gaps || 'Enter the date of birth.';
  elsif a.dob > a.assessment_date then gaps := gaps || 'The date of birth is after the assessment date.'; end if;
  if a.gender is null then gaps := gaps || 'Select the gender.'; end if;
  if btrim(a.chief_complaints) = '' then gaps := gaps || 'Enter the chief complaints.'; end if;
  if a.surgery_date is not null and (a.surgery_date > private.today() or (a.dob is not null and a.surgery_date < a.dob)) then
    gaps := gaps || 'The date of surgery isn''t possible.';
  end if;
  if not exists (select 1 from public.assessment_problems p where p.assessment_id = p_id and btrim(p.problem) <> '' and btrim(p.treatment_plan) <> '') then
    gaps := gaps || 'Add at least one problem identified with its treatment plan.';
  end if;
  return nullif(array_to_string(gaps, E'\n'), '');
end $$;
drop function if exists private.assessment_gaps(uuid);

create or replace function private.guard_completed_assessment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_gaps text;
begin
  if new.status = 'completed' and old.status = 'completed' then
    v_gaps := private.assessment_gaps(new.id, old.therapist_id is null);
    if v_gaps is not null then raise exception 'A completed assessment must stay complete: %', v_gaps; end if;
  end if;
  return null;
end $$;

create or replace function public.complete_assessment(p_id uuid, p_rev integer) returns integer
language plpgsql security definer set search_path = '' as $$
declare a public.assessments; v_gaps text; v_rev integer;
begin
  if not private.can_edit_assessment(p_id) then raise exception 'You can''t complete this assessment.'; end if;
  select * into a from public.assessments where id = p_id for update;
  if p_rev is null or a.rev <> p_rev then raise exception 'ASSESSMENT_CONFLICT'; end if;
  v_gaps := private.assessment_gaps(p_id, true);
  if v_gaps is not null then raise exception '%', v_gaps; end if;
  update public.assessments set status = 'completed', completed_at = coalesce(completed_at, now()), completed_by = coalesce(completed_by, (select auth.uid())),
    rev = rev + 1, updated_at = now(), updated_by = (select auth.uid())
  where id = p_id returning rev into v_rev;
  return v_rev;
end $$;
revoke execute on function private.assessment_gaps(uuid, boolean) from public, anon;

-- ============================================================ 2
create or replace function public.create_assessed_child(p_assessment uuid, p_name text, p_dob date, p_father text, p_mother text,
  p_phone text, p_alt_phone text, p_therapies jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare a public.assessments; v_id uuid;
begin
  perform private.require_admin();
  if p_assessment is not null then
    select * into a from public.assessments where id = p_assessment for update;
    if not found then raise exception 'The assessment was not found. Attend the assessment again.'; end if;
    if a.child_id is not null then raise exception 'This assessment already belongs to a child.'; end if;
    if a.status <> 'completed' then raise exception 'Complete the assessment before creating the child.'; end if;
    if lower(regexp_replace(btrim(a.child_name), '\s+', ' ', 'g')) <> lower(regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g'))
       or a.dob is distinct from p_dob then
      raise exception 'This assessment is for % (born %). The name and date of birth on the form must match it.',
        a.child_name, coalesce(to_char(a.dob, 'DD Mon YYYY'), 'no date of birth');
    end if;
  end if;
  v_id := private.save_child_core(null, p_name, p_dob, p_father, p_mother, p_phone, p_alt_phone, p_therapies);
  update public.children set assessment_needed = p_assessment is not null where id = v_id;
  if p_assessment is not null then
    update public.assessments set child_id = v_id, rev = rev + 1, updated_at = now(), updated_by = (select auth.uid()) where id = p_assessment;
  end if;
  return v_id;
end $$;

-- ============================================================ 3
drop function if exists public.create_assessment(uuid, text, uuid, uuid);
create or replace function public.create_assessment(p_child uuid, p_kind text, p_therapist uuid, p_copy_from uuid default null,
  p_name text default null, p_dob date default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_admin boolean := private.is_admin();
  v_therapist uuid := p_therapist;
  v_id uuid;
  c public.children;
begin
  if p_child is null then
    if not v_admin then raise exception 'Only the centre admin can assess a new child.'; end if;
    if p_dob is not null and p_dob > private.today() then raise exception 'Enter a valid date of birth.'; end if;
  else
    if not (v_admin or private.therapist_has_child(p_child)) then raise exception 'You can only assess children in your sessions.'; end if;
    select * into c from public.children where id = p_child;
    if not found then raise exception 'Child not found.'; end if;
  end if;
  if not v_admin then v_therapist := private.my_therapist_id(); end if;
  if v_therapist is not null and not exists (select 1 from public.therapists where id = v_therapist and active) then
    raise exception 'Select an active therapist.';
  end if;
  if coalesce(p_kind, '') not in ('initial', 'reassessment', 'follow_up') then raise exception 'Choose the type of assessment.'; end if;

  insert into public.assessments (child_id, therapist_id, kind, child_name, dob, updated_by)
  values (p_child, v_therapist, p_kind,
    case when p_child is null then left(btrim(coalesce(p_name, '')), 120) else c.name end,
    case when p_child is null then p_dob else c.dob end,
    (select auth.uid()))
  returning id into v_id;

  if p_copy_from is not null then
    if p_child is null or not exists (select 1 from public.assessments where id = p_copy_from and child_id = p_child) then
      raise exception 'The earlier assessment belongs to another child.';
    end if;
    update public.assessments t set
      gender = s.gender, referred_by = s.referred_by, informant = s.informant, hand_dominance = s.hand_dominance,
      surgery = s.surgery, surgery_details = s.surgery_details, surgery_date = s.surgery_date,
      chief_complaints = s.chief_complaints, felt_needs = s.felt_needs, family_history = s.family_history,
      prenatal = s.prenatal, perinatal = s.perinatal, postnatal = s.postnatal,
      school_status = s.school_status, grade = s.grade, classroom_complaints = s.classroom_complaints,
      play_types = s.play_types, play_methods = s.play_methods, group_behaviour = s.group_behaviour,
      screen_hours = s.screen_hours, screen_minutes = s.screen_minutes, screen_content = s.screen_content,
      posture_anatomy = s.posture_anatomy, approaches = s.approaches, approach_tags = s.approach_tags,
      home_activities = s.home_activities, home_frequency = s.home_frequency, home_duration = s.home_duration,
      home_instructions = s.home_instructions, home_precautions = s.home_precautions,
      progress = s.progress, copied_from = s.id, status = 'in_progress'
    from public.assessments s where s.id = p_copy_from and t.id = v_id;
    insert into public.assessment_findings (assessment_id, domain, item, side, label, status, severity, age, frequency, duration,
      triggers, behaviour, arom, prom, strength, notes)
    select v_id, domain, item, side, label, status, severity, age, frequency, duration, triggers, behaviour, arom, prom, strength, notes
    from public.assessment_findings where assessment_id = p_copy_from;
    insert into public.assessment_problems (id, assessment_id, position, problem, treatment_plan)
    select gen_random_uuid(), v_id, position, problem, treatment_plan from public.assessment_problems where assessment_id = p_copy_from;
    insert into public.assessment_goals (id, assessment_id, term, position, description, target_date, status, source_goal_id)
    select gen_random_uuid(), v_id, term, position, description, target_date, status, id from public.assessment_goals where assessment_id = p_copy_from;
  end if;
  return v_id;
end $$;
revoke execute on function public.create_assessment(uuid, text, uuid, uuid, text, date) from public, anon;
grant execute on function public.create_assessment(uuid, text, uuid, uuid, text, date) to authenticated;

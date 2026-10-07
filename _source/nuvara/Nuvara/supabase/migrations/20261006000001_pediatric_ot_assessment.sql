-- Pediatric OT assessment (the centre's 5-page paper form, digitised).
--
-- * One child has many assessments; each is its own record and is never overwritten (re-assessments are new rows,
--   optionally pre-filled from an earlier one, with `copied_from` and goals' `source_goal_id` linking them so
--   progress can be compared later).
-- * (Changed in 20261006000003: Add child now asks whether an assessment is needed; children who had the paper
--   assessment are created without one.) A new child needing an assessment can't be created until it's completed: the admin attends it from the Add child form
--   while the child doesn't exist yet (`child_id` is null, an "intake" assessment), and `create_assessed_child`
--   creates the child and attaches it in one transaction. `save_child` now only edits existing children.
-- * Scalar answers are columns on `assessments`; rated items (milestones, behaviours, reflexes, ROM, ADL, …) are
--   rows in `assessment_findings`, keyed by (domain, item, side) so the same item lines up across assessments;
--   problems and goals are their own rows.
-- * Clients only read through RLS. Every write goes through the security-definer functions below, which check
--   who may edit what. Saves carry a revision number, so two devices never silently overwrite each other.

-- ============================================================ tables
create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  -- Null while it is the intake assessment of a child the admin hasn't created yet.
  child_id uuid references public.children(id) on delete cascade,
  therapist_id uuid references public.therapists(id) on delete set null,
  kind text not null default 'initial' check (kind in ('initial', 'reassessment', 'follow_up')),
  status text not null default 'draft' check (status in ('draft', 'in_progress', 'completed', 'archived')),
  assessment_date date not null default private.today(),
  rev integer not null default 1,
  progress smallint not null default 0 check (progress between 0 and 100),
  current_section text not null default 'demographics' check (char_length(current_section) <= 40),
  copied_from uuid references public.assessments(id) on delete set null,

  -- Demographic data
  child_name text not null default '',
  gender text check (gender in ('male', 'female', 'other')),
  dob date,
  referred_by text not null default '',
  informant text not null default '',
  hand_dominance text check (hand_dominance in ('right', 'left', 'ambidextrous', 'not_established', 'not_assessed')),
  surgery text check (surgery in ('yes', 'no')),
  surgery_details text not null default '',
  surgery_date date,
  chief_complaints text not null default '',
  felt_needs text not null default '',

  -- Family and medical history
  family_history text not null default '',
  prenatal text not null default '',
  perinatal text not null default '',
  postnatal text not null default '',

  -- Educational history
  school_status text check (school_status in ('regular', 'regular_integrated', 'special', 'not_school_going')),
  grade text not null default '',
  classroom_complaints text not null default '',

  -- Play
  play_types text[] not null default '{}',
  play_methods text[] not null default '{}',
  group_behaviour text check (group_behaviour in ('alone', 'some', 'with_others')),

  -- Screen time
  screen_hours smallint check (screen_hours between 0 and 24),
  screen_minutes smallint check (screen_minutes between 0 and 59),
  screen_content text not null default '',

  -- Posture
  posture_anatomy text not null default '',

  -- Approaches used and home program
  approaches text not null default '',
  approach_tags text[] not null default '{}',
  home_activities text not null default '',
  home_frequency text not null default '',
  home_duration text not null default '',
  home_instructions text not null default '',
  home_precautions text not null default '',

  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  completed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint screen_time_per_day check (coalesce(screen_hours, 0) * 60 + coalesce(screen_minutes, 0) <= 1440)
);
create index assessments_child_idx on public.assessments (child_id, assessment_date desc);
create index assessments_intake_idx on public.assessments (created_by) where child_id is null;
create index assessments_therapist_idx on public.assessments (therapist_id);
create index assessments_copied_idx on public.assessments (copied_from);

-- Every rated item of the form. `item` is a stable key from the app's catalogue (e.g. 'walking', 'moro',
-- 'shoulder'); `side` is 'right'/'left' for range of motion and '' otherwise; `label` names an "Others" ADL.
create table public.assessment_findings (
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  domain text not null check (domain in ('senses', 'milestones', 'play_skills', 'behaviour', 'sensory', 'posture', 'reflexes', 'rom', 'hand', 'adl')),
  item text not null check (char_length(item) between 1 and 60),
  side text not null default '' check (side in ('', 'right', 'left')),
  label text not null default '' check (char_length(label) <= 120),
  status text check (status in (
    'normal', 'concern', 'impaired', 'not_assessed',                               -- special senses
    'present', 'absent', 'delayed', 'emerging',                                     -- milestones, play skills, behaviour, hand function
    'age_appropriate', 'age_inappropriate', 'needs_support',                        -- handling defeat
    'no_concern',                                                                   -- sensory
    'abnormal',                                                                     -- posture
    'retained', 'exaggerated',                                                      -- reflexes
    'independent', 'independent_difficulty', 'needs_assistance', 'dependent', 'not_applicable')), -- ADL
  severity text check (severity in ('mild', 'moderate', 'severe')),
  age text not null default '',
  frequency text not null default '',
  duration text not null default '',
  triggers text not null default '',
  behaviour text not null default '',
  arom text not null default '',
  prom text not null default '',
  strength smallint check (strength between 0 and 5),
  notes text not null default '',
  primary key (assessment_id, domain, item, side)
);

create table public.assessment_problems (
  id uuid primary key,
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  position integer not null default 0,
  problem text not null default '',
  treatment_plan text not null default ''
);
create index assessment_problems_assessment_idx on public.assessment_problems (assessment_id, position);

create table public.assessment_goals (
  id uuid primary key,
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  term text not null check (term in ('short', 'long')),
  position integer not null default 0,
  description text not null default '',
  target_date date,
  status text not null default 'not_started' check (status in ('not_started', 'in_progress', 'achieved', 'modified')),
  -- The same goal in the assessment this one was copied from, for comparing goals over time.
  source_goal_id uuid references public.assessment_goals(id) on delete set null
);
create index assessment_goals_assessment_idx on public.assessment_goals (assessment_id, term, position);
create index assessment_goals_source_idx on public.assessment_goals (source_goal_id);

-- ============================================================ who may read and edit
-- Read: the admin; therapists for children in their sessions; whoever started it.
alter table public.assessments enable row level security;
alter table public.assessment_findings enable row level security;
alter table public.assessment_problems enable row level security;
alter table public.assessment_goals enable row level security;

create policy "Read" on public.assessments for select to authenticated using (
  (select private.is_admin())
  or (child_id is not null and private.therapist_has_child(child_id))
  or created_by = (select auth.uid())
);
-- The parent row's own policy decides, so the rules live in one place.
create policy "Read" on public.assessment_findings for select to authenticated
  using (exists (select 1 from public.assessments a where a.id = assessment_id));
create policy "Read" on public.assessment_problems for select to authenticated
  using (exists (select 1 from public.assessments a where a.id = assessment_id));
create policy "Read" on public.assessment_goals for select to authenticated
  using (exists (select 1 from public.assessments a where a.id = assessment_id));

revoke all on public.assessments, public.assessment_findings, public.assessment_problems, public.assessment_goals from anon;
revoke insert, update, delete, truncate on public.assessments, public.assessment_findings, public.assessment_problems, public.assessment_goals from authenticated;
grant select on public.assessments, public.assessment_findings, public.assessment_problems, public.assessment_goals to authenticated;

-- Edit: the admin, any assessment that isn't archived. A therapist: unfinished assessments of children in their
-- sessions, and completed ones they did themselves.
create or replace function private.can_edit_assessment(p_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.assessments a
    where a.id = p_id and a.status <> 'archived' and (
      private.is_admin()
      or (a.child_id is not null and private.therapist_has_child(a.child_id)
          and (a.status in ('draft', 'in_progress') or a.therapist_id = private.my_therapist_id()))
    )
  )
$$;

-- ============================================================ start one
-- [p_child] null = the intake assessment for a child the admin is about to create. [p_copy_from] pre-fills it
-- from an earlier assessment of the same child (a re-assessment usually changes only part of the picture).
create or replace function public.create_assessment(p_child uuid, p_kind text, p_therapist uuid, p_copy_from uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_admin boolean := private.is_admin();
  v_therapist uuid := p_therapist;
  v_id uuid;
  c public.children;
begin
  if p_child is null then
    if not v_admin then raise exception 'Only the centre admin can assess a new child.'; end if;
  else
    if not (v_admin or private.therapist_has_child(p_child)) then raise exception 'You can only assess children in your sessions.'; end if;
    select * into c from public.children where id = p_child;
    if not found then raise exception 'Child not found.'; end if;
  end if;
  -- A therapist always assesses as themself.
  if not v_admin then v_therapist := private.my_therapist_id(); end if;
  if v_therapist is not null and not exists (select 1 from public.therapists where id = v_therapist and active) then
    raise exception 'Select an active therapist.';
  end if;
  if coalesce(p_kind, '') not in ('initial', 'reassessment', 'follow_up') then raise exception 'Choose the type of assessment.'; end if;

  insert into public.assessments (child_id, therapist_id, kind, child_name, dob, updated_by)
  values (p_child, v_therapist, p_kind, coalesce(c.name, ''), c.dob, (select auth.uid()))
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

-- ============================================================ save (autosave)
-- Writes the whole assessment: the scalar answers in [p_data].fields, and the full lists of findings, problems
-- and goals (rows missing from the lists are removed). [p_rev] must be the revision the app last loaded or
-- saved; otherwise someone else saved in between and nothing is written. Returns the new revision.
-- Clinical checks (required answers, sensible dates) happen at completion, never here: an autosave must not
-- be refused because a draft is half-filled.
create or replace function public.save_assessment(p_id uuid, p_rev integer, p_data jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  f jsonb := coalesce(p_data->'fields', '{}');
  a public.assessments;
  v_rev integer;
begin
  if not private.can_edit_assessment(p_id) then raise exception 'You can''t edit this assessment.'; end if;
  if octet_length(p_data::text) > 500000 then raise exception 'This assessment is too large to save.'; end if;
  select * into a from public.assessments where id = p_id for update;
  if p_rev is null or a.rev <> p_rev then raise exception 'ASSESSMENT_CONFLICT'; end if;

  update public.assessments set
    -- Only the admin chooses the therapist; a therapist's own assessments stay theirs.
    therapist_id = case when private.is_admin() then nullif(f->>'therapist_id', '')::uuid else therapist_id end,
    kind = coalesce(nullif(f->>'kind', ''), kind),
    assessment_date = coalesce(nullif(f->>'assessment_date', '')::date, assessment_date),
    current_section = left(coalesce(nullif(f->>'current_section', ''), current_section), 40),
    progress = greatest(0, least(100, coalesce((f->>'progress')::int, progress))),
    child_name = left(coalesce(f->>'child_name', ''), 120),
    gender = nullif(f->>'gender', ''),
    dob = nullif(f->>'dob', '')::date,
    referred_by = coalesce(f->>'referred_by', ''),
    informant = coalesce(f->>'informant', ''),
    hand_dominance = nullif(f->>'hand_dominance', ''),
    surgery = nullif(f->>'surgery', ''),
    surgery_details = coalesce(f->>'surgery_details', ''),
    surgery_date = nullif(f->>'surgery_date', '')::date,
    chief_complaints = coalesce(f->>'chief_complaints', ''),
    felt_needs = coalesce(f->>'felt_needs', ''),
    family_history = coalesce(f->>'family_history', ''),
    prenatal = coalesce(f->>'prenatal', ''),
    perinatal = coalesce(f->>'perinatal', ''),
    postnatal = coalesce(f->>'postnatal', ''),
    school_status = nullif(f->>'school_status', ''),
    grade = coalesce(f->>'grade', ''),
    classroom_complaints = coalesce(f->>'classroom_complaints', ''),
    play_types = coalesce(array(select jsonb_array_elements_text(coalesce(f->'play_types', '[]'))), '{}'),
    play_methods = coalesce(array(select jsonb_array_elements_text(coalesce(f->'play_methods', '[]'))), '{}'),
    group_behaviour = nullif(f->>'group_behaviour', ''),
    screen_hours = nullif(f->>'screen_hours', '')::smallint,
    screen_minutes = nullif(f->>'screen_minutes', '')::smallint,
    screen_content = coalesce(f->>'screen_content', ''),
    posture_anatomy = coalesce(f->>'posture_anatomy', ''),
    approaches = coalesce(f->>'approaches', ''),
    approach_tags = coalesce(array(select jsonb_array_elements_text(coalesce(f->'approach_tags', '[]'))), '{}'),
    home_activities = coalesce(f->>'home_activities', ''),
    home_frequency = coalesce(f->>'home_frequency', ''),
    home_duration = coalesce(f->>'home_duration', ''),
    home_instructions = coalesce(f->>'home_instructions', ''),
    home_precautions = coalesce(f->>'home_precautions', ''),
    status = case when status = 'draft' then 'in_progress' else status end,
    rev = rev + 1,
    updated_at = now(),
    updated_by = (select auth.uid())
  where id = p_id
  returning rev into v_rev;

  delete from public.assessment_findings where assessment_id = p_id;
  insert into public.assessment_findings (assessment_id, domain, item, side, label, status, severity, age, frequency, duration,
    triggers, behaviour, arom, prom, strength, notes)
  select p_id, x.domain, x.item, coalesce(x.side, ''), coalesce(x.label, ''), nullif(x.status, ''), nullif(x.severity, ''),
    coalesce(x.age, ''), coalesce(x.frequency, ''), coalesce(x.duration, ''), coalesce(x.triggers, ''), coalesce(x.behaviour, ''),
    coalesce(x.arom, ''), coalesce(x.prom, ''), x.strength, coalesce(x.notes, '')
  from jsonb_to_recordset(coalesce(p_data->'findings', '[]')) as x(domain text, item text, side text, label text, status text,
    severity text, age text, frequency text, duration text, triggers text, behaviour text, arom text, prom text, strength smallint, notes text);

  -- Problems and goals keep their ids (goals are linked across assessments), so they are upserted, not replaced.
  delete from public.assessment_problems where assessment_id = p_id
    and id not in (select (x->>'id')::uuid from jsonb_array_elements(coalesce(p_data->'problems', '[]')) x);
  insert into public.assessment_problems (id, assessment_id, position, problem, treatment_plan)
  select x.id, p_id, coalesce(x.position, 0), coalesce(x.problem, ''), coalesce(x.treatment_plan, '')
  from jsonb_to_recordset(coalesce(p_data->'problems', '[]')) as x(id uuid, position int, problem text, treatment_plan text)
  on conflict (id) do update set position = excluded.position, problem = excluded.problem, treatment_plan = excluded.treatment_plan
    where public.assessment_problems.assessment_id = p_id;

  delete from public.assessment_goals where assessment_id = p_id
    and id not in (select (x->>'id')::uuid from jsonb_array_elements(coalesce(p_data->'goals', '[]')) x);
  insert into public.assessment_goals (id, assessment_id, term, position, description, target_date, status)
  select x.id, p_id, x.term, coalesce(x.position, 0), coalesce(x.description, ''), x.target_date, coalesce(nullif(x.status, ''), 'not_started')
  from jsonb_to_recordset(coalesce(p_data->'goals', '[]')) as x(id uuid, term text, position int, description text, target_date date, status text)
  on conflict (id) do update set term = excluded.term, position = excluded.position, description = excluded.description,
    target_date = excluded.target_date, status = excluded.status
    where public.assessment_goals.assessment_id = p_id;

  return v_rev;
end $$;

-- ============================================================ complete
-- The checks a finished assessment must pass. Kept short on purpose: only what a clinical record can't be
-- without. Returns the problems found, one per line, or null.
create or replace function private.assessment_gaps(p_id uuid) returns text
language plpgsql stable security definer set search_path = '' as $$
declare a public.assessments; gaps text[] := '{}';
begin
  select * into a from public.assessments where id = p_id;
  if a.therapist_id is null then gaps := gaps || 'Choose the therapist who did the assessment.'; end if;
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

create or replace function public.complete_assessment(p_id uuid, p_rev integer) returns integer
language plpgsql security definer set search_path = '' as $$
declare a public.assessments; v_gaps text; v_rev integer;
begin
  if not private.can_edit_assessment(p_id) then raise exception 'You can''t complete this assessment.'; end if;
  select * into a from public.assessments where id = p_id for update;
  if p_rev is null or a.rev <> p_rev then raise exception 'ASSESSMENT_CONFLICT'; end if;
  v_gaps := private.assessment_gaps(p_id);
  if v_gaps is not null then raise exception '%', v_gaps; end if;
  update public.assessments set status = 'completed', completed_at = coalesce(completed_at, now()), completed_by = coalesce(completed_by, (select auth.uid())),
    rev = rev + 1, updated_at = now(), updated_by = (select auth.uid())
  where id = p_id returning rev into v_rev;
  return v_rev;
end $$;

-- A completed assessment that is edited later must still pass the completion checks.
create or replace function private.guard_completed_assessment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_gaps text;
begin
  if new.status = 'completed' and old.status = 'completed' then
    v_gaps := private.assessment_gaps(new.id);
    if v_gaps is not null then raise exception 'A completed assessment must stay complete: %', v_gaps; end if;
  end if;
  return null;
end $$;
-- Deferred: the findings, problems and goals of the same save are in place when it runs.
create constraint trigger completed_assessment_guard after update on public.assessments
  deferrable initially deferred for each row execute function private.guard_completed_assessment();

-- ============================================================ archive and delete
-- Admin: archive (kept, read-only, out of the active history) or bring back.
create or replace function public.set_assessment_archived(p_id uuid, p_archived boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  update public.assessments set
    status = case when p_archived then 'archived' when completed_at is not null then 'completed' else 'in_progress' end,
    rev = rev + 1, updated_at = now(), updated_by = (select auth.uid())
  where id = p_id and (status = 'archived') <> p_archived;
end $$;

-- Only an unfinished assessment can be deleted (by the admin or whoever started it); finished ones are archived.
create or replace function public.delete_assessment(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.assessments a where a.id = p_id and a.status in ('draft', 'in_progress')
    and (private.is_admin() or a.created_by = (select auth.uid()));
  if not found then raise exception 'Only an unfinished assessment can be deleted.'; end if;
end $$;

-- ============================================================ creating a child needs an assessment
-- The old save_child body, shared by editing and by create_assessed_child.
create or replace function private.save_child_core(p_id uuid, p_name text, p_dob date, p_father text, p_mother text, p_phone text, p_alt_phone text, p_therapies jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := p_id;
begin
  perform private.require_admin();
  if length(btrim(coalesce(p_name, ''))) = 0 then raise exception 'Enter the child''s name.'; end if;
  if p_dob is null or p_dob > private.today() then raise exception 'Enter a valid date of birth.'; end if;
  if length(private.digits10(p_phone)) <> 10 then raise exception 'Enter a valid 10-digit contact number.'; end if;
  if jsonb_array_length(coalesce(p_therapies, '[]')) = 0 then raise exception 'Select at least one therapy.'; end if;
  if exists (select 1 from jsonb_array_elements(p_therapies) x where (x->>'session_fee') is not null and (x->>'session_fee')::numeric < 0) then
    raise exception 'A session fee can''t be negative.';
  end if;
  if v_id is null then
    insert into public.children (name, dob, father_name, mother_name, phone, alt_phone)
    values (btrim(p_name), p_dob, btrim(coalesce(p_father, '')), btrim(coalesce(p_mother, '')), btrim(p_phone), btrim(coalesce(p_alt_phone, '')))
    returning id into v_id;
  else
    update public.children set name = btrim(p_name), dob = p_dob, father_name = btrim(coalesce(p_father, '')),
      mother_name = btrim(coalesce(p_mother, '')), phone = btrim(p_phone), alt_phone = btrim(coalesce(p_alt_phone, ''))
    where id = v_id;
    if not found then raise exception 'Child not found.'; end if;
    delete from public.child_therapies ct where ct.child_id = v_id
      and ct.therapy_id not in (select (x->>'therapy_id')::uuid from jsonb_array_elements(p_therapies) x);
  end if;
  insert into public.child_therapies (child_id, therapy_id, session_fee)
  select v_id, (x->>'therapy_id')::uuid, round((x->>'session_fee')::numeric, 2) from jsonb_array_elements(p_therapies) x
  on conflict (child_id, therapy_id) do update set session_fee = excluded.session_fee;
  return v_id;
end $$;
revoke execute on function private.save_child_core(uuid, text, date, text, text, text, text, jsonb) from public, anon, authenticated;

create or replace function public.save_child(p_id uuid, p_name text, p_dob date, p_father text, p_mother text, p_phone text, p_alt_phone text, p_therapies jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
begin
  if p_id is null then raise exception 'A new child needs a completed assessment. Attend the assessment first.'; end if;
  return private.save_child_core(p_id, p_name, p_dob, p_father, p_mother, p_phone, p_alt_phone, p_therapies);
end $$;

-- Admin: creates the child and attaches their completed intake assessment, all or nothing.
create or replace function public.create_assessed_child(p_assessment uuid, p_name text, p_dob date, p_father text, p_mother text,
  p_phone text, p_alt_phone text, p_therapies jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare a public.assessments; v_id uuid;
begin
  perform private.require_admin();
  select * into a from public.assessments where id = p_assessment for update;
  if not found then raise exception 'The assessment was not found. Attend the assessment again.'; end if;
  if a.child_id is not null then raise exception 'This assessment already belongs to a child.'; end if;
  if a.status <> 'completed' then raise exception 'Complete the assessment before creating the child.'; end if;
  v_id := private.save_child_core(null, p_name, p_dob, p_father, p_mother, p_phone, p_alt_phone, p_therapies);
  update public.assessments set child_id = v_id, rev = rev + 1, updated_at = now(), updated_by = (select auth.uid()) where id = p_assessment;
  return v_id;
end $$;

-- ============================================================ grants
do $$
declare f text;
begin
  foreach f in array array[
    'public.create_assessment(uuid, text, uuid, uuid)',
    'public.save_assessment(uuid, integer, jsonb)',
    'public.complete_assessment(uuid, integer)',
    'public.set_assessment_archived(uuid, boolean)',
    'public.delete_assessment(uuid)',
    'public.save_child(uuid, text, date, text, text, text, text, jsonb)',
    'public.create_assessed_child(uuid, text, date, text, text, text, text, jsonb)']
  loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
revoke execute on function private.can_edit_assessment(uuid), private.assessment_gaps(uuid), private.guard_completed_assessment() from public, anon;

-- 1. "Is an assessment needed?" when adding a child.
--    Children who already had the centre's paper assessment are added without one: create_assessed_child takes a
--    null assessment for them and records `assessment_needed = false`, so their profile doesn't ask for one.
--    (An assessment can still be started for any child at any time.) Children added before assessments existed
--    count as not needing one.
-- 2. assessment_timeline: the rated answers of a child's completed assessments, for the progress chart on the
--    child's profile. Admin, the child's therapists and the family may read it. Only statuses, severities and
--    strength grades are returned: no notes, histories or plans, which stay with the clinical staff.

alter table public.children add column if not exists assessment_needed boolean not null default false;

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
  end if;
  v_id := private.save_child_core(null, p_name, p_dob, p_father, p_mother, p_phone, p_alt_phone, p_therapies);
  update public.children set assessment_needed = p_assessment is not null where id = v_id;
  if p_assessment is not null then
    update public.assessments set child_id = v_id, rev = rev + 1, updated_at = now(), updated_by = (select auth.uid()) where id = p_assessment;
  end if;
  return v_id;
end $$;

create or replace function public.save_child(p_id uuid, p_name text, p_dob date, p_father text, p_mother text, p_phone text, p_alt_phone text, p_therapies jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
begin
  if p_id is null then raise exception 'Add a new child from the Add child form: it asks whether an assessment is needed.'; end if;
  return private.save_child_core(p_id, p_name, p_dob, p_father, p_mother, p_phone, p_alt_phone, p_therapies);
end $$;

create or replace function public.assessment_timeline(p_child uuid)
returns table (assessment_id uuid, assessment_date date, kind text, findings jsonb)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (private.is_admin() or private.therapist_has_child(p_child) or private.is_my_child(p_child)) then
    raise exception 'You can only see your own child''s progress.';
  end if;
  return query
  select a.id, a.assessment_date, a.kind,
    coalesce((select jsonb_agg(jsonb_build_object('domain', f.domain, 'item', f.item, 'side', f.side, 'label', f.label, 'status', f.status, 'severity', f.severity, 'strength', f.strength))
              from public.assessment_findings f where f.assessment_id = a.id), '[]'::jsonb)
  from public.assessments a
  where a.child_id = p_child and a.status = 'completed'
  order by a.assessment_date, a.created_at;
end $$;

revoke execute on function public.assessment_timeline(uuid) from public, anon;
grant execute on function public.assessment_timeline(uuid) to authenticated;
revoke execute on function public.create_assessed_child(uuid, text, date, text, text, text, text, jsonb) from public, anon;
grant execute on function public.create_assessed_child(uuid, text, date, text, text, text, text, jsonb) to authenticated;

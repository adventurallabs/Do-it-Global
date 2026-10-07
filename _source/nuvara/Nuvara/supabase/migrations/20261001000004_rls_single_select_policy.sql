-- One SELECT policy per table (admin OR the role-specific rule), and separate admin write policies.
do $$
declare
  t text;
  rules jsonb := jsonb_build_object(
    'profiles', 'id = (select auth.uid())',
    'therapies', 'true', 'therapists', 'true', 'therapist_therapies', 'true', 'timetable_slots', 'true', 'sessions', 'true',
    'therapist_details', 'therapist_id = (select private.my_therapist_id())',
    'session_children', 'private.is_my_session(session_id) or private.is_my_child(child_id)',
    'children', 'private.is_my_child(id) or private.therapist_has_child(id)',
    'child_therapies', 'private.is_my_child(child_id) or private.therapist_has_child(child_id)',
    'fee_charges', 'private.is_my_child(child_id)',
    'fee_payments', 'private.is_my_child(child_id)');
  p record;
begin
  for t in select jsonb_object_keys(rules) loop
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy "Read" on public.%I for select to authenticated using (%s)', t,
      case when rules->>t = 'true' then 'true' else format('(select private.is_admin()) or %s', rules->>t) end);
    execute format('create policy "Admin insert" on public.%I for insert to authenticated with check ((select private.is_admin()))', t);
    execute format('create policy "Admin update" on public.%I for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()))', t);
    execute format('create policy "Admin delete" on public.%I for delete to authenticated using ((select private.is_admin()))', t);
  end loop;
end $$;

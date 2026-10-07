-- Sessions always have at least one child (create/update enforce it). Removing a child cascades their
-- seats away; any session left with nobody in it is removed in the same statement.
create or replace function private.drop_empty_sessions() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  delete from public.sessions s where not exists (select 1 from public.session_children sc where sc.session_id = s.id);
  return null;
end $$;
create trigger children_drop_empty_sessions after delete on public.children
  for each statement execute function private.drop_empty_sessions();

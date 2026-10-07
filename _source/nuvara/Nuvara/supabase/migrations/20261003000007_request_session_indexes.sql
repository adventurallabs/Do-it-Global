-- Deleting a session (re-allocations empty and delete them) clears these references; index them so it
-- doesn't scan every request.
create index if not exists reschedule_requests_session_idx on public.reschedule_requests (session_id) where session_id is not null;
create index if not exists reschedule_requests_target_session_idx on public.reschedule_requests (target_session_id) where target_session_id is not null;

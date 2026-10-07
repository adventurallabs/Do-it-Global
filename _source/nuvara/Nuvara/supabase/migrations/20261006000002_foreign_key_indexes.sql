-- Covering indexes for foreign keys the performance advisor flagged. Without them, deleting a profile, therapist
-- or therapy (or checking those references) scans the whole referencing table, which grows with the centre.
create index if not exists assessments_completed_by_idx on public.assessments (completed_by);
create index if not exists assessments_updated_by_idx on public.assessments (updated_by);
create index if not exists fee_payments_reconciled_by_idx on public.fee_payments (reconciled_by);
create index if not exists fee_payments_resolved_by_idx on public.fee_payments (resolved_by);
create index if not exists fee_payments_upi_account_idx on public.fee_payments (upi_account_id);
create index if not exists messages_sender_idx on public.messages (sender_id);
create index if not exists reschedule_requests_created_by_idx on public.reschedule_requests (created_by);
create index if not exists reschedule_requests_new_therapist_idx on public.reschedule_requests (new_therapist_id);
create index if not exists reschedule_requests_resolved_by_idx on public.reschedule_requests (resolved_by);
create index if not exists reschedule_requests_target_therapist_idx on public.reschedule_requests (target_therapist_id);
create index if not exists reschedule_requests_therapist_idx on public.reschedule_requests (therapist_id);
create index if not exists reschedule_requests_therapy_idx on public.reschedule_requests (therapy_id);
create index if not exists session_children_marked_by_idx on public.session_children (marked_by);

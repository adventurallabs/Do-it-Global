-- The app loads half a year of weekly bills. Any older week that still has money due is loaded too, so
-- nothing owed is ever out of sight (record_child_payment settles the oldest weeks first, these included).
-- Runs as the caller: fee_weeks decides what they may see.
create or replace function public.fee_weeks_due(p_before date)
returns table (child_id uuid, week_start date, allocated int, attended int, absent int, unmarked int, upcoming int,
  amount numeric, paid numeric, verifying numeric, lines jsonb, closed boolean)
language sql stable security invoker set search_path = '' as $$
  select f.* from public.fee_weeks(date '2000-01-03', p_before - 1) f
  where f.amount - f.paid - f.verifying > 0.005
$$;
revoke execute on function public.fee_weeks_due(date) from public, anon;
grant execute on function public.fee_weeks_due(date) to authenticated;

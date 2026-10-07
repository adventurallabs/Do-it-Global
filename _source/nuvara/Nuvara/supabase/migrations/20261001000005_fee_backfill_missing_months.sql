-- Bill every month up to now, not only the current one: if nobody opened the app during a month,
-- that month is still billed (at the child's plan as it stands). Existing bills are never changed.
create or replace function public.ensure_fee_charges() returns void language plpgsql security definer set search_path = '' as $$
declare
  cur date := date_trunc('month', private.today())::date;
  r record;
  m date;
begin
  perform private.require_admin();
  for r in
    select c.id,
      coalesce(sum(t.base_fee), 0) as base,
      coalesce(max(c.fee_override), coalesce(sum(t.base_fee), 0)) as amount,
      coalesce(
        (select (max(f.period) || '-01')::date + interval '1 month' from public.fee_charges f where f.child_id = c.id),
        date_trunc('month', c.created_at at time zone 'Asia/Kolkata')
      )::date as first_missing
    from public.children c
    left join public.child_therapies ct on ct.child_id = c.id
    left join public.therapies t on t.id = ct.therapy_id
    where c.active
    group by c.id
  loop
    m := r.first_missing;
    while m <= cur loop
      insert into public.fee_charges (child_id, period, base_fee, amount)
      values (r.id, to_char(m, 'YYYY-MM'), r.base, r.amount)
      on conflict (child_id, period) do nothing;
      m := (m + interval '1 month')::date;
    end loop;
  end loop;
end $$;

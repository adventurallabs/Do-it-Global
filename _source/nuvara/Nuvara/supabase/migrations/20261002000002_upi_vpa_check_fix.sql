-- Postgres caps a regex repetition count at 255. (The previous migration now has the corrected check;
-- this re-creates it on databases that ran the first version.)
alter table public.upi_accounts drop constraint upi_accounts_vpa_check;
alter table public.upi_accounts add constraint upi_accounts_vpa_check check (vpa ~ '^[A-Za-z0-9._-]{2,255}@[A-Za-z][A-Za-z0-9.-]{1,63}$');

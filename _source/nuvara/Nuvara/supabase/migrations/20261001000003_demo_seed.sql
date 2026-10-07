-- Small demo dataset so each test login has something to show. Everything here can be deleted from the app.

-- The parent test account is linked to children through this number.
update public.profiles set phone = '+91 98765 43210' where id = '00000000-0000-4000-a000-000000000003';

insert into public.therapies (name, base_fee) values
  ('Speech Therapy', 3000), ('Occupational Therapy', 3500), ('Behaviour Therapy', 4000),
  ('Physiotherapy', 3000), ('Special Education', 2500);

insert into public.therapists (name, profile_id)
values ('Priya Raman', '00000000-0000-4000-a000-000000000002'), ('Rahul Menon', null), ('Divya Nair', null), ('Kumar Selvam', null);

insert into public.therapist_details (therapist_id, dob, phone, emergency_phone, salary)
select t.id, v.dob, v.phone, '', v.salary
from (values ('Priya Raman', date '1991-04-12', '98400 11001', 32000), ('Rahul Menon', date '1988-09-03', '98400 11002', 30000),
             ('Divya Nair', date '1993-01-22', '98400 11003', 28000), ('Kumar Selvam', date '1985-06-30', '98400 11004', 31000)) v(name, dob, phone, salary)
join public.therapists t on t.name = v.name;

insert into public.therapist_therapies
select t.id, th.id from (values ('Priya Raman', 'Occupational Therapy'), ('Rahul Menon', 'Speech Therapy'),
  ('Divya Nair', 'Behaviour Therapy'), ('Divya Nair', 'Special Education'), ('Kumar Selvam', 'Physiotherapy')) v(t, th)
join public.therapists t on t.name = v.t join public.therapies th on th.name = v.th;

insert into public.children (name, dob, father_name, mother_name, phone, alt_phone, fee_override) values
  ('Aarav Sharma', '2020-03-14', 'Vikram Sharma', 'Neha Sharma', '+91 98765 43210', '', null),
  ('Anaya Sharma', '2022-08-02', 'Vikram Sharma', 'Neha Sharma', '+91 98765 43210', '', 5500),
  ('Diya Patel', '2019-11-21', 'Rakesh Patel', 'Meena Patel', '98765 43421', '', null),
  ('Kavin Raj', '2018-06-09', 'Raj Kumar', 'Lakshmi Raj', '98765 43632', '98765 40000', null),
  ('Riya Thomas', '2020-09-17', 'Joseph Thomas', 'Mary Thomas', '98765 43843', '', null);

insert into public.child_therapies (child_id, therapy_id, level)
select c.id, th.id, v.level from (values
  ('Aarav Sharma', 'Speech Therapy', 35), ('Aarav Sharma', 'Occupational Therapy', 50),
  ('Anaya Sharma', 'Speech Therapy', 20), ('Anaya Sharma', 'Special Education', 15),
  ('Diya Patel', 'Behaviour Therapy', 40), ('Kavin Raj', 'Physiotherapy', 60),
  ('Kavin Raj', 'Occupational Therapy', 45), ('Riya Thomas', 'Physiotherapy', 25)) v(c, th, level)
join public.children c on c.name = v.c join public.therapies th on th.name = v.th;

-- This week's timetable: three slots on Mon–Fri.
insert into public.timetable_slots (slot_date, start_time, end_time)
select date_trunc('week', private.today())::date + i, v.st, v.en
from generate_series(0, 4) i
cross join (values (time '09:30', time '10:15'), (time '10:15', time '11:00'), (time '11:15', time '12:00')) v(st, en);

insert into public.sessions (slot_id, name, therapist_id)
select s.id, v.name, t.id
from (values ('09:30', 'Speech group · Room 1', 'Rahul Menon'), ('09:30', 'OT · Room 2', 'Priya Raman'),
             ('10:15', 'Behaviour · Room 3', 'Divya Nair'), ('10:15', 'Physio · Gym', 'Kumar Selvam'),
             ('11:15', 'OT · Room 2', 'Priya Raman')) v(st, name, therapist)
join public.timetable_slots s on s.start_time = v.st::time and s.slot_date between date_trunc('week', private.today())::date and date_trunc('week', private.today())::date + 4
join public.therapists t on t.name = v.therapist;

insert into public.session_children (session_id, child_id)
select s.id, c.id
from public.sessions s join public.timetable_slots ts on ts.id = s.slot_id
join (values ('09:30', 'Speech group · Room 1', 'Aarav Sharma'), ('09:30', 'Speech group · Room 1', 'Anaya Sharma'),
             ('09:30', 'OT · Room 2', 'Kavin Raj'), ('10:15', 'Behaviour · Room 3', 'Diya Patel'),
             ('10:15', 'Physio · Gym', 'Riya Thomas'), ('10:15', 'Physio · Gym', 'Kavin Raj'),
             ('11:15', 'OT · Room 2', 'Aarav Sharma')) v(st, name, child) on ts.start_time = v.st::time and s.name = v.name
join public.children c on c.name = v.child;

-- A couple of payments this month so every fee status appears.
insert into public.fee_payments (child_id, period, amount, method)
select c.id, to_char(private.today(), 'YYYY-MM'), v.amount, v.method
from (values ('Anaya Sharma', 5500, 'UPI'), ('Aarav Sharma', 3000, 'Cash')) v(name, amount, method)
join public.children c on c.name = v.name;

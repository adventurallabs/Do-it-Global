/**
 * Illustrative sample data shown inside the recreated Nuvara screens. Names
 * follow the app's own demo seed (supabase/migrations/…_demo_seed.sql) and
 * everything here is fictional: a normal Tuesday at a therapy centre.
 */
export const NV_DATE = {
  weekday: 'Tuesday',
  long: 'Tuesday, 6 October',
  short: 'Tue, 6 Oct',
  week: '5 – 11 Oct 2026',
  lastWeek: '28 Sep – 4 Oct',
}

/** Therapies with their fee per session. Colours come from Therapy.color (a hash of the name). */
export const THERAPIES = {
  speech: { name: 'Speech Therapy', color: '#3D64A8', fee: 600 },
  ot: { name: 'Occupational Therapy', color: '#B8486A', fee: 700 },
  behaviour: { name: 'Behaviour Therapy', color: '#5B6B8F', fee: 800 },
  physio: { name: 'Physiotherapy', color: '#3D64A8', fee: 600 },
  special: { name: 'Special Education', color: '#3D64A8', fee: 500 },
}

export const KIDS = {
  aarav: { name: 'Aarav Sharma', first: 'Aarav', code: 'C001', age: '6 years 6 months' },
  anaya: { name: 'Anaya Sharma', first: 'Anaya', code: 'C002', age: '4 years 2 months' },
  diya: { name: 'Diya Patel', first: 'Diya', code: 'C003', age: '6 years 10 months' },
  kavin: { name: 'Kavin Raj', first: 'Kavin', code: 'C004', age: '8 years 3 months' },
  riya: { name: 'Riya Thomas', first: 'Riya', code: 'C005', age: '6 years' },
  ishaan: { name: 'Ishaan Kumar', first: 'Ishaan', code: 'C006', age: '5 years 1 month' },
  meher: { name: 'Meher Joseph', first: 'Meher', code: 'C007', age: '7 years 4 months' },
}

export const STAFF = {
  priya: { name: 'Priya Raman', first: 'Priya', code: 'T001', therapy: 'Occupational Therapy' },
  rahul: { name: 'Rahul Menon', first: 'Rahul', code: 'T002', therapy: 'Speech Therapy' },
  divya: { name: 'Divya Nair', first: 'Divya', code: 'T003', therapy: 'Behaviour Therapy' },
  kumar: { name: 'Kumar Selvam', first: 'Kumar', code: 'T004', therapy: 'Physiotherapy' },
}

export const PARENT = { name: 'Neha Sharma', first: 'Neha' }
export const ADMIN = { name: 'Meera Krishnan', first: 'Meera' }
export const UPI_ID = 'nuvara@okaxis'

/** Aarav's session ratings since he joined: one point per day, 0–10. */
export const AARAV_RATINGS = [4, 4.5, 5, 4, 5.5, 5, 6, 5.5, 6, 6.5, 6, 7, 6.5, 7, 7.5, 7, 8, 7.5]

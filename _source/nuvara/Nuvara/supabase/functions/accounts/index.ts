// Accounts: the only place logins are created, reset or removed. Runs with the service role, so
// every action re-checks who is calling. Called by the app via `supabase.functions.invoke('accounts')`.
//
//   admin_signup   {email, password, name}      anyone; email must be on public.admin_allowlist
//   sync_therapist {therapist_id}               admin; creates/updates the therapist's phone login
//   sync_child     {child_id}                   admin; creates/updates the parent login for a child
//   reset_password {kind: therapist|child, id}  admin; back to the default password (must set their own), returns {login, password}
//   delete_login   {kind: therapist|child, id}  admin; removes the login (before deleting the person)
//   delete_profile {profile_id}                 admin; removes a therapist/parent login left after deleting the person
//
// Therapist login: phone number. Parent login: the child's ID (C001). Both start with a default password =
// first letter of the name (upper case) + date of birth as DDMMYYYY, e.g. S01012000, and must set their
// own at the first sign-in. After that only the admin can change it (reset, which brings the default
// back); a database trigger enforces this.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

class Fail extends Error {
  constructor(message: string, public status = 400) {
    super(message);
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** [v] as a UUID, or a 400 naming [what] (a malformed id would otherwise surface as a raw database error). */
function uuid(v: unknown, what: string): string {
  if (typeof v !== 'string' || !UUID.test(v)) throw new Fail(`Missing or invalid ${what}.`);
  return v;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const digits10 = (p: string) => (p ?? '').replace(/\D/g, '').slice(-10);
export const therapistEmail = (phone: string) => `t${digits10(phone)}@therapist.nuvara.app`;
export const parentEmail = (childNo: number) => `child-${childNo}@parent.nuvara.app`;

/** "Santhosh", "2000-01-01" -> "S01012000" */
export function defaultPassword(name: string, dob: string | null): string {
  const letter = (name ?? '').trim().charAt(0).toUpperCase();
  if (!letter || !dob) throw new Fail('A name and date of birth are needed to create the default password.');
  const [y, m, d] = dob.split('-');
  return `${letter}${d}${m}${y}`;
}

const BANNED = '876000h'; // ~100 years: an inactive person can't sign in until reactivated.

async function requireAdmin(db: SupabaseClient, req: Request) {
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const { data, error } = await db.auth.getUser(token);
  if (error || !data.user) throw new Fail('Please sign in again.', 401);
  const { data: p } = await db.from('profiles').select('role').eq('id', data.user.id).maybeSingle();
  if (p?.role !== 'ADMIN') throw new Fail('Only the centre admin can manage logins.', 403);
}

/** Sets a therapist/parent password. The grant lets this one change past the guard_password_change trigger. */
async function setPassword(db: SupabaseClient, userId: string, password: string) {
  const { error: g } = await db.rpc('grant_password_change', { p_user: userId });
  if (g) throw new Fail(g.message);
  const { error } = await db.auth.admin.updateUserById(userId, { password });
  if (error) throw new Fail(error.message);
}

async function findUserByEmail(db: SupabaseClient, email: string) {
  for (let page = 1; ; page++) {
    const { data, error } = await db.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    const hit = data.users.find((u) => u.email?.toLowerCase() === email.toLowerCase());
    if (hit) return hit;
    if (data.users.length < 1000) return null;
  }
}

async function adminSignup(db: SupabaseClient, b: Record<string, string>) {
  const email = (b.email ?? '').trim().toLowerCase();
  const name = (b.name ?? '').trim();
  const password = b.password ?? '';
  if (!email.includes('@')) throw new Fail('Enter a valid email address.');
  if (!name) throw new Fail('Enter your name.');
  if (password.length < 8) throw new Fail('Use a password of at least 8 characters.');
  const { data: allowed } = await db.from('admin_allowlist').select('email').eq('email', email).maybeSingle();
  if (!allowed) throw new Fail('This email is not approved for an admin account. Please contact Nuvara.', 403);
  if (await findUserByEmail(db, email)) throw new Fail('An account already exists for this email. Please sign in.', 409);
  const { data, error } = await db.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name: name } });
  if (error) throw new Fail(error.message);
  const { error: e2 } = await db.from('profiles').insert({ id: data.user.id, role: 'ADMIN', full_name: name, email });
  if (e2) {
    await db.auth.admin.deleteUser(data.user.id);
    throw new Fail(e2.message);
  }
  return { ok: true };
}

async function syncTherapist(db: SupabaseClient, id: string) {
  const { data: t, error: te } = await db.from('therapists').select('id, name, active, profile_id, therapist_details(phone, dob)').eq('id', id).maybeSingle();
  if (te) throw te;
  if (!t) throw new Fail('Therapist not found.', 404);
  const d = Array.isArray(t.therapist_details) ? t.therapist_details[0] : t.therapist_details;
  if (digits10(d?.phone ?? '').length !== 10) throw new Fail('Add a 10-digit mobile number to create the login.');
  const email = therapistEmail(d.phone);
  const clash = await findUserByEmail(db, email);
  if (clash && clash.id !== t.profile_id) throw new Fail('Another login already uses this mobile number.', 409);

  if (!t.profile_id) {
    const { data, error } = await db.auth.admin.createUser({ email, password: defaultPassword(t.name, d?.dob ?? null), email_confirm: true, ban_duration: t.active ? 'none' : BANNED });
    if (error) throw new Fail(error.message);
    // Either step failing would leave a login nobody can use (or one the therapist isn't linked to): undo it.
    const { error: pe } = await db.from('profiles').insert({ id: data.user.id, role: 'THERAPIST', full_name: t.name, email, phone: d.phone, must_change_password: true });
    const { error: le } = pe ? { error: null } : await db.from('therapists').update({ profile_id: data.user.id }).eq('id', t.id);
    if (pe || le) {
      await db.auth.admin.deleteUser(data.user.id); // the profile row goes with it (on delete cascade)
      throw pe ?? le;
    }
    return { created: true, login: d.phone };
  }
  const { error } = await db.auth.admin.updateUserById(t.profile_id, { email, email_confirm: true, ban_duration: t.active ? 'none' : BANNED });
  if (error) throw new Fail(error.message);
  const { error: pe } = await db.from('profiles').update({ full_name: t.name, email, phone: d.phone }).eq('id', t.profile_id);
  if (pe) throw pe;
  return { created: false, login: d.phone };
}

async function syncChild(db: SupabaseClient, id: string) {
  const { data: c, error: ce } = await db.from('children').select('id, child_no, name, dob, phone, father_name, mother_name, active').eq('id', id).maybeSingle();
  if (ce) throw ce;
  if (!c) throw new Fail('Child not found.', 404);
  const email = parentEmail(c.child_no);
  const fullName = c.mother_name || c.father_name || `Parent of ${c.name}`;
  const { data: p, error: pe0 } = await db.from('profiles').select('id').eq('child_id', c.id).maybeSingle();
  if (pe0) throw pe0;
  if (!p) {
    const existing = await findUserByEmail(db, email);
    if (existing) await db.auth.admin.deleteUser(existing.id); // leftover from a removed child with the same number
    const { data, error } = await db.auth.admin.createUser({ email, password: defaultPassword(c.name, c.dob), email_confirm: true, ban_duration: c.active ? 'none' : BANNED });
    if (error) throw new Fail(error.message);
    const { error: pe } = await db.from('profiles').insert({ id: data.user.id, role: 'PARENT', full_name: fullName, email, phone: c.phone, child_id: c.id, must_change_password: true });
    if (pe) {
      await db.auth.admin.deleteUser(data.user.id); // no profile: the login would be unusable
      throw pe;
    }
    return { created: true };
  }
  // The login email always follows the child's ID, so it can never drift from what the parent types.
  const { error } = await db.auth.admin.updateUserById(p.id, { email, email_confirm: true, ban_duration: c.active ? 'none' : BANNED });
  if (error) throw new Fail(error.message);
  const { error: pe } = await db.from('profiles').update({ full_name: fullName, email, phone: c.phone }).eq('id', p.id);
  if (pe) throw pe;
  return { created: false };
}

async function loginOf(db: SupabaseClient, kind: string, id: string) {
  if (kind === 'therapist') {
    const { data: t } = await db.from('therapists').select('name, profile_id, therapist_details(dob, phone)').eq('id', id).maybeSingle();
    if (!t) throw new Fail('Therapist not found.', 404);
    const d = Array.isArray(t.therapist_details) ? t.therapist_details[0] : t.therapist_details;
    return { profileId: t.profile_id as string | null, name: t.name as string, dob: (d?.dob ?? null) as string | null, login: (d?.phone ?? '') as string };
  }
  if (kind === 'child') {
    const { data: c } = await db.from('children').select('name, dob, child_no').eq('id', id).maybeSingle();
    if (!c) throw new Fail('Child not found.', 404);
    const { data: p } = await db.from('profiles').select('id').eq('child_id', id).maybeSingle();
    return { profileId: (p?.id ?? null) as string | null, name: c.name as string, dob: c.dob as string, login: `C${String(c.child_no).padStart(3, '0')}` };
  }
  throw new Fail('Unknown account type.');
}

async function resetPassword(db: SupabaseClient, kind: string, id: string) {
  const l = await loginOf(db, kind, id);
  if (!l.profileId) throw new Fail('This person has no login yet.');
  const password = defaultPassword(l.name, l.dob);
  await setPassword(db, l.profileId, password);
  const { error } = await db.from('profiles').update({ must_change_password: true }).eq('id', l.profileId);
  if (error) throw new Fail(error.message);
  return { login: l.login, password };
}

/** Removes a therapist or parent login after its person was deleted. Never touches admin accounts. */
async function deleteProfile(db: SupabaseClient, profileId: string) {
  const { data: p } = await db.from('profiles').select('role').eq('id', profileId).maybeSingle();
  if (p && p.role === 'ADMIN') throw new Fail('Admin accounts cannot be removed here.', 403);
  const { data: t } = await db.from('therapists').select('id').eq('profile_id', profileId).maybeSingle();
  if (t) throw new Fail('This login still belongs to a therapist.', 409);
  const { data: c } = await db.from('profiles').select('child_id').eq('id', profileId).maybeSingle();
  if (c?.child_id) throw new Fail('This login still belongs to a child.', 409);
  const { error } = await db.auth.admin.deleteUser(profileId);
  if (error && !/not found/i.test(error.message)) throw new Fail(error.message);
  return { ok: true };
}

async function deleteLogin(db: SupabaseClient, kind: string, id: string) {
  const l = await loginOf(db, kind, id);
  if (l.profileId) await db.auth.admin.deleteUser(l.profileId);
  return { ok: true };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
    const b = await req.json().catch(() => ({}));
    if (b.action === 'admin_signup') return json(await adminSignup(db, b));
    await requireAdmin(db, req);
    switch (b.action) {
      case 'sync_therapist':
        return json(await syncTherapist(db, uuid(b.therapist_id, 'therapist id')));
      case 'sync_child':
        return json(await syncChild(db, uuid(b.child_id, 'child id')));
      case 'reset_password':
        return json(await resetPassword(db, b.kind, uuid(b.id, 'id')));
      case 'delete_login':
        return json(await deleteLogin(db, b.kind, uuid(b.id, 'id')));
      case 'delete_profile':
        return json(await deleteProfile(db, uuid(b.profile_id, 'profile id')));
      default:
        throw new Fail('Unknown action.');
    }
  } catch (e) {
    if (e instanceof Fail) return json({ error: e.message }, e.status);
    // Anything unexpected (database, auth API): log the real error, show the person a plain message.
    console.error('accounts:', e);
    return json({ error: 'Something went wrong. Please try again.' }, 500);
  }
});

# Nuvara

One Flutter app with three role-based experiences (Admin, Therapist, Parent) on a Supabase backend.
Works on phones, tablets, laptops and desktops: a bottom navigation bar on phones, a side rail on
tablets (from 840px) and a labelled sidebar on laptops and desktops (from 1200px).

## Setup

The Supabase URL and keys live in `.env`, which is never committed. Copy the template and fill it in
(Supabase dashboard → Project Settings → API):

```
cp .env.example .env
```

| Variable | What it is |
| --- | --- |
| `SUPABASE_URL` | The project URL, e.g. `https://<ref>.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | The publishable (anon) key. Never put the secret / service-role key here: it would ship inside the app |
| `TEST_PASSWORD` | Password of the seeded test accounts; used only by the live tests (`test/live_helpers.dart`). Leave it out of release env files |

The values are compiled in at build time, so every `flutter` command passes the file:

```
flutter pub get
flutter run --dart-define-from-file=.env           # Android/iOS device, or -d chrome / -d windows
flutter build apk --dart-define-from-file=.env
```

The VS Code launch config (`.vscode/launch.json`) passes it for you. Without it the app stops at startup and says what's missing.

## Signing in

| Who | Signs in with | First password |
| --- | --- | --- |
| Admin | Email + their own password. "New admin? Create your account" works only for emails on `admin_allowlist` (add them in the Supabase dashboard). | Chosen at sign-up |
| Therapist | Mobile number | First letter of their name + date of birth (DDMMYYYY), e.g. Santhosh, 01/01/2000 → `S01012000` |
| Parent | Child's ID (C001) | First letter of the child's name + the child's date of birth, e.g. `A14032020` |

- Therapist and parent logins are created automatically when the admin saves the person, and paused when they're marked inactive. The admin then sees the login details in a dialog with copy buttons.
- Anyone signing in with the default password (a new login, or after a reset) must set and confirm their own before they can use the app. It must differ from the default.
- After that, therapists and parents can't change their password themselves; only the admin's reset can. A database trigger (`guard_password_change`) enforces this even through the API: it allows exactly one self-change while the default is in use.
- "Reset password" on a child's or therapist's profile brings the default back and shows it with a copy button, ready to send. The profile shows whether the person is still on the default. While they are, editing the name's first letter or the date of birth updates the default and shows the new details.
- Admins can change their own password from the account sheet.
- Logins are managed by the `accounts` Edge Function (`supabase/functions/accounts`); it is the only code that uses the service role.

## Admin

| Tab / card | What it does |
| --- | --- |
| Home | Today's time slots (tap → sessions → session details), quick cards, last week's fee collection, "needs attention" (absences, reschedule requests, payments to verify, fees due) |
| Our therapies | Therapies offered and their standard fee **per session** |
| Timetable | Pick a week → create time slots (optionally Mon–Fri) → create sessions inside a slot. Every session has a therapy, a therapist and children. Grid view and day view |
| Children | Auto-numbered IDs (C001…). Adding a child asks **"Is an assessment needed?"**: Yes requires a completed Pediatric OT assessment ("Attend Assessment", above the therapies); No (e.g. assessed on paper before) adds the child without one. Profile with a **New assessment** button, assessment history, an assessment progress chart, therapies with **this child's fee per session** (e.g. Speech ₹3,000 → ₹300 for one child), weekly fee summary, progress charts with a day-by-day view (read-only) |
| Therapists | Auto-numbered IDs (T001…), specialisations, salary, weekly load, add/edit form |
| Fees | Week by week per child: sessions allocated / attended, fee per session per therapy, total, paid, due. Record cash/bank payments, verify UPI payments, reverse an invalid one, UPI ID settings |
| Reschedule requests | Families' requests to move a session or all sessions at that time; approve with a new day/time (clashes shown first) or turn down with a note |
| Messages | A chat with each child's family: inbox with unread counts, live updates, read ticks (therapists have no access) |

## Therapist

| Tab | What it does |
| --- | --- |
| Today | Live/next/done timeline of my sessions; one-tap Present / Late / Absent per child, "Mark all present", parent absence notices on the child |
| Session (tap a session) | Attendance, then for each child who came a **0–10 rating** and a description for the parents (autosaves). Only the session's therapist can rate |
| Week | My week by day, with what is still to mark |
| Children | My children; detail has tap-to-call parents, assessment history (start a re-assessment, continue a draft, view or download a report), rating charts per therapy with a day view, recent notes |

## Parent

| Tab | What it does |
| --- | --- |
| Home | Next session with "Can't make it?", today's sessions, **today's progress** (ratings and descriptions), fee due, latest note |
| Schedule | Week by week, with ratings and notes; **Change time** on any upcoming session (this one, or every session at that time) and the centre's answer |
| Progress | Rating chart per therapy since the child joined; tap the chart or pick a day to read each session |
| Fees | Weekly bills (allocated, attended, fee per session, total), **Pay with UPI**, payment history with **Download receipt** |
| Messages | Chat with the centre about each child |

Children who share the family's phone number appear together (avatar chips at the top). A family whose
children have separate logins adds each one from the account sheet (tap the picture → **Add another child**)
and switches between them with one tap, like adding accounts in Instagram. Logins are remembered on the
device (refresh token only); signing out of one moves to the next.

## Pediatric OT assessment

The centre's 5-page paper form as a structured assessment (`lib/assessment/`). Every item of the form is listed once
in `catalog.dart`; the editor, progress, review, report and PDF are all built from it.

- **18 sections**, one per page: a section list on the left on wide screens, a scrolling strip on phones. Answers
  are one-tap pills (tap again to clear); follow-up questions appear only when an answer needs them (severity once a
  behaviour is Present, duration/triggers once a sensory concern is present, age once a milestone is Delayed,
  surgery details once Yes…). "Mark the rest" answers every item still empty in one go. Range of motion is a table
  on wide screens and one card per joint on phones, with one-tap 0–5 strength.
- **Autosave**: every change is saved about a second after typing pauses, and again on leaving the app. Saves
  carry a revision: if someone saved from another device in between, the editor stops and asks which version to
  keep. If the server can't be reached, the changes are kept in the app's private storage
  (`PendingAssessments`) and sent when the connection returns (also on the next start).
- **When adding a child** the form asks "Is an assessment needed?". *Yes*: the admin attends the assessment
  before the child exists (an *intake* assessment, `child_id` null), and `create_assessed_child` creates the child
  and attaches the completed assessment in one transaction. *No* (e.g. the child had the paper assessment): the
  child is created without one (`children.assessment_needed = false`) and their profile doesn't ask for one.
  `save_child` no longer creates children. An unfinished intake is offered again the next time a child is added.
- **New assessment** any time: a button on the admin's child profile header and in the Assessments section (also
  for therapists, for their children).
- **Assessment progress chart** on the child's profile for the admin, their therapists and the family (parent
  Progress tab), from completed assessments (`scores.dart`). Criterion-referenced, with no invented weights: each
  answer is *at the expected level* (Present, Normal, Independent, No concern, behaviour Absent…), *developing*
  (Delayed, Emerging, with difficulty / needs assistance, mild behaviour…) or *not yet*; "Not assessed" and "Not
  applicable" are left out. An area's score is the share of its assessed items at the expected level; Overall
  counts all assessed items together; muscle strength stays on its own 0–5 grade scale. The card shows one line
  over time (Overall or a chosen area), the latest assessment by area split into the three levels, and **what
  changed item by item** since the previous assessment ("Walking: Delayed → Present"). The rules shown under "How
  this is worked out" are generated from the same mapping. Families get results only, through
  `assessment_timeline`: no notes, history or plans.
- **Completing** goes through a review of every section. Only the essentials block it (therapist, dates, name,
  date of birth, gender, chief complaints, one problem with its treatment plan); the server checks the same
  (`private.assessment_gaps`), also when a completed assessment is edited later.
- **History**: each assessment is its own record (Initial, Re-assessment, Follow-up). A re-assessment can start
  pre-filled from the last one; items keep stable keys and goals link to the goal they came from
  (`source_goal_id`), so progress can be compared later. Unfinished drafts can be deleted; finished ones are
  archived (admin), never deleted.
- **Who**: the admin sees and edits all; therapists see the assessments of children in their sessions, can edit
  unfinished ones and the completed ones they did. Parents have no access. The tables are read-only to the app
  (RLS); all writes are security-definer functions that check permissions.
- **PDF**: "Download PDF" draws the report from the data (`pdf.dart`), section by section.

Terms to confirm with the centre (kept exactly as on the form, not changed): "Pulp to Pulp" and "Pad to Pad" are
listed separately under Prehension; the reflex answers ("Present / Retained", …) are offered for both primitive and
deep tendon reflexes as specified; "Quadrupod / Digital" is one pencil-grasp option.

## Layout

| Path | What lives there |
| --- | --- |
| `lib/models.dart` | One class per table, parsed from Supabase rows |
| `lib/store.dart` | App state, loading (timetable weeks are loaded on demand), realtime, conflict checks, fee maths |
| `lib/actions.dart` | Every write; multi-row writes go through database functions so they are atomic |
| `lib/screens/admin` | Home, timetable (week list, week grid/day view, slot & session sheets), children, therapists, fees, therapies |
| `lib/screens/therapist`, `lib/screens/parent` | The therapist and parent experiences |
| `lib/widgets` | Shared UI kit, bottom-navigation shell, level chart, account sheet / tap-to-call |

## Brand

Nuvara navy `#010039`, orange `#EA501E` and sky `#36A9E0`, taken from the logo (`nuvara.jpeg`). The mark is
drawn in code (`lib/widgets/brand.dart`) from a vector trace kept in `tool/nuvara_mark.json`, so it stays sharp
and can animate on the splash. Regenerate every launcher icon (Android, iOS, web, Windows) with
`python tool/make_icons.py`. Parent and therapist logins use internal emails on `@parent.nuvara.app` /
`@therapist.nuvara.app`, derived from the child ID or mobile number the person types.

## Rules the database enforces

- A therapist or a child can never be in two sessions that overlap in time (Postgres exclusion constraints);
  the session form also explains who is busy before you save.
- Fees are weekly (Monday–Sunday) and only for attended sessions. Marking a child present or late fixes that
  session's price (`session_children.rate`) from the child's own fee or the therapy's base fee, so later price
  changes never rewrite a past week. `fee_weeks()` builds every bill from those rows.
- Attendance opens 15 minutes before a session and can be changed until it ends. After the end a child who was
  never marked can still be marked once; marks already given are final. A finished session isn't "completed"
  until every child is marked. Once a week has a payment verifying or confirmed, nothing in it can change.
- Progress is a 0–10 rating + description per child per session, given only by that session's therapist, from
  the start until 24 hours after the end.
- A payment can never exceed what is still due for that week.
- Parents see only children whose contact number matches their profile phone; therapists see only children in
  their sessions; salaries are admin-only.

## Release builds

1. **Signing key (once).** Create an upload key and keep it, and its passwords, somewhere safe outside the repo;
   losing it means no more updates under the same app:
   ```
   keytool -genkey -v -keystore ~/nuvara-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Then create `android/key.properties` (git-ignored):
   ```
   storeFile=C:/Users/you/nuvara-upload.jks
   storePassword=…
   keyAlias=upload
   keyPassword=…
   ```
   Without this file a release build is signed with the debug key and Gradle prints a warning: never ship that.
2. **A release env file** with only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` (no `TEST_PASSWORD`), e.g. `.env.release`.
3. **Bump `version:`** in `pubspec.yaml` (`1.0.1+2`: the number after `+` must go up on every release).
4. **Build** (keep `build/symbols/<version>` to read crash stacks later):
   ```
   flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/1.0.1 --dart-define-from-file=.env.release --dart-define=APP_VERSION=1.0.1
   flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols/1.0.1 --dart-define-from-file=.env.release --dart-define=APP_VERSION=1.0.1
   ```
   The app bundle is for Google Play; the per-ABI APKs (about 20 MB each) are for installing directly.

Android backups and phone-to-phone transfers exclude the app's data (`android:allowBackup="false"` and
`res/xml/data_extraction_rules.xml`), so sign-in tokens and children's details never leave the phone.
Uncaught errors in release builds are sent to the `client_errors` table (read it in the Supabase dashboard).

## Offline

Each login keeps a small snapshot on its phone (`lib/offline.dart`): the profile and the centre's lists, this week
and next (last week too for therapists), the last four weeks of bills plus anything still owed, the newest 40
messages per conversation, open requests and, for families, the progress charts. It is capped at 600 KB, kept in
the app's cache folder (never backed up), expires after 14 days and is deleted when that login signs out.

If the server can't be reached when the app opens, or a request fails for lack of network, the app shows the saved
data under a bar that says "You're offline · showing data from …" with Retry. It retries on its own (10 s up to
2 min apart) and as soon as the app comes back to the foreground; saving anything while offline says it didn't go
through. When the connection returns everything reloads and the bar says "Back online".

## Backend (Supabase project "Nuvara")

Schema, access rules and database functions are in `supabase/migrations` (applied to the project):
reset → core schema → demo seed → single read policy per table → monthly fee backfill → drop sessions left empty → attendance, notes, absence notices and level history → review fixes → sign-in accounts and messages → admin-managed passwords → set your own password at first sign-in → weekly fees, UPI payments, ratings and reschedule requests. The demo seed links the parent test account
to Aarav and Anaya through the contact number `+91 98765 43210`.

## Tests

`flutter test` runs scheduling/fee/formatting unit tests, a render test that opens every screen, sheet and form
at seven sizes from a 320px phone to a 1920px desktop (failing on any overflow or collapsed page), and `test/live_test.dart` (tag `live`), which signs in as each test account against
the real project and checks what each role can see and that the database rejects double-booking, overpayment
and non-admin writes.

```
flutter test --exclude-tags live                          # offline suite, as CI runs it
flutter test --tags live --dart-define-from-file=.env     # live suite against the real project
```

The live suite is skipped when `.env` isn't passed. GitHub Actions (`.github/workflows/ci.yml`) runs
`flutter analyze` and the offline suite on every push to `main` and every pull request.

## Paying fees with UPI

No gateway is used (no 2% fee). The centre adds its UPI IDs under Fees → UPI IDs and picks the active one.

1. **Pay** asks the server for a payment (`start_upi_payment`). The server decides the amount (what is still
   due for that finished week), copies the active UPI ID onto the payment and gives it a one-time reference.
   The app can't change any of these.
2. Android shows **Pay with**, so the parent chooses their UPI app (Google Pay, PhonePe, Paytm, BHIM…). The
   intent carries the payee, amount and reference (`MainActivity.kt`, channel `nuvara/upi`).
3. The UPI app's reply goes to `complete_upi_payment`. The server only accepts it if it refers to this
   payment's reference, and only if its bank reference (UTR) has never been used before. **SUCCESS** with a
   UTR: paid, with a receipt number. **FAILURE**: nothing changes.
4. No clear reply (app killed, an app that doesn't report back, or a QR payment on iPhone or desktop): the
   parent says whether they paid. **Yes** plus the UTR sends it to the admin to verify. **No** cancels it.
   Until then that week can't be paid again, so nobody pays twice.

Consistency: one open attempt per child and week (unique index), advisory locks per child and week across
payments and attendance, a unique UTR across all verifying and confirmed payments, and amounts and payees
fixed on the server. Switching the active UPI ID never affects a payment that has already started.

**Trust model.** As chosen, a UPI app's SUCCESS reply confirms a payment without a person checking it.
That reply passes through the parent's phone, so a tampered app could fake one. To limit this, Fees →
Verify lists every app-confirmed payment so the admin can spot-check it against the bank statement and
**Reverse** any that never arrived. Reversing voids the receipt and makes the week due again.

**Receipts** are never stored. **Download receipt** reads the payment and that week's bill from the database
and draws the PDF on the device (`lib/payments/receipt.dart`): share or save on phones, print or save as PDF
on desktop. A reversed payment produces no receipt.

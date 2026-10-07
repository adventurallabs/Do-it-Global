import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../assessment/history.dart';
import '../../assessment/progress_chart.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/account.dart' show callNumber;
import '../../widgets/progress.dart';
import '../../widgets/credentials.dart';
import '../../widgets/ui.dart';
import 'sessions.dart';

class ChildrenTab extends StatefulWidget {
  const ChildrenTab({super.key});

  @override
  State<ChildrenTab> createState() => _ChildrenTabState();
}

class _ChildrenTabState extends State<ChildrenTab> {
  String q = '';

  /// Bumped to reset the search field.
  int _search = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    // Inactive children stay findable but sort last.
    final list = [...store.children.where((c) => c.active && c.matches(q)), ...store.children.where((c) => !c.active && c.matches(q))];
    final inactive = store.children.length - store.activeChildren.length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-child',
        onPressed: () => context.push('/admin/children/new'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add child'),
        backgroundColor: C.brand700,
        foregroundColor: Colors.white,
      ),
      body: PageList(
        onRefresh: store.refresh,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: list.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ChildCard(list[i], onTap: () => context.push('/admin/children/${list[i].id}')),
        ),
        children: [
          TabHeader('Children', subtitle: '${plural(store.activeChildren.length, 'child', 'children')} at the centre${inactive > 0 ? ' · $inactive inactive' : ''}'),
          SearchField(key: ValueKey(_search), hint: 'Search by name or ID', onChanged: (v) => setState(() => q = v)),
          const SizedBox(height: 14),
          if (store.children.isEmpty)
            EmptyState(
              icon: Icons.child_care_rounded,
              title: 'No children yet',
              hint: 'Add a child with their therapies; families pay weekly for the sessions their child attends.',
              action: btn('Add child', icon: Icons.person_add_alt_1_rounded, kind: 'filled', onPressed: () => context.push('/admin/children/new')),
            )
          else if (list.isEmpty)
            EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No child matches "${q.trim()}"',
              hint: 'Try a name, or an ID like C004 or 4.',
              action: btn('Clear search', icon: Icons.close_rounded, onPressed: () => setState(() {
                q = '';
                _search++;
              })),
            ),
        ],
      ),
    );
  }
}

class ChildCard extends StatelessWidget {
  final Child child;
  final VoidCallback onTap;
  final Widget? trailing;
  const ChildCard(this.child, {super.key, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final ts = child.therapyIds.map(store.therapy).whereType<Therapy>().toList();
    final card = AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Avatar(child.name, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NameWithId(child.name, child.code),
                const SizedBox(height: 2),
                Text(ageLong(child.dob), style: body(12.5, color: C.muted)),
                if (store.isAdmin && store.dueTotal(child.id) > 0) ...[
                  const SizedBox(height: 6),
                  StatusChip('${money(store.dueTotal(child.id))} fee due', tone: Tone.red),
                ],
                if (!child.active) ...[const SizedBox(height: 6), const StatusChip('Inactive')],
                if (ts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final t in ts.take(3)) TherapyTag(t), if (ts.length > 3) StatusChip('+${ts.length - 3}', dot: false)]),
                ],
              ],
            ),
          ),
          trailing ?? const Icon(Icons.chevron_right_rounded, color: C.muted),
        ],
      ),
    );
    return child.active ? card : Opacity(opacity: 0.6, child: card);
  }
}

/// Someone's sign-in details for the admin to hand over. A login starts with the default [password];
/// the person sets their own at the first sign-in. "Reset password" brings the default back (shown to
/// copy) and they set a new one again.
class LoginCard extends StatelessWidget {
  final String title, who, loginLabel, loginId, password;
  final bool exists, paused;

  /// Still on the default password: they haven't signed in and set their own yet.
  final bool onDefault;

  /// Why a login can't be made yet (e.g. no phone number), with the way to fix it.
  final String? missing;
  final VoidCallback? onFix;
  final Future<void> Function() onCreate, onReset;
  const LoginCard({
    super.key,
    required this.title,
    required this.who,
    required this.loginLabel,
    required this.loginId,
    required this.password,
    required this.exists,
    required this.onCreate,
    required this.onReset,
    this.paused = false,
    this.onDefault = true,
    this.missing,
    this.onFix,
  });

  Future<void> _show(BuildContext context, String heading, String message) =>
      showLoginDetails(context, title: heading, message: message, loginLabel: loginLabel, loginId: loginId, password: password);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(Icons.key_rounded, size: 36),
              const SizedBox(width: 12),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w700))),
              const SizedBox(width: 8),
              Flexible(
                child: missing != null || !exists
                    ? const StatusChip('Not set up', tone: Tone.amber)
                    : paused
                    ? const StatusChip('Paused')
                    : const StatusChip('Active', tone: Tone.green),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (missing != null) ...[
            Text(missing!, style: body(13, color: C.muted, height: 1.4)),
            if (onFix != null) ...[const SizedBox(height: 12), btn('Add details', icon: Icons.edit_rounded, onPressed: onFix)],
          ] else ...[
            Row(
              children: [
                Expanded(child: KV(loginLabel, loginId, icon: Icons.badge_outlined)),
                const SizedBox(width: 8),
                Expanded(child: KV('Password', !exists ? 'Not created yet' : onDefault ? 'Default · not changed yet' : 'Their own', icon: Icons.lock_outline_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              !exists
                  ? 'No login yet. Create one, then share the details with $who.'
                  : onDefault
                  ? 'They\'ll be asked to set their own password the first time they sign in.'
                  : 'They have set their own password. If they forget it, reset it: the default comes back and they choose a new one when they sign in.',
              style: body(12.5, color: C.muted, height: 1.4),
            ),
            if (paused && exists) ...[
              const SizedBox(height: 6),
              Text('Paused while inactive: they can\'t sign in until reactivated.', style: body(12.5, weight: FontWeight.w600, color: C.amber, height: 1.4)),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (!exists)
                  ActionButton('Create login', icon: Icons.key_rounded, onPressed: () async {
                    await onCreate();
                    if (context.mounted) await _show(context, 'Login created', 'Share these details with $who. They\'ll set their own password the first time they sign in.');
                    return null;
                  })
                else ...[
                  ActionButton('Reset password', icon: Icons.lock_reset_rounded, kind: 'outlined', onPressed: () async {
                    final ok = await confirm(
                      context,
                      title: 'Reset the password?',
                      message: 'The password goes back to the default, and the current one stops working. They\'ll set a new one when they next sign in.',
                      action: 'Reset password',
                      danger: false,
                    );
                    if (!ok) return null;
                    await onReset();
                    if (context.mounted) await _show(context, 'Password reset', 'Send these details to $who. Their old password no longer works, and they\'ll set a new one when they sign in.');
                    return null;
                  }),
                  if (onDefault) btn('Show login details', icon: Icons.visibility_outlined, kind: 'text', onPressed: () => _show(context, title, 'Share these details with $who.')),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown on an inactive person's profile, with the way back.
class InactiveBanner extends StatelessWidget {
  final String text;
  final VoidCallback onReactivate;
  const InactiveBanner({super.key, required this.text, required this.onReactivate});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
    child: Row(
      children: [
        const Icon(Icons.pause_circle_outline_rounded, size: 20, color: C.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: body(12.5, weight: FontWeight.w600, color: C.muted, height: 1.35))),
        const SizedBox(width: 6),
        TextButton(onPressed: onReactivate, child: const Text('Reactivate')),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------

class ChildDetailScreen extends StatefulWidget {
  final String id;
  const ChildDetailScreen(this.id, {super.key});

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

/// How many weeks back "Recent notes" looks, including this one.
const _noteWeeks = 4;

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  bool _allNotes = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final monday = weekStart(todayISO());
    // Notes come from the loaded weeks; a week that fails to load is simply left out.
    // Next week too: "Next 7 days" runs into it from Tuesday on.
    Future.wait([for (var i = -1; i < _noteWeeks; i++) store.loadWeek(addDays(monday, -7 * i)).catchError((_) {})]).then((_) => store.touch());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final c = store.child(widget.id);
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.person_off_outlined,
            title: 'Child not found',
            hint: 'They may have been removed.',
            action: btn('Back to children', icon: Icons.arrow_back_rounded, onPressed: () => context.go('/admin/children')),
          ),
        ),
      );
    }
    final today = todayISO();
    final monday = weekStart(today);
    final due = store.dueTotal(c.id);
    final dueWeeks = store.dueBills(c.id);
    final thisWeek = store.bill(c.id, monday);

    // Past sessions from the loaded weeks that have something to tell: attendance, a note or a notice.
    final history = [
      for (var i = 0; i < _noteWeeks; i++)
        for (final s in store.sessionsOfChild(c.id, addDays(monday, -7 * i)))
          if (s.date.compareTo(today) <= 0)
            if (s.seat(c.id) case final seat? when seat.attendance != null || seat.note.trim().isNotEmpty || seat.noticed) (s: s, seat: seat),
    ]..sort((a, b) => '${b.s.date}${b.s.start}'.compareTo('${a.s.date}${a.s.start}'));
    final marked = history.where((h) => h.seat.attendance != null).toList();
    final attended = marked.where((h) => h.seat.attendance != 'absent').length;
    final shown = _allNotes ? history : history.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(c.code),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded), onPressed: () => Future.wait([store.refresh(), store.loadProgress(c.id, force: true)]).then((_) => store.touch())),
          IconButton(
            tooltip: 'Message family',
            icon: Badge(
              isLabelVisible: store.unreadIn(Convo.family(c.id)) > 0,
              label: Text('${store.unreadIn(Convo.family(c.id))}'),
              backgroundColor: C.clay600,
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            onPressed: () => context.push('/admin/messages/${c.id}'),
          ),
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/admin/children/${c.id}/edit')),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) => v == 'delete' ? _delete(c) : _setActive(c, !c.active),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'active',
                child: Row(
                  children: [
                    Icon(c.active ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, color: C.muted, size: 20),
                    const SizedBox(width: 10),
                    Text(c.active ? 'Mark as inactive' : 'Reactivate', style: body(14)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: C.red, size: 20),
                    const SizedBox(width: 10),
                    Text('Remove permanently', style: body(14, color: C.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: PageList(
        onRefresh: () => Future.wait([store.refresh(), store.loadProgress(c.id, force: true)]).then((_) => store.touch()),
        children: [
          _ProfileHeader(child: c, onNewAssessment: c.active ? () => startNewAssessment(context, c, '/admin/children/${c.id}') : null),
          if (!c.active) ...[
            const SizedBox(height: 12),
            InactiveBanner(
              text: '${c.first} is inactive and can\'t be added to sessions. Their history is kept.',
              onReactivate: () => _setActive(c, true),
            ),
          ],
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Overline('Family & contact'),
                Row(
                  children: [
                    Expanded(child: KV('Father', c.fatherName, icon: Icons.man_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: KV('Mother', c.motherName, icon: Icons.woman_rounded)),
                  ],
                ),
                const SizedBox(height: 10),
                _PhoneRow(label: 'Contact', number: c.phone, icon: Icons.call_rounded),
                if (c.altPhone.trim().isNotEmpty) _PhoneRow(label: 'Alternative', number: c.altPhone, icon: Icons.phone_forwarded_rounded),
                const SizedBox(height: 12),
                btn(
                  store.unreadIn(Convo.family(c.id)) > 0 ? 'Message family · ${store.unreadIn(Convo.family(c.id))} unread' : 'Message family',
                  icon: Icons.chat_bubble_outline_rounded,
                  kind: 'soft',
                  onPressed: () => context.push('/admin/messages/${c.id}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LoginCard(
            title: 'Parent login',
            who: 'the family',
            loginLabel: "Child's ID",
            loginId: c.code,
            password: defaultPassword(c.name, c.dob),
            exists: store.parentLogins.contains(c.id),
            onDefault: store.onDefaultPassword(store.parentProfileOf[c.id]),
            paused: !c.active,
            onCreate: () => store.syncChildLogin(c.id),
            onReset: () => store.resetParentPassword(c.id),
          ),
          const SizedBox(height: 22),
          AssessmentHistory(child: c, base: '/admin/children/${c.id}'),
          const SizedBox(height: 22),
          AssessmentProgressCard(child: c),
          const SizedBox(height: 22),
          SectionTitle('Therapies & fees', hint: c.therapies.isEmpty ? null : 'Charged per attended session'),
          if (c.therapies.isEmpty)
            EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'No therapies assigned',
              hint: 'Add therapies to ${c.first}\'s plan.',
              action: btn('Add therapies', icon: Icons.add_rounded, kind: 'filled', onPressed: () => context.push('/admin/children/${c.id}/edit')),
            )
          else
            AppCard(
              onTap: () => context.push('/admin/children/${c.id}/edit'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(children: [
                for (var i = 0; i < c.therapies.length; i++)
                  if (store.therapy(c.therapies[i].therapyId) case final t?) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: t.color, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w600))),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${money(store.rateOf(c.id, t.id))} / session', style: body(14, weight: FontWeight.w700).copyWith(fontFeatures: tnum)),
                          if (c.therapies[i].sessionFee != null) Text('Own fee · standard ${money(t.baseFee)}', style: body(11, weight: FontWeight.w600, color: C.green)),
                        ]),
                      ]),
                    ),
                  ],
              ]),
            ),
          const SizedBox(height: 22),
          SectionTitle(
            'Fees',
            action: TextButton(onPressed: () => context.push('/admin/fees/${c.id}'), child: const Text('Details')),
          ),
          AppCard(
            onTap: () => context.push('/admin/fees/${c.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(due > 0 ? 'Due now' : 'Nothing due', style: body(12, weight: FontWeight.w600, color: C.muted)),
                          Text(money(due), style: display(26, color: due > 0 ? C.clay600 : C.ink).copyWith(fontFeatures: tnum)),
                        ],
                      ),
                    ),
                    StatusChip(dueWeeks.isEmpty ? 'All paid' : '${plural(dueWeeks.length, 'week')} unpaid', tone: dueWeeks.isEmpty ? Tone.green : Tone.red),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  [
                    for (final w in dueWeeks) '${w.monday == monday ? 'This week' : 'Week of ${fmtDate(w.monday, 'd MMM')}'}: ${money(w.due)} due',
                    if (thisWeek != null && !thisWeek.payable) 'This week so far: ${thisWeek.attended} attended · ${money(thisWeek.amount)}${thisWeek.paid > 0 ? ' · paid' : ''}',
                    if (dueWeeks.isEmpty && thisWeek == null) 'Nothing billed this week yet.',
                  ].join('\n'),
                  style: body(12.5, color: C.muted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionTitle('Progress', hint: 'Rated by therapists after each session'),
          ProgressPanel(c),
          const SizedBox(height: 22),
          SectionTitle('Next 7 days', hint: nextSevenDaysLabel()),
          NextSevenDays((store, m) => store.sessionsOfChild(c.id, m), childId: c.id),
          const SizedBox(height: 22),
          SectionTitle(
            'Recent notes',
            hint: marked.isEmpty ? 'Last $_noteWeeks weeks' : 'Last $_noteWeeks weeks · attended $attended of ${plural(marked.length, 'session')}',
          ),
          if (history.isEmpty)
            EmptyState(
              icon: Icons.sticky_note_2_outlined,
              title: 'No notes yet',
              hint: 'Attendance and therapists\' notes from ${c.first}\'s sessions will appear here.',
              action: btn('Open timetable', icon: Icons.calendar_view_week_rounded, onPressed: () => context.push('/admin/timetable/$monday?view=day')),
            )
          else ...[
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < shown.length; i++) ...[if (i > 0) const Divider(indent: 16, endIndent: 16), _NoteRow(session: shown[i].s, seat: shown[i].seat)],
                ],
              ),
            ),
            if (history.length > shown.length || _allNotes && history.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: TextButton(
                    onPressed: () => setState(() => _allNotes = !_allNotes),
                    child: Text(_allNotes ? 'Show fewer' : 'Show all ${history.length}'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _setActive(Child c, bool active) async {
    final store = context.read<AppStore>();
    // Seats in upcoming sessions would still be billed once marked, so they come out with the child.
    var upcoming = <Session>[];
    if (!active) {
      try {
        await store.loadWeeksAhead();
      } catch (e) {
        if (mounted) toast(context, 'Couldn\'t check ${c.first}\'s upcoming sessions. ${cleanError(e)}', error: true);
        return;
      }
      if (!mounted) return;
      upcoming = store.upcomingSessions((s) => s.childIds.contains(c.id));
    }
    final alone = upcoming.where((s) => s.childIds.length == 1).length;
    final ok = await confirm(
      context,
      title: active ? 'Reactivate ${c.first}?' : 'Mark ${c.first} as inactive?',
      message: active
          ? 'They\'ll be billed again for sessions they attend, and can be added to sessions.'
          : upcoming.isEmpty
              ? 'An inactive child can\'t be added to sessions. Fees already owed stay due. Their sessions, notes, levels and fee history are kept, and you can reactivate them any time.'
              : '${c.first} is still in ${plural(upcoming.length, 'upcoming session')}, starting with "${upcoming.first.name}" on ${fmtDate(upcoming.first.date, 'EEE, d MMM')}. '
                  'They\'ll be taken out of ${upcoming.length == 1 ? 'it' : 'them'}${alone == 0 ? '' : ' (${alone == 1 ? 'a session' : '$alone sessions'} with no other children ${alone == 1 ? 'is' : 'are'} deleted)'}, so nothing more is billed. '
                  'Fees already owed stay due. Their notes, levels and fee history are kept, and you can reactivate them any time.',
      action: active ? 'Reactivate' : (upcoming.isEmpty ? 'Mark as inactive' : 'Remove from sessions & mark inactive'),
      danger: false,
    );
    if (!ok || !mounted) return;
    try {
      final removed = upcoming.isEmpty ? 0 : await store.removeChildFromSessions(c.id, upcoming);
      await store.setChildActive(c.id, active);
      if (mounted) {
        toast(context, store.loginWarning ?? (active ? '${c.first} is active again' : '${c.first} marked as inactive${removed == 0 ? '' : ' and taken out of ${plural(removed, 'session')}'}'),
            error: store.loginWarning != null);
      }
    } catch (e) {
      if (mounted) toast(context, cleanError(e), error: true);
    }
  }

  Future<void> _delete(Child c) async {
    final ok = await confirm(
      context,
      title: 'Remove ${c.name} permanently?',
      message: 'This deletes ${c.first} along with their assessments, fee and payment records. They are taken out of every session, and sessions left with no children are deleted. This cannot be undone.'
          '${c.active ? '\n\nTo stop billing but keep their history, use "Mark as inactive" instead.' : ''}',
      action: 'Remove',
    );
    if (!ok || !mounted) return;
    final store = context.read<AppStore>();
    final router = GoRouter.of(context);
    try {
      await store.deleteChild(c.id);
      router.pop();
      if (mounted) toast(context, '${c.name} removed');
    } catch (e) {
      if (mounted) toast(context, cleanError(e), error: true);
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  final Child child;
  final VoidCallback? onNewAssessment;
  const _ProfileHeader({required this.child, this.onNewAssessment});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [avatarColor(child.name), Color.lerp(avatarColor(child.name), Colors.black, 0.25)!]),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _identity(context),
      if (onNewAssessment != null) ...[
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onNewAssessment,
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.brand900, minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.assignment_add, size: 19),
            label: const Text('New assessment'),
          ),
        ),
      ],
    ]),
  );

  Widget _identity(BuildContext context) => Row(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Text(initials(child.name), style: display(24, color: Colors.white)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(child.name, style: display(23, color: Colors.white)),
              const SizedBox(height: 6),
              Row(
                children: [
                  IdBadge(child.code, light: true),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      ageLong(child.dob),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Born ${fmtDate(child.dob, 'd MMMM yyyy')}', style: body(12, color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
        ),
        if (child.phone.trim().isNotEmpty) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Call family',
            onPressed: () => callNumber(context, child.phone),
            style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.16), foregroundColor: Colors.white, minimumSize: const Size(46, 46)),
            icon: const Icon(Icons.call_rounded, size: 21),
          ),
        ],
      ],
    );
}

/// A phone number that calls when tapped.
class _PhoneRow extends StatelessWidget {
  final String label, number;
  final IconData icon;
  const _PhoneRow({required this.label, required this.number, required this.icon});

  @override
  Widget build(BuildContext context) {
    final has = number.trim().isNotEmpty;
    return InkWell(
      onTap: has ? () => callNumber(context, number) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: KV(label, number, icon: icon)),
            if (has)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: C.brand50, borderRadius: BorderRadius.circular(99)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.call_rounded, size: 15, color: C.brand700),
                    const SizedBox(width: 5),
                    Text('Call', style: body(12.5, weight: FontWeight.w700, color: C.brand700)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A past session from the child's point of view: when, with whom, attendance and the therapist's note.
class _NoteRow extends StatelessWidget {
  final Session session;
  final Seat seat;
  const _NoteRow({required this.session, required this.seat});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final note = seat.note.trim();
    final reason = (seat.absenceReason ?? '').trim();
    return InkWell(
      onTap: () => showSessionSheet(context, session.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Text(fmtDate(session.date, 'EEE'), style: body(11, weight: FontWeight.w700, color: C.muted)),
                  Text(fmtDate(session.date, 'd'), style: display(19)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(session.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 104),
                        child: seat.attendance == null && seat.noticed ? const AwayChip() : StatusChip(attendanceLabel(seat.attendance), tone: attendanceTone(seat.attendance)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtTime(session.start)} · ${store.therapistName(session.therapistId)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(12, color: C.muted),
                  ),
                  if (seat.noticed && reason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.event_busy_rounded, size: 15, color: C.amber),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Away · $reason', maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w600, color: C.amber))),
                      ]),
                    ),
                  if (note.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(10)),
                      child: Text(note, style: body(13, height: 1.4)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekSessionRow extends StatelessWidget {
  final Session session;
  final String? childId;
  const _WeekSessionRow({required this.session, this.childId});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final past = '${session.date} ${session.end}'.compareTo('${todayISO()} ${nowHM()}') < 0;
    final seat = childId == null ? null : session.seat(childId!);
    final chip = seat == null
        ? null
        : seat.attendance != null
            ? StatusChip(attendanceLabel(seat.attendance), tone: attendanceTone(seat.attendance))
            : seat.noticed
                ? const AwayChip()
                : null;
    return InkWell(
      onTap: () => showSessionSheet(context, session.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Column(
                children: [
                  Text(
                    fmtDate(session.date, 'EEE'),
                    style: body(11, weight: FontWeight.w700, color: C.muted),
                  ),
                  Text(fmtDate(session.date, 'd'), style: display(19, color: past ? C.muted : C.ink)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(14.5, weight: FontWeight.w700, color: past ? C.muted : C.ink),
                  ),
                  Text(
                    '${fmtSpan(session.start, session.end)} · ${store.therapistName(session.therapistId)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(12.5, color: C.muted),
                  ),
                ],
              ),
            ),
            if (chip != null) ...[const SizedBox(width: 8), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 104), child: chip)],
            const Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// [sessions] from today through six days ahead, soonest first: a profile's "Next 7 days", which on a Sunday
/// is mostly next week. Pass this week's and next week's sessions.
List<Session> nextSevenDays(Iterable<Session> sessions) {
  final today = todayISO(), last = addDays(today, 6);
  return [for (final s in sessions) if (s.date.compareTo(today) >= 0 && s.date.compareTo(last) <= 0) s]..sort((a, b) => '${a.date}${a.start}'.compareTo('${b.date}${b.start}'));
}

/// "4 Oct – 10 Oct".
String nextSevenDaysLabel() => '${fmtDate(todayISO(), 'd MMM')} – ${fmtDate(addDays(todayISO(), 6), 'd MMM')}';

/// "Next 7 days" on a profile: this week's and next week's sessions of one person (from [of]). Loads next week
/// once when it's needed (from Tuesday on) and shows a spinner, or a retry line if it failed, until it's there.
class NextSevenDays extends StatefulWidget {
  final List<Session> Function(AppStore store, String monday) of;
  final String? childId;
  const NextSevenDays(this.of, {super.key, this.childId});

  @override
  State<NextSevenDays> createState() => _NextSevenDaysState();
}

class _NextSevenDaysState extends State<NextSevenDays> {
  bool failed = false;

  String get _next => addDays(weekStart(todayISO()), 7);

  /// On a Monday the seven days end on Sunday, so next week isn't needed.
  bool get _needsNext => todayISO() != weekStart(todayISO());

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final store = context.read<AppStore>();
    if (!_needsNext || store.weekSlots(_next) != null) return;
    store.loadWeek(_next).then((_) => store.touch(), onError: (_) {
      if (mounted) setState(() => failed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final monday = weekStart(todayISO());
    if (_needsNext && store.weekSlots(_next) == null) {
      if (!failed) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
      return AppCard(
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: C.red),
          const SizedBox(width: 10),
          Expanded(child: Text("Couldn't load next week's sessions.", style: body(13, color: C.ink))),
          TextButton(
            onPressed: () {
              setState(() => failed = false);
              _load();
            },
            child: const Text('Try again'),
          ),
        ]),
      );
    }
    return WeekSessions(nextSevenDays([...widget.of(store, monday), ...widget.of(store, _next)]), childId: widget.childId);
  }
}

/// A day-by-day list of a person's sessions for the next 7 days (used on therapist profiles too). With
/// [childId], each row also shows that child's attendance or absence notice.
class WeekSessions extends StatelessWidget {
  final List<Session> sessions;
  final String? childId;
  const WeekSessions(this.sessions, {super.key, this.childId});

  @override
  Widget build(BuildContext context) => sessions.isEmpty
      ? EmptyState(
          icon: Icons.event_busy_outlined,
          title: 'No sessions in the next 7 days',
          hint: 'Sessions are planned in the weekly timetable.',
          action: btn('Open timetable', icon: Icons.calendar_view_week_rounded, onPressed: () => context.push('/admin/timetable/${weekStart(todayISO())}')),
        )
      : AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < sessions.length; i++) ...[if (i > 0) const Divider(indent: 16, endIndent: 16), _WeekSessionRow(session: sessions[i], childId: childId)],
            ],
          ),
        );
}

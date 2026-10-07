import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../actions.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/account.dart' show callNumber;
import '../../widgets/credentials.dart';
import '../../widgets/ui.dart';
import 'child_form.dart' show fmtPlain, phoneFormatter, validPhone;
import 'children.dart' show InactiveBanner, LoginCard, NextSevenDays, nextSevenDaysLabel;
import 'therapies.dart';

class TherapistsTab extends StatefulWidget {
  const TherapistsTab({super.key});

  @override
  State<TherapistsTab> createState() => _TherapistsTabState();
}

class _TherapistsTabState extends State<TherapistsTab> {
  String q = '';

  /// Bumped to reset the search field.
  int _search = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final monday = weekStart(todayISO());
    bool hit(Therapist t) => q.trim().isEmpty || t.name.toLowerCase().contains(q.trim().toLowerCase()) || matchesCode(q, 'T', t.no);
    // Inactive therapists stay findable but sort last.
    final list = [...store.therapists.where((t) => t.active && hit(t)), ...store.therapists.where((t) => !t.active && hit(t))];
    final inactive = store.therapists.length - store.activeTherapists.length;
    // Opened full screen from Home (no longer a tab), so it has its own back button.
    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-therapist',
        onPressed: () => context.push('/admin/therapists/new'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Create therapist'),
        backgroundColor: C.brand700,
        foregroundColor: Colors.white,
      ),
      body: PageList(
        onRefresh: store.refresh,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final t = list[i];
          final card = Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => context.push('/admin/therapists/${t.id}'),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Avatar(t.name, size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NameWithId(t.name, t.code),
                        const SizedBox(height: 2),
                        Text(
                          '${plural(store.sessionsOfTherapist(t.id, monday).length, 'session')} this week',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(12.5, color: C.muted),
                        ),
                        if (!t.active) ...[const SizedBox(height: 6), const StatusChip('Inactive')],
                        if (t.therapyIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final id in t.therapyIds)
                                if (store.therapy(id) case final x?) TherapyTag(x),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: C.muted),
                ],
              ),
            ),
          );
          return t.active ? card : Opacity(opacity: 0.6, child: card);
        },
        children: [
          TabHeader('Therapists', subtitle: '${plural(store.activeTherapists.length, 'therapist')} on the team${inactive > 0 ? ' · $inactive inactive' : ''}'),
          SearchField(key: ValueKey(_search), hint: 'Search by name or ID', onChanged: (v) => setState(() => q = v)),
          const SizedBox(height: 14),
          if (store.therapists.isEmpty)
            EmptyState(
              icon: Icons.badge_outlined,
              title: 'No therapists yet',
              hint: 'Add your therapists so you can assign them to sessions in the timetable.',
              action: btn('Create therapist', icon: Icons.person_add_alt_1_rounded, kind: 'filled', onPressed: () => context.push('/admin/therapists/new')),
            )
          else if (list.isEmpty)
            EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No therapist matches "${q.trim()}"',
              hint: 'Try a name, or an ID like T002 or 2.',
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

// ---------------------------------------------------------------------------

class TherapistDetailScreen extends StatelessWidget {
  final String id;
  const TherapistDetailScreen(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.therapist(id);
    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.person_off_outlined,
            title: 'Therapist not found',
            hint: 'They may have been removed.',
            action: btn('Back to therapists', icon: Icons.arrow_back_rounded, onPressed: () => context.canPop() ? context.pop() : context.push('/admin/therapists')),
          ),
        ),
      );
    }
    final d = t.details;
    final monday = weekStart(todayISO());
    final week = store.sessionsOfTherapist(t.id, monday)..sort((a, b) => '${a.date}${a.start}'.compareTo('${b.date}${b.start}'));
    final minutes = week.fold<int>(0, (a, s) => a + s.slot.minutes);
    final kids = {for (final s in week) ...s.childIds}.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.code),
        actions: [
          IconButton(
            tooltip: 'Message ${t.first}',
            icon: Badge(
              isLabelVisible: store.unreadIn(Convo.therapist(t.id)) > 0,
              label: Text('${store.unreadIn(Convo.therapist(t.id))}'),
              backgroundColor: C.clay600,
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            onPressed: () => context.push('/admin/messages/therapists/${t.id}'),
          ),
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/admin/therapists/${t.id}/edit')),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) => v == 'delete' ? _delete(context, store, t) : _setActive(context, store, t, !t.active),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'active',
                child: Row(
                  children: [
                    Icon(t.active ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, color: C.muted, size: 20),
                    const SizedBox(width: 10),
                    Text(t.active ? 'Mark as inactive' : 'Reactivate', style: body(14)),
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
        onRefresh: store.refresh,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [avatarColor(t.name), Color.lerp(avatarColor(t.name), Colors.black, 0.25)!]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
                      child: Text(initials(t.name), style: display(24, color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: display(23, color: Colors.white)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              IdBadge(t.code, light: true),
                              if (d?.dob != null) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    ageLong(d!.dob!).replaceFirst(' old', ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: body(13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(children: [_heroStat('${week.length}', 'Sessions'), _heroStat(minutesLabel(minutes).replaceAll(' min', 'm'), 'Scheduled'), _heroStat('$kids', 'Children')]),
              ],
            ),
          ),
          if (store.pendingReports.where((r) => r.therapistId == t.id).length case final n when n > 0) ...[
            const SizedBox(height: 12),
            AppCard(
              onTap: () => context.push('/admin/reports'),
              border: const Color(0xFFF2DFB4),
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(children: [
                const IconTile(Icons.rate_review_outlined, color: C.amber, size: 38),
                const SizedBox(width: 12),
                Expanded(child: Text('${plural(n, 'session report')} pending from ${t.first}', style: body(13.5, weight: FontWeight.w700, color: C.amber))),
                const Icon(Icons.chevron_right_rounded, color: C.muted),
              ]),
            ),
          ],
          if (!t.active) ...[
            const SizedBox(height: 12),
            InactiveBanner(
              text: '${t.first} is inactive and can\'t be picked for new sessions. Their history is kept.',
              onReactivate: () => _setActive(context, store, t, true),
            ),
          ],
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Overline('Details'),
                Row(
                  children: [
                    Expanded(child: KV('Date of birth', d?.dob == null ? '' : fmtDate(d!.dob!, 'd MMM yyyy'), icon: Icons.cake_outlined)),
                    Expanded(child: KV('Salary', d == null ? '' : '${money(d.salary)} / mo', icon: Icons.payments_outlined)),
                  ],
                ),
                const SizedBox(height: 10),
                _CallRow(label: 'Contact', number: d?.phone ?? '', icon: Icons.call_rounded),
                _CallRow(label: 'Emergency', number: d?.emergencyPhone ?? '', icon: Icons.emergency_outlined),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LoginCard(
            title: 'Therapist login',
            who: t.first,
            loginLabel: 'Mobile number',
            loginId: d?.phone.trim() ?? '',
            password: defaultPassword(t.name, d?.dob),
            exists: t.profileId != null,
            onDefault: store.onDefaultPassword(t.profileId),
            paused: !t.active,
            missing: (d?.phone.trim() ?? '').isEmpty
                ? 'Add ${t.first}\'s mobile number: it is their login ID.'
                : d?.dob == null
                ? 'Add ${t.first}\'s date of birth: it makes their password.'
                : null,
            onFix: () => context.push('/admin/therapists/${t.id}/edit'),
            onCreate: () => store.syncTherapistLogin(t.id),
            onReset: () => store.resetTherapistPassword(t.id),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Overline('Specialised in'),
                if (t.therapyIds.isEmpty)
                  Row(
                    children: [
                      Expanded(child: Text('No specialisation added', style: body(13.5, color: C.muted))),
                      TextButton(onPressed: () => context.push('/admin/therapists/${t.id}/edit'), child: const Text('Add')),
                    ],
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in t.therapyIds)
                        if (store.therapy(id) case final x?) TherapyTag(x),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionTitle('Next 7 days', hint: nextSevenDaysLabel()),
          NextSevenDays((store, m) => store.sessionsOfTherapist(t.id, m)),
        ],
      ),
    );
  }

  Widget _heroStat(String v, String l) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          v,
          style: display(21, color: Colors.white).copyWith(fontFeatures: tnum),
        ),
        Text(
          l,
          style: body(11.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75)),
        ),
      ],
    ),
  );

  /// Upcoming sessions of [t], after loading every planned week from this one on (the index says which), so
  /// a week nobody has opened on this device isn't missed. Null (with a message shown) if a week won't load.
  Future<List<Session>?> _upcoming(BuildContext context, AppStore store, Therapist t) async {
    try {
      await store.loadWeeksAhead();
    } catch (e) {
      if (context.mounted) toast(context, 'Couldn\'t check ${t.first}\'s upcoming sessions. ${cleanError(e)}', error: true);
      return null;
    }
    return store.upcomingSessions((s) => s.therapistId == t.id);
  }

  /// [t] still has [upcoming] sessions: they need another therapist before [then] ("mark Asha as inactive").
  Future<void> _reassignFirst(BuildContext context, Therapist t, List<Session> upcoming, String then) async {
    final first = upcoming.first;
    final open = await confirm(
      context,
      title: 'Reassign ${t.first}\'s sessions first',
      message: '${t.first} still has ${plural(upcoming.length, 'upcoming session')}, starting with "${first.name}" on ${fmtDate(first.date, 'EEE, d MMM')}. '
          'Give them to another therapist (or remove them), then $then.',
      action: 'Open timetable',
      danger: false,
    );
    if (open && context.mounted) context.push('/admin/timetable/${weekStart(first.date)}');
  }

  Future<void> _setActive(BuildContext context, AppStore store, Therapist t, bool active) async {
    if (!active) {
      final upcoming = await _upcoming(context, store, t);
      if (upcoming == null || !context.mounted) return;
      if (upcoming.isNotEmpty) return _reassignFirst(context, t, upcoming, 'mark ${t.first} as inactive');
    }
    final ok = await confirm(
      context,
      title: active ? 'Reactivate ${t.first}?' : 'Mark ${t.first} as inactive?',
      message: active
          ? '${t.first} can be picked for sessions again.'
          : 'An inactive therapist can\'t be picked for new sessions. Their past sessions and details are kept, and you can reactivate them any time.',
      action: active ? 'Reactivate' : 'Mark as inactive',
      danger: false,
    );
    if (!ok || !context.mounted) return;
    try {
      await store.setTherapistActive(t.id, active);
      if (context.mounted) toast(context, store.loginWarning ?? (active ? '${t.first} is active again' : '${t.first} marked as inactive'), error: store.loginWarning != null);
    } catch (e) {
      if (context.mounted) toast(context, cleanError(e), error: true);
    }
  }

  Future<void> _delete(BuildContext context, AppStore store, Therapist t) async {
    // Someone with sessions can't be deleted; retiring them keeps the history instead. Past weeks the device
    // hasn't loaded are caught by the database (the delete is refused); upcoming ones are loaded and checked.
    final upcoming = await _upcoming(context, store, t);
    if (upcoming == null || !context.mounted) return;
    // Upcoming sessions need another therapist whichever way they leave, so say that first.
    if (upcoming.isNotEmpty) return _reassignFirst(context, t, upcoming, t.active ? 'mark ${t.first} as inactive' : 'remove ${t.first}');
    final booked = {...store.weekIndex.keys, weekStart(todayISO())}.any((m) => store.sessionsOfTherapist(t.id, m).isNotEmpty);
    if (booked && t.active) {
      final retire = await confirm(
        context,
        title: 'Mark ${t.first} as inactive instead?',
        message: '${t.first} has past sessions in the timetable, so they can\'t be removed. Marking them inactive keeps their history and stops new bookings.',
        action: 'Mark as inactive',
        danger: false,
      );
      if (retire && context.mounted) await _setActive(context, store, t, false);
      return;
    }
    final ok = await confirm(
      context,
      title: 'Remove ${t.name} permanently?',
      message: 'This deletes the therapist and their details. This cannot be undone.'
          '${t.active ? '\n\nTo keep their history, use "Mark as inactive" instead.' : ''}',
      action: 'Remove',
    );
    if (!ok || !context.mounted) return;
    final router = GoRouter.of(context);
    try {
      await store.deleteTherapist(t.id);
      router.pop();
      if (context.mounted) toast(context, '${t.name} removed');
    } catch (e) {
      if (context.mounted) toast(context, cleanError(e), error: true);
    }
  }
}

/// A phone number with a Call action; shows a dash when empty.
class _CallRow extends StatelessWidget {
  final String label, number;
  final IconData icon;
  const _CallRow({required this.label, required this.number, required this.icon});

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

// ---------------------------------------------------------------------------

class TherapistFormScreen extends StatefulWidget {
  final String? therapistId;
  const TherapistFormScreen({super.key, this.therapistId});

  @override
  State<TherapistFormScreen> createState() => _TherapistFormScreenState();
}

class _TherapistFormScreenState extends State<TherapistFormScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final emergency = TextEditingController();
  final salary = TextEditingController();
  String? dob;
  final List<String> therapies = [];
  bool tried = false, dirty = false;

  @override
  void initState() {
    super.initState();
    final t = widget.therapistId == null ? null : context.read<AppStore>().therapist(widget.therapistId);
    if (t != null) {
      name.text = t.name;
      therapies.addAll(t.therapyIds);
      final d = t.details;
      if (d != null) {
        dob = d.dob;
        phone.text = d.phone;
        emergency.text = d.emergencyPhone;
        salary.text = fmtPlain(d.salary);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [name, phone, emergency, salary]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() => dirty = true);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final editing = widget.therapistId != null;
    final err = <String, String?>{
      'name': tried && name.text.trim().isEmpty ? 'Enter the therapist\'s name' : null,
      'phone': tried && !validPhone(phone.text) ? 'Enter a 10-digit contact number' : null,
      'emergency': emergency.text.trim().isNotEmpty && !validPhone(emergency.text) ? 'Enter a 10-digit number or leave it empty' : null,
      'salary': tried && parseMoney(salary.text) == null ? 'Enter the monthly salary' : null,
      'dob': tried && dob == null ? 'Select the date of birth' : null,
    };

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context, title: 'Discard changes?', message: 'What you entered for this therapist will be lost.', action: 'Discard');
        if (leave && context.mounted) {
          setState(() => dirty = false);
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(editing ? 'Edit therapist' : 'Create therapist')),
        // White right down to the screen edge; SafeArea inside keeps the button above the system bar.
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: C.line)),
          ),
          child: SafeArea(
            top: false,
            child: Constrained(
              child: ActionButton(editing ? 'Save changes' : 'Create therapist', icon: Icons.check_rounded, large: true, onPressed: () => _save(store, err)),
            ),
          ),
        ),
        body: PageList(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Field(
                    'Therapist name',
                    child: TextField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      style: body(15),
                      onChanged: (_) => _changed(),
                      decoration: InputDecoration(hintText: 'Full name', errorText: err['name']),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Field(
                    'Date of birth',
                    hint: dob == null || name.text.trim().isEmpty
                        ? 'Needed for their password: initial + date of birth, e.g. P12041991.'
                        : 'Their password will be ${defaultPassword(name.text, dob)}.',
                    child: PickerField(
                      text: dob == null ? 'Select date' : '${fmtDate(dob!, 'd MMMM yyyy')}  ·  ${ageLong(dob!).replaceFirst(' old', '')}',
                      placeholder: dob == null,
                      error: err['dob'],
                      icon: Icons.cake_outlined,
                      onTap: () async {
                        final d = await pickDate(context, initial: dob ?? addDays(todayISO(), -365 * 28), last: DateTime.now(), help: 'Date of birth');
                        if (d != null) {
                          setState(() {
                            dob = d;
                            dirty = true;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Field(
                    'Contact number',
                    child: TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [phoneFormatter],
                      style: body(15).copyWith(fontFeatures: tnum),
                      onChanged: (_) => _changed(),
                      decoration: InputDecoration(
                        hintText: '98765 43210',
                        errorText: err['phone'],
                        prefixIcon: const Icon(Icons.call_rounded, size: 18, color: C.muted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Field(
                    'Emergency contact number',
                    optional: true,
                    child: TextField(
                      controller: emergency,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [phoneFormatter],
                      style: body(15).copyWith(fontFeatures: tnum),
                      onChanged: (_) => _changed(),
                      decoration: InputDecoration(
                        hintText: 'Someone to call in an emergency',
                        errorText: err['emergency'],
                        prefixIcon: const Icon(Icons.emergency_outlined, size: 18, color: C.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Specialised in', style: body(12.5, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Pick existing therapies or create a new one.', style: body(12.5, color: C.muted)),
                  const SizedBox(height: 12),
                  TherapyPicker(
                    selected: therapies.toSet(),
                    onToggle: (id) => setState(() {
                      dirty = true;
                      therapies.contains(id) ? therapies.remove(id) : therapies.add(id);
                    }),
                    onCreated: (t) => setState(() {
                      dirty = true;
                      if (!therapies.contains(t.id)) therapies.add(t.id);
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Field(
                'Salary per month',
                child: MoneyField(controller: salary, error: err['salary'], onChanged: (_) => _changed()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _save(AppStore store, Map<String, String?> err) async {
    setState(() => tried = true);
    final pay = parseMoney(salary.text);
    if (name.text.trim().isEmpty || dob == null || !validPhone(phone.text) || err['emergency'] != null || pay == null) throw Exception('Please fix the highlighted fields.');
    final router = GoRouter.of(context);
    final nav = Navigator.of(context, rootNavigator: true);
    final editing = widget.therapistId != null;
    final before = editing ? store.therapist(widget.therapistId) : null;
    final hadLogin = before?.profileId != null;
    final id = await store.saveTherapist(id: widget.therapistId, name: name.text, dob: dob, phone: phone.text, emergencyPhone: emergency.text, salary: pay, therapyIds: therapies);
    final password = defaultPassword(name.text, dob);
    final login = phone.text.trim();
    final hasLogin = store.therapist(id)?.profileId != null;
    var warning = store.loginWarning;
    // Until they set their own password, it's the default made from the name and date of birth, so it
    // follows them when they change. A password the therapist chose is never touched.
    final onDefault = store.onDefaultPassword(store.therapist(id)?.profileId);
    var reset = false;
    if (editing && hadLogin && hasLogin && onDefault && warning == null && defaultPassword(before!.name, before.details?.dob) != password) {
      try {
        await store.resetTherapistPassword(id);
        reset = true;
      } catch (e) {
        warning = 'Saved, but the password could not be updated: ${cleanError(e)} Use "Reset password" on the profile.';
      }
    }
    final loginMoved = editing && hadLogin && (before!.details?.phone ?? '').replaceAll(RegExp(r'\D'), '') != login.replaceAll(RegExp(r'\D'), '');
    setState(() => dirty = false);
    await WidgetsBinding.instance.endOfFrame;
    if (editing) {
      router.pop();
    } else {
      router.pushReplacement('/admin/therapists/$id');
    }
    if (warning != null) return warning;
    final first = firstWord(name.text.trim());
    // Once they use their own password, a new mobile number only changes the ID they sign in with.
    if (loginMoved && !onDefault) return 'Saved · $first now signs in with $login';
    if (hasLogin && (!editing || reset || loginMoved)) {
      await WidgetsBinding.instance.endOfFrame;
      if (!nav.mounted) return null;
      showLoginDetails(
        nav.context,
        title: editing ? 'New login details for $first' : '$first added',
        message: editing
            ? 'Their ${[if (loginMoved) 'mobile number', if (reset) 'password'].join(' and ')} changed. Send the new details to $first.'
            : 'Share these with $first. They\'ll set their own password the first time they sign in.',
        loginLabel: 'Mobile number',
        loginId: login,
        password: password,
      );
      return null;
    }
    return editing ? 'Changes saved' : '$first added';
  }
}

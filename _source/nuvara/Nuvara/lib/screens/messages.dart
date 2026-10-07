import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../actions.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/account.dart';
import '../widgets/shell.dart' show Logo;
import 'parent/kit.dart' show ChildSwitcher;
import '../widgets/ui.dart';

// Messages, like a chat app. The centre (admin) has one conversation with each child's family and one with
// each therapist. Families and therapists only ever talk to the centre, never to each other (the database
// enforces it).

String _when(DateTime t) {
  final d = iso(t);
  if (d == todayISO()) return fmtAt(t, 'h:mm a');
  if (d == addDays(todayISO(), -1)) return 'Yesterday';
  if (t.isAfter(DateTime.now().subtract(const Duration(days: 6)))) return fmtAt(t, 'EEE');
  return fmtAt(t, 'd MMM');
}

String familyName(Child c) => [c.motherName, c.fatherName].where((n) => n.trim().isNotEmpty).join(' & ');

/// Where a conversation opens, for each role.
String chatPath(AppStore store, Convo c) => switch (store.role) {
      Role.admin => c.therapist ? '/admin/messages/therapists/${c.id}' : '/admin/messages/${c.id}',
      Role.parent => '/parent/messages/${c.id}',
      _ => '/therapist/messages',
    };

// ---------------------------------------------------------------------------
// Admin: Parents and Therapists

class AdminInbox extends StatelessWidget {
  const AdminInbox({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unread = store.unreadMessages;
    final families = store.threads, staff = store.therapistThreads;
    return PageList(
      onRefresh: store.refresh,
      children: [
        TabHeader('Messages', subtitle: unread == 0 ? 'Families and therapists' : plural(unread, 'unread message')),
        _HubCard(
          icon: Icons.family_restroom_rounded,
          color: const Color(0xFFC2622D),
          title: 'Parents',
          hint: 'Each child\'s family',
          conversations: families.length,
          unread: store.unreadFromFamilies,
          last: families.firstOrNull == null ? null : (who: store.child(families.first.id)?.first ?? 'Family', m: families.first.last),
          onTap: () => context.push('/admin/messages/parents'),
        ),
        const SizedBox(height: 12),
        _HubCard(
          icon: Icons.badge_rounded,
          color: const Color(0xFF3D64A8),
          title: 'Therapists',
          hint: 'Your team',
          conversations: staff.length,
          unread: store.unreadFromTherapists,
          last: staff.firstOrNull == null ? null : (who: store.therapist(staff.first.id)?.first ?? 'Therapist', m: staff.first.last),
          onTap: () => context.push('/admin/messages/therapists'),
        ),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lock_outline_rounded, size: 16, color: C.muted),
          const SizedBox(width: 8),
          Expanded(child: Text('Families and therapists each talk only with the centre. They can\'t message one another.', style: body(12.5, color: C.muted, height: 1.4))),
        ]),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, hint;
  final int conversations, unread;
  final ({String who, Message m})? last;
  final VoidCallback onTap;
  const _HubCard({required this.icon, required this.color, required this.title, required this.hint, required this.conversations, required this.unread, required this.last, required this.onTap});

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            backgroundColor: C.clay600,
            child: IconTile(icon, color: color, size: 52),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: display(21)),
              const SizedBox(height: 2),
              Text(
                last == null ? '$hint · no conversations yet' : '${last!.m.fromAdmin ? 'You' : last!.who}: ${last!.m.body.replaceAll('\n', ' ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(13, weight: unread > 0 ? FontWeight.w700 : FontWeight.w400, color: unread > 0 ? C.ink : C.muted),
              ),
              const SizedBox(height: 2),
              Text(
                [plural(conversations, 'conversation'), if (unread > 0) '$unread unread', if (last != null) _when(last!.m.at)].join(' · '),
                style: body(12, weight: FontWeight.w600, color: unread > 0 ? C.brand700 : C.muted),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
      );
}

/// Everyone the admin can message on one side (families or therapists): conversations first, newest on
/// top, then everyone else so a new conversation is one tap away. Searchable by name or ID.
class AdminPeople extends StatefulWidget {
  final bool therapists;
  const AdminPeople({super.key, required this.therapists});

  @override
  State<AdminPeople> createState() => _AdminPeopleState();
}

class _AdminPeopleState extends State<AdminPeople> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = widget.therapists;
    final threads = {for (final x in t ? store.therapistThreads : store.threads) x.id: x};
    final people = <({String id, String name, String code, String sub})>[
      if (t)
        for (final p in store.therapists)
          if (p.active || threads.containsKey(p.id))
            if (q.trim().isEmpty || p.name.toLowerCase().contains(q.trim().toLowerCase()) || matchesCode(q, 'T', p.no))
              (id: p.id, name: p.name, code: p.code, sub: p.therapyIds.map(store.therapyName).join(', ')),
      if (!t)
        for (final c in store.children)
          if (c.active || threads.containsKey(c.id))
            if (c.matches(q) || familyName(c).toLowerCase().contains(q.trim().toLowerCase())) (id: c.id, name: c.name, code: c.code, sub: familyName(c).isEmpty ? 'Family' : familyName(c)),
    ];
    final order = {for (final (i, x) in (t ? store.therapistThreads : store.threads).indexed) x.id: i};
    people.sort((a, b) {
      final x = order[a.id], y = order[b.id];
      if (x != null || y != null) return x == null ? 1 : (y == null ? -1 : x.compareTo(y));
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    final unread = t ? store.unreadFromTherapists : store.unreadFromFamilies;
    return Scaffold(
      appBar: AppBar(title: Text(t ? 'Therapists' : 'Parents')),
      body: PageList(
        onRefresh: store.refresh,
        itemCount: people.length,
        itemBuilder: (_, i) {
          final p = people[i];
          final th = threads[p.id];
          final convo = t ? Convo.therapist(p.id) : Convo.family(p.id);
          return GroupedRow(
            index: i,
            count: people.length,
            indent: 76,
            child: _ThreadRow(name: p.name, code: p.code, sub: p.sub, last: th?.last, unread: th?.unread ?? 0, onTap: () => context.push(chatPath(store, convo))),
          );
        },
        children: [
          Text(
            unread > 0 ? '${plural(unread, 'unread message')} · ${plural(threads.length, 'conversation')}' : (t ? 'Message any therapist. Only you and they see the conversation.' : 'Message any child\'s family. Search by child, ID or parent name.'),
            style: body(13, color: C.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          SearchField(hint: t ? 'Search therapist by name or ID' : 'Search by child, ID or parent', onChanged: (v) => setState(() => q = v)),
          const SizedBox(height: 14),
          if (people.isEmpty)
            EmptyState(
              icon: q.trim().isEmpty ? Icons.forum_outlined : Icons.search_off_rounded,
              title: q.trim().isEmpty ? (t ? 'No therapists yet' : 'No children yet') : 'Nobody matches "${q.trim()}"',
            ),
        ],
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final String name, code, sub;
  final Message? last;
  final int unread;
  final VoidCallback onTap;
  const _ThreadRow({required this.name, required this.code, required this.sub, required this.last, required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final isUnread = unread > 0;
    final m = last;
    final mine = m != null && m.fromAdmin == store.isAdmin;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Avatar(name, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: NameWithId(name, code, style: body(15, weight: isUnread ? FontWeight.w800 : FontWeight.w600))),
                if (m != null) ...[
                  const SizedBox(width: 8),
                  Text(_when(m.at), style: body(11.5, weight: isUnread ? FontWeight.w800 : FontWeight.w500, color: isUnread ? C.brand700 : C.muted)),
                ],
              ]),
              const SizedBox(height: 3),
              Row(children: [
                if (mine) ...[_Ticks(read: m.readAt != null, size: 15), const SizedBox(width: 4)],
                Expanded(
                  child: Text(
                    m == null ? '$sub · tap to start a conversation' : '${mine ? 'You: ' : ''}${m.body.replaceAll('\n', ' ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(13, weight: isUnread ? FontWeight.w700 : FontWeight.w400, color: isUnread ? C.ink : C.muted),
                  ),
                ),
                if (isUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: C.brand700, borderRadius: BorderRadius.circular(99)),
                    child: Text('$unread', textAlign: TextAlign.center, style: body(11, weight: FontWeight.w800, color: Colors.white, height: 1.2)),
                  ),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Parent tab

/// One child: the conversation itself. Several children (siblings on the same phone): a short list.
class ParentMessages extends StatelessWidget {
  const ParentMessages({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final kids = store.children;
    if (kids.isEmpty) {
      return const PageList(children: [
        TabHeader('Messages'),
        EmptyState(icon: Icons.forum_outlined, title: 'No child linked yet', hint: 'Once the centre links your child to this account, you can message them here.'),
      ]);
    }
    if (kids.length == 1) {
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Constrained(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TabHeader('Messages', subtitle: 'Chat with the centre about ${kids.first.first}'),
              const ChildSwitcher(),
            ]),
          ),
        ),
        Expanded(child: ChatView(Convo.family(kids.first.id))),
      ]);
    }
    final threads = {for (final t in store.threads) t.id: t};
    return PageList(
      onRefresh: store.refresh,
      itemCount: kids.length,
      itemBuilder: (_, i) {
        final c = kids[i];
        final t = threads[c.id];
        return GroupedRow(
          index: i,
          count: kids.length,
          indent: 76,
          child: _ThreadRow(name: c.name, code: c.code, sub: 'The centre', last: t?.last, unread: t?.unread ?? 0, onTap: () => context.push('/parent/messages/${c.id}')),
        );
      },
      children: const [TabHeader('Messages', subtitle: 'Chat with the centre about each child')],
    );
  }
}

// ---------------------------------------------------------------------------
// Therapist tab

/// A therapist's one conversation: with the centre.
class TherapistMessages extends StatelessWidget {
  const TherapistMessages({super.key});

  @override
  Widget build(BuildContext context) {
    final id = context.select<AppStore, String?>((s) => s.therapistId);
    if (id == null) {
      return const PageList(children: [
        TabHeader('Messages'),
        EmptyState(icon: Icons.forum_outlined, title: 'Not linked yet', hint: 'Your login isn\'t linked to a therapist profile. Please contact the centre.'),
      ]);
    }
    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Constrained(child: TabHeader('Messages', subtitle: 'Chat with the centre')),
      ),
      Expanded(child: ChatView(Convo.therapist(id))),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Conversation

class ChatScreen extends StatelessWidget {
  final Convo convo;
  const ChatScreen(this.convo, {super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final String title, subtitle, avatar;
    String? phone;
    if (convo.therapist) {
      final t = store.therapist(convo.id);
      avatar = store.isAdmin ? (t?.name ?? '?') : '';
      title = store.isAdmin ? (t?.name ?? 'Therapist') : 'Nuvara centre';
      subtitle = store.isAdmin ? [t?.code ?? '', ...?t?.therapyIds.map(store.therapyName)].where((x) => x.isNotEmpty).join(' · ') : 'The centre';
      phone = store.isAdmin ? t?.details?.phone : null;
    } else {
      final c = store.child(convo.id);
      final family = c == null ? '' : familyName(c);
      avatar = store.isAdmin ? (c?.name ?? '?') : '';
      title = store.isAdmin ? "${c?.first ?? 'Child'}'s family" : 'Nuvara centre';
      subtitle = store.isAdmin ? '${c?.code ?? ''}${family.isEmpty ? '' : ' · $family'}' : 'About ${c?.first ?? 'your child'} · ${c?.code ?? ''}';
      phone = store.isAdmin ? c?.phone : null;
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          // The centre is shown as the Nuvara tile; people by their initials.
          if (avatar.isEmpty) const Logo(size: 38) else Avatar(avatar, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15.5, weight: FontWeight.w700)),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
            ]),
          ),
        ]),
        actions: [
          if (phone != null && phone.isNotEmpty) IconButton(tooltip: 'Call', icon: const Icon(Icons.call_outlined), onPressed: () => callNumber(context, phone!)),
        ],
      ),
      body: store.isAdmin && !convo.therapist && !store.parentLogins.contains(convo.id)
          ? Column(children: [_NoLoginBanner(childId: convo.id), Expanded(child: ChatView(convo))])
          : ChatView(convo),
    );
  }
}

/// The message list and composer for one conversation.
class ChatView extends StatefulWidget {
  final Convo convo;
  const ChatView(this.convo, {super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final input = TextEditingController();
  bool sending = false;
  int _seen = -1;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _send(AppStore store) async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    HapticFeedback.lightImpact();
    setState(() => sending = true);
    try {
      await store.sendMessage(widget.convo, text);
      input.clear();
    } catch (e) {
      if (mounted) toast(context, cleanError(e), error: true);
    }
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final msgs = store.thread(widget.convo);
    // Mark as read whenever a new message from the other side is on screen. Tabs (and routes underneath
    // another) stay alive offstage with tickers off: those must not mark anything read until shown again.
    final visible = TickerMode.valuesOf(context).enabled;
    final incoming = msgs.where((m) => m.fromAdmin != store.isAdmin && m.readAt == null).length;
    if (incoming == 0) _seen = 0;
    if (visible && incoming > 0 && incoming != _seen) {
      _seen = incoming;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) store.markThreadRead(widget.convo);
      });
    }
    // Newest at the bottom: the list is reversed, so build items newest-first with day separators.
    final items = <Object>[];
    for (var i = msgs.length - 1; i >= 0; i--) {
      items.add(msgs[i]);
      final day = iso(msgs[i].at);
      if (i == 0 || iso(msgs[i - 1].at) != day) items.add(day);
    }

    return Column(children: [
      Expanded(
        child: msgs.isEmpty
            // Scrolls so it still fits above the keyboard on short screens.
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 64, height: 64, decoration: const BoxDecoration(color: C.brand50, shape: BoxShape.circle), child: const Icon(Icons.forum_rounded, color: C.brand600, size: 30)),
                    const SizedBox(height: 14),
                    Text('Say hello', style: display(22)),
                    const SizedBox(height: 6),
                    Text(
                      _emptyHint(store, widget.convo),
                      textAlign: TextAlign.center,
                      style: body(13.5, color: C.muted, height: 1.45),
                    ),
                  ]),
                ),
              )
            : ListView.builder(
                reverse: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i];
                  if (it is String) return _DayChip(it);
                  final m = it as Message;
                  final mine = m.fromAdmin == store.isAdmin;
                  // Bubbles from the same side within 3 minutes sit closer together.
                  final newer = i > 0 && items[i - 1] is Message ? items[i - 1] as Message : null;
                  final grouped = newer != null && newer.fromAdmin == m.fromAdmin && newer.at.difference(m.at).inMinutes < 3;
                  return Constrained(child: _Bubble(m, mine: mine, tight: grouped));
                },
              ),
      ),
      _Composer(controller: input, sending: sending, onSend: () => _send(store)),
    ]);
  }
}

class _DayChip extends StatelessWidget {
  final String day;
  const _DayChip(this.day);

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.line)),
          child: Text(relDay(day), style: body(11.5, weight: FontWeight.w700, color: C.muted)),
        ),
      );
}

class _Bubble extends StatelessWidget {
  final Message m;
  final bool mine, tight;
  const _Bubble(this.m, {required this.mine, required this.tight});

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(18);
    final radius = BorderRadius.only(topLeft: r, topRight: r, bottomLeft: mine ? r : const Radius.circular(6), bottomRight: mine ? const Radius.circular(6) : r);
    return Padding(
      padding: EdgeInsets.only(top: tight ? 2 : 8),
      child: Row(mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 9, 11, 7),
              decoration: BoxDecoration(
                color: mine ? C.brand700 : Colors.white,
                borderRadius: radius,
                border: mine ? null : Border.all(color: C.line),
                boxShadow: const [BoxShadow(color: Color(0x0C010039), blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(m.body, style: body(14.5, color: mine ? Colors.white : C.ink, height: 1.35)),
                ),
                const SizedBox(height: 3),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(fmtAt(m.at, 'h:mm a'), style: body(10.5, weight: FontWeight.w600, color: mine ? C.brand200 : C.muted)),
                  if (mine) ...[const SizedBox(width: 4), _Ticks(read: m.readAt != null, onDark: true)],
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// ✓ sent, ✓✓ read.
class _Ticks extends StatelessWidget {
  final bool read, onDark;
  final double size;
  const _Ticks({required this.read, this.onDark = false, this.size = 14});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: read ? 'Read' : 'Sent',
        child: Icon(read ? Icons.done_all_rounded : Icons.done_rounded, size: size, color: read ? (onDark ? const Color(0xFF7DD3FC) : C.blue) : (onDark ? C.brand200 : C.muted)),
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: SafeArea(
          top: false,
          child: Constrained(
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  style: body(15),
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    counterText: '',
                    filled: true,
                    fillColor: C.canvas,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.brand300)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, v, _) {
                  final ready = v.text.trim().isNotEmpty && !sending;
                  return AnimatedScale(
                    scale: ready || sending ? 1 : 0.9,
                    duration: const Duration(milliseconds: 150),
                    child: IconButton.filled(
                      tooltip: 'Send',
                      onPressed: ready ? onSend : null,
                      // Stays brand-coloured while sending (disabled then), so the white spinner shows.
                      style: IconButton.styleFrom(
                        fixedSize: const Size(48, 48),
                        backgroundColor: C.brand700,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: sending ? C.brand700 : C.sand,
                        disabledForegroundColor: sending ? Colors.white : C.muted,
                      ),
                      icon: sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 20),
                    ),
                  );
                },
              ),
            ]),
          ),
        ),
      );
}

/// Admin, chatting with a family that has no parent login yet: they can't read anything sent here.
class _NoLoginBanner extends StatelessWidget {
  final String childId;
  const _NoLoginBanner({required this.childId});

  @override
  Widget build(BuildContext context) => Material(
        color: C.amberBg,
        child: InkWell(
          onTap: () => context.push('/admin/children/$childId'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Constrained(
              child: Row(children: [
                const Icon(Icons.no_accounts_outlined, size: 20, color: C.amber),
                const SizedBox(width: 10),
                Expanded(child: Text("No parent login yet — the family can't see messages", style: body(12.5, weight: FontWeight.w700, color: C.amber, height: 1.3))),
                Text('Set up', style: body(12.5, weight: FontWeight.w800, color: C.brand700)),
                const Icon(Icons.chevron_right_rounded, size: 20, color: C.brand700),
              ]),
            ),
          ),
        ),
      );
}

String _emptyHint(AppStore store, Convo c) {
  if (c.therapist) {
    return store.isAdmin
        ? 'Messages you send here reach ${store.therapist(c.id)?.first ?? 'this therapist'} in their app. Only the two of you see them.'
        : 'Questions about your sessions or schedule? Message the centre here.';
  }
  final kid = store.child(c.id)?.first;
  return store.isAdmin
      ? 'Messages you send here reach ${kid ?? 'this child'}\'s family in their app.'
      : 'Questions about ${kid ?? 'your child'}\'s sessions, fees or progress? The centre will reply here.';
}

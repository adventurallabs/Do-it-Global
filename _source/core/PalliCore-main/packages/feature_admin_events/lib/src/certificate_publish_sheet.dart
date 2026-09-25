import 'dart:typed_data';

import 'package:event_certificates/event_certificates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:printing/printing.dart';

/// Choosing the certificate a room's children will take home.
///
/// A layout covers both tiers, so the preview shows the winner's sheet and the
/// runner's sheet side by side — the admin is picking a pair, not a picture.
/// Publishing writes one row; the certificates themselves are drawn on each
/// parent's device when they ask for one.
class CertificatePublishSheet extends StatefulWidget {
  final SchoolEvent event;
  final EventCategory category;
  final EventRoom room;
  final List<EventStandingRecord> standings;
  final EventCertificate? current;

  const CertificatePublishSheet({
    super.key,
    required this.event,
    required this.category,
    required this.room,
    required this.standings,
    this.current,
  });

  static Future<bool?> open(
    BuildContext context, {
    required SchoolEvent event,
    required EventCategory category,
    required EventRoom room,
    required List<EventStandingRecord> standings,
    EventCertificate? current,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CertificatePublishSheet(
          event: event,
          category: category,
          room: room,
          standings: standings,
          current: current,
        ),
      ),
    );
  }

  @override
  State<CertificatePublishSheet> createState() => _CertificatePublishSheetState();
}

class _CertificatePublishSheetState extends State<CertificatePublishSheet> {
  SchoolProfile? _school;
  Uint8List? _logo;
  String? _selected;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.current?.layoutId;
    _load();
  }

  Future<void> _load() async {
    try {
      final school = await context.read<SchoolSettingsRepository>().get();
      final logo = await loadSchoolLogo(school.logoUrl);
      if (!mounted) return;
      setState(() {
        _school = school;
        _logo = logo;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// A sample drawn from this room's real result — the admin previews the
  /// certificate a specific child will actually get, not a lorem-ipsum one.
  CertificateData _sample(CertificateTier tier) {
    final winner = widget.standings.where((s) => s.standing.isWinner).firstOrNull;
    final runner = widget.standings.where((s) => !s.standing.isWinner).firstOrNull;
    final pick = tier == CertificateTier.winner ? winner : runner;
    return CertificateData(
      schoolName: _school?.name ?? '',
      schoolLogo: _logo,
      eventName: widget.event.name,
      categoryName: widget.category.name,
      roomName: widget.room.name,
      studentName: pick?.studentName ?? (tier.isWinner ? 'Winner' : 'Participant'),
      classLabel: pick?.classroomLabel ?? '',
      tier: tier,
      position: tier.isWinner ? (pick?.position ?? 1) : null,
      awardedOn: widget.room.submittedAt ?? widget.event.eventDate,
    );
  }

  Future<void> _preview(CertificateLayout layout) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PreviewScreen(
          layout: layout,
          winner: _sample(CertificateTier.winner),
          runner: _sample(CertificateTier.runner),
        ),
      ),
    );
  }

  Future<void> _publish() async {
    final layout = _selected;
    if (layout == null) return;
    final winners = widget.standings.where((s) => s.standing.isWinner).length;
    final runners = widget.standings.length - winners;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish these certificates?'),
        content: Text(
          'Every parent in ${widget.room.name} gets a download button: '
          '$winners winner${winners == 1 ? '' : 's'} and '
          '$runners runner${runners == 1 ? '' : 's'}.\n\n'
          'You can change the layout later — parents always download the '
          'current one.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publish')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<EventProgramRepository>().publishCertificates(
            roomId: widget.room.id,
            layoutId: layout,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(EventProgramRepository.describeError(e)),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final school = _school;
    final ready = school?.isReadyForCertificates ?? false;
    return Scaffold(
      appBar: AppBar(title: Text('Certificates · ${widget.room.name}', overflow: TextOverflow.ellipsis)),
      bottomNavigationBar: ready && !_loading
          ? StickyActionBar(
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _selected == null || _busy ? null : _publish,
                  icon: _busy
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 19),
                  label: Text(widget.current == null ? 'Confirm and publish' : 'Update layout'),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !ready
                ? _locked(school)
                : _layoutList(),
      ),
    );
  }

  Widget _locked(SchoolProfile? school) {
    final missing = school?.missingForCertificates ?? const ['school name', 'school logo'];
    return EmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'Certificates are locked',
      subtitle: 'Every layout carries your crest and your school\'s name. '
          'Add your ${missing.join(' and ')} on the admin home screen, then come back.',
    );
  }

  Widget _layoutList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: certificateLayouts.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
            child: Text(
              'Each layout includes a winner\'s certificate and a runner\'s. '
              'Preview shows both, drawn with this room\'s real names.',
              style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.onSurfaceMuted(context)),
            ),
          );
        }
        final layout = certificateLayouts[i - 1];
        return _LayoutTile(
          layout: layout,
          selected: _selected == layout.id,
          onSelect: () => setState(() => _selected = layout.id),
          onPreview: () => _preview(layout),
        );
      },
    );
  }
}

class _LayoutTile extends StatelessWidget {
  final CertificateLayout layout;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPreview;

  const _LayoutTile({
    required this.layout,
    required this.selected,
    required this.onSelect,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: onSelect,
      child: Row(
        children: [
          _Swatch(layout: layout, selected: selected),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(layout.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(layout.description,
                    style: TextStyle(fontSize: 12, height: 1.3, color: AppColors.onSurfaceMuted(context))),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onPreview,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('Preview certificate'),
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            color: selected ? AppColors.accent : AppColors.onSurfaceHint(context),
          ),
        ],
      ),
    );
  }
}

/// A tiny impression of the layout's palette, so the list reads as ten
/// different things before the admin opens any of them.
class _Swatch extends StatelessWidget {
  final CertificateLayout layout;
  final bool selected;
  const _Swatch({required this.layout, required this.selected});

  Color _c(int argb) => Color(argb);

  @override
  Widget build(BuildContext context) {
    final p = layout.palette;
    return Container(
      width: 56,
      height: 74,
      decoration: BoxDecoration(
        color: _c(p.paper.toInt()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.accent : _c(p.metal.toInt()).withValues(alpha: 0.5),
          width: selected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(height: 1.5, color: _c(p.metal.toInt())),
            const SizedBox(height: 6),
            Container(width: 16, height: 16,
                decoration: BoxDecoration(color: _c(p.metal.toInt()), shape: BoxShape.circle)),
            const SizedBox(height: 6),
            Container(height: 3, width: 30, color: _c(p.ink.toInt()).withValues(alpha: 0.65)),
            const SizedBox(height: 3),
            Container(height: 2, width: 20, color: _c(p.muted.toInt()).withValues(alpha: 0.6)),
            const SizedBox(height: 6),
            Container(height: 1.5, color: _c(p.metal.toInt())),
          ],
        ),
      ),
    );
  }
}

/// Winner and runner, in one scrollable preview.
class _PreviewScreen extends StatelessWidget {
  final CertificateLayout layout;
  final CertificateData winner;
  final CertificateData runner;

  const _PreviewScreen({required this.layout, required this.winner, required this.runner});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(layout.name, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(tabs: [Tab(text: 'Winner'), Tab(text: 'Runner')]),
        ),
        body: TabBarView(
          children: [
            _Pdf(layout: layout, data: winner),
            _Pdf(layout: layout, data: runner),
          ],
        ),
      ),
    );
  }
}

class _Pdf extends StatelessWidget {
  final CertificateLayout layout;
  final CertificateData data;
  const _Pdf({required this.layout, required this.data});

  @override
  Widget build(BuildContext context) {
    return PdfPreview(
      build: (_) => buildCertificatePdf(layout: layout, data: data),
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowPrinting: false,
      allowSharing: false,
      useActions: false,
      loadingWidget: const Center(child: CircularProgressIndicator()),
    );
  }
}

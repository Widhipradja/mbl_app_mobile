import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart'
    show MonthPill, EmptyState, RetryState;
import '../launcher/launcher_models.dart'
    show EventLevel, daysShort, monthsShort;
import 'event_data.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

/// Events of a month, grouped by date. Writers (`events/access`) also get
/// the add button; everyone else is read-only.
class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen>
    with WidgetsBindingObserver {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<MobileEvent> _events = const [];
  bool _loading = true;
  bool _canManage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _checkAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A role change upstream can lag a few minutes: check again on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final can = await eventRepo.canManage();
      if (mounted) setState(() => _canManage = can);
    } catch (e) {
      debugPrint('Events access error: $e');
      // Unknown: keep the controls hidden.
      if (mounted) setState(() => _canManage = false);
    }
  }

  Future<void> _load() async {
    final month = _month;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await eventRepo.month(month);
      if (!mounted || month != _month) return;
      setState(() => _events = list);
    } catch (e) {
      debugPrint('Events load error: $e');
      if (!mounted || month != _month) return;
      setState(() {
        _events = const [];
        _error = eventError(e);
      });
    } finally {
      if (mounted && month == _month) setState(() => _loading = false);
    }
  }

  void _setMonth(DateTime m) {
    setState(() => _month = DateTime(m.year, m.month));
    _load();
  }

  Future<void> _open(MobileEvent e) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => EventDetailScreen(event: e, canManage: _canManage)));
    if (!mounted) return;
    _load();
    _checkAccess();
  }

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const EventFormScreen()));
    if (!mounted) return;
    if (saved == true) {
      _load();
    } else if (saved == false) {
      // Refused as a writer: re-check, which hides the add button.
      _checkAccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<MobileEvent>>{};
    for (final e in _events) {
      groups.putIfAbsent(e.startDate, () => []).add(e);
    }

    return Scaffold(
      backgroundColor: Lx.background,
      appBar: AppBar(title: const Text('Kegiatan')),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s8),
            child: MonthPill(
              month: _month,
              onChanged: _setMonth,
              last: DateTime(DateTime.now().year + 2, 12),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_load(), _checkAccess()]);
              },
              child: _body(groups),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(Map<String, List<MobileEvent>> groups) {
    if (_loading && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [RetryState(_error!, onRetry: _load)],
      );
    }
    if (_events.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Lx.s24),
        children: [
          const SizedBox(height: 32),
          EmptyState(
            icon: Icons.event_available_rounded,
            text: 'Tidak ada kegiatan di bulan ini.',
            action: _canManage ? 'Tambah kegiatan' : null,
            onAction: _canManage ? _add : null,
          ),
        ],
      );
    }
    final today = eventDay(DateTime.now());
    final upcoming =
        _events.where((e) => (e.endDate.isEmpty ? e.startDate : e.endDate)
            .compareTo(today) >= 0).length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, 96),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Lx.s4, bottom: Lx.s4),
          child: Text(
              '${_events.length} kegiatan'
              '${upcoming > 0 ? ' · $upcoming akan datang' : ''}',
              style: Lx.metadata),
        ),
        for (final entry in groups.entries)
          for (final e in entry.value)
            _EventCard(
                event: e,
                today: e.startDate == today,
                past: (e.endDate.isEmpty ? e.startDate : e.endDate)
                        .compareTo(today) <
                    0,
                onTap: () => _open(e)),
      ],
    );
  }

}

/// "08:00 – 10:00", "Seluruh hari" or "12 Nov – 14 Nov".
String eventWhen(MobileEvent e) {
  if (e.isMultiDay) {
    final s = e.start!, t = e.end!;
    return '${s.day} ${monthsShort[s.month - 1]} – ${t.day} ${monthsShort[t.month - 1]}';
  }
  return e.hasTime ? '${e.startTime} – ${e.endTime}' : 'Seluruh hari';
}

/// Only the states worth noticing; `Scheduled` is the normal case.
({String label, Color fg, Color tint})? eventStatusChip(String status) {
  switch (status) {
    case 'Ongoing':
      return (
        label: 'Berlangsung',
        fg: const Color(0xFF15803D),
        tint: const Color(0xFFDCFCE7)
      );
    case 'Completed':
      return (
        label: 'Selesai',
        fg: const Color(0xFF475569),
        tint: const Color(0xFFF1F5F9)
      );
    case 'Cancelled':
      return (
        label: 'Dibatalkan',
        fg: const Color(0xFFB91C1C),
        tint: const Color(0xFFFEE2E2)
      );
  }
  return null;
}

class EventChip extends StatelessWidget {
  const EventChip(this.label, this.fg, this.tint, {super.key, this.icon});
  final String label;
  final Color fg, tint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: tint, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ]),
      );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onTap,
    this.today = false,
    this.past = false,
  });
  final MobileEvent event;
  final VoidCallback onTap;
  final bool today, past;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final level = e.level.isEmpty ? null : EventLevel.of(e.level);
    final status = eventStatusChip(e.status);
    final cancelled = e.status == 'Cancelled';
    final d = e.start;
    final accent = level?.color ?? Lx.primary;
    final tint = level?.tint ?? Lx.primaryLight;
    final fg = level?.fg ?? Lx.primary;

    return Opacity(
      opacity: past && !today ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.only(top: Lx.s8),
        child: Material(
          color: Lx.surface,
          borderRadius: BorderRadius.circular(Lx.rCard),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Lx.rCard),
                border: Border.all(
                    color: today ? accent : Lx.border, width: today ? 1.5 : 1),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Calendar block: weekday, day number, month.
                    Container(
                      width: 64,
                      color: tint,
                      padding: const EdgeInsets.symmetric(vertical: Lx.s12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(d == null ? '' : daysShort[d.weekday - 1],
                              style: Lx.metadata.copyWith(
                                  color: fg, fontWeight: FontWeight.w700)),
                          Text(d == null ? '–' : '${d.day}',
                              style: Lx.userName.copyWith(
                                  color: fg, fontSize: 24, height: 1.1)),
                          Text(d == null ? '' : monthsShort[d.month - 1],
                              style: Lx.metadata.copyWith(color: fg)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(Lx.s12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (e.isAnnouncement) ...[
                                  const Icon(Icons.campaign_outlined,
                                      size: 16, color: Lx.warning),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    e.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Lx.cardHeading.copyWith(
                                      fontSize: 14,
                                      decoration: cancelled
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                if (today)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text('Hari ini',
                                        style: Lx.metadata.copyWith(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _info(
                                e.isAnnouncement
                                    ? Icons.campaign_outlined
                                    : Icons.schedule_rounded,
                                e.isAnnouncement ? 'Pengumuman' : eventWhen(e)),
                            if (e.location.isNotEmpty)
                              _info(Icons.location_on_outlined, e.location),
                            if (level != null || status != null) ...[
                              const SizedBox(height: 6),
                              Wrap(spacing: 6, runSpacing: 4, children: [
                                if (level != null)
                                  EventChip(level.label, level.fg, level.tint,
                                      icon: level.icon),
                                if (status != null)
                                  EventChip(status.label, status.fg, status.tint),
                              ]),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Lx.textMuted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lx.metadata),
            ),
          ],
        ),
      );
}

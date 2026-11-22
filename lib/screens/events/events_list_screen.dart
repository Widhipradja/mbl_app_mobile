import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../finance/finance_widgets.dart';
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
          MonthSwitcher(
            month: _month,
            onChanged: _setMonth,
            last: DateTime(DateTime.now().year + 2, 12),
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
      return _message(_error!, retry: true);
    }
    if (_events.isEmpty) {
      return _message('Tidak ada kegiatan di bulan ini.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, 96),
      children: [
        for (final entry in groups.entries) ...[
          GroupLabel(_dayLabel(entry.key)),
          for (final e in entry.value) _EventCard(event: e, onTap: () => _open(e)),
        ],
      ],
    );
  }

  /// Scrollable so pull-to-refresh also works on an empty or failed month.
  Widget _message(String text, {bool retry = false}) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Lx.s32),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.event_busy_outlined, size: 40, color: Lx.textMuted),
          const SizedBox(height: Lx.s12),
          Text(text, textAlign: TextAlign.center, style: Lx.greeting),
          if (retry)
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
        ],
      );
}

String _dayLabel(String day) {
  final d = parseEventDay(day);
  if (d == null) return day;
  return '${daysShort[d.weekday - 1]}, ${d.day} ${monthsShort[d.month - 1]} ${d.year}';
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
  const _EventCard({required this.event, required this.onTap});
  final MobileEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final level = e.level.isEmpty ? null : EventLevel.of(e.level);
    final status = eventStatusChip(e.status);
    final cancelled = e.status == 'Cancelled';

    return Padding(
      padding: const EdgeInsets.only(top: Lx.s8),
      child: Material(
        color: Lx.surface,
        borderRadius: BorderRadius.circular(Lx.rCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(Lx.rCard),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(Lx.s12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lx.rCard),
              border: Border.all(color: Lx.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: level?.tint ?? Lx.primaryLight,
                    borderRadius: BorderRadius.circular(Lx.rButton),
                  ),
                  child: Icon(
                    e.isAnnouncement
                        ? Icons.campaign_outlined
                        : (level?.icon ?? Icons.event_outlined),
                    color: level?.fg ?? Lx.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: Lx.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Lx.cardHeading.copyWith(
                          decoration:
                              cancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.isAnnouncement ? 'Pengumuman' : eventWhen(e),
                        style: Lx.sectionSubtitle,
                      ),
                      if (e.location.isNotEmpty)
                        Text(e.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Lx.sectionSubtitle),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        if (level != null)
                          EventChip(level.label, level.fg, level.tint),
                        if (status != null)
                          EventChip(status.label, status.fg, status.tint),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

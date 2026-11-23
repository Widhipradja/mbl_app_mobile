import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../launcher/launcher_models.dart'
    show EventLevel, daysShort, monthsShort;
import 'event_data.dart';
import 'event_form_screen.dart';
import 'events_list_screen.dart' show EventChip, eventStatusChip, eventWhen;

/// All fields of one event. Writers get "Ubah" and "Hapus".
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen(
      {super.key, required this.event, required this.canManage});

  final MobileEvent event;
  final bool canManage;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late MobileEvent _event = widget.event;
  late bool _canManage = widget.canManage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// The list row can be stale (and may lack materials): read the event.
  Future<void> _refresh() async {
    try {
      final e = await eventRepo.get(_event.id);
      if (mounted) setState(() => _event = e);
    } catch (e) {
      debugPrint('Event detail error: $e');
      if (mounted && eventFailure(e) == EventFailure.notFound) {
        _snack(eventError(e));
        Navigator.of(context).pop();
      }
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => EventFormScreen(event: _event)));
    if (!mounted) return;
    if (saved == true) {
      // An edit can move the event to another month: back to the list.
      Navigator.of(context).pop();
    } else if (saved == false) {
      // Refused as a writer: hide the controls.
      setState(() => _canManage = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus kegiatan'),
        content: Text('Hapus "${_event.title}"? Tindakan ini tidak bisa '
            'dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Lx.danger),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await eventRepo.delete(_event.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Event delete error: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Not a writer after all: hide the controls.
        if (eventFailure(e) == EventFailure.notWriter) _canManage = false;
      });
      _snack(eventError(e));
      // Already gone: back to the list, which refreshes.
      if (eventFailure(e) == EventFailure.notFound) Navigator.of(context).pop();
    }
  }

  String _dateText() {
    String f(String s) {
      final d = parseEventDay(s);
      return d == null ? s : '${d.day} ${monthsShort[d.month - 1]} ${d.year}';
    }

    final e = _event;
    return e.isMultiDay ? '${f(e.startDate)} – ${f(e.endDate)}' : f(e.startDate);
  }

  @override
  Widget build(BuildContext context) {
    final e = _event;
    final level = e.level.isEmpty ? null : EventLevel.of(e.level);
    final status = eventStatusChip(e.status);

    return Scaffold(
      backgroundColor: Lx.background,
      appBar: AppBar(
        title: Text(e.isAnnouncement ? 'Pengumuman' : 'Kegiatan'),
        actions: [
          if (_canManage) ...[
            IconButton(
                tooltip: 'Ubah',
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit_outlined)),
            IconButton(
                tooltip: 'Hapus',
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline)),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s24),
        children: [
          _hero(e, level, status),
          const SizedBox(height: Lx.s12),
          _card([
            _row(Icons.calendar_today_outlined, _dateText()),
            if (!e.isAnnouncement) _row(Icons.schedule_outlined, eventWhen(e)),
            if (e.location.isNotEmpty)
              _row(Icons.location_on_outlined, e.location),
            _row(Icons.sell_outlined, 'Kategori ${e.category}'),
          ]),
          if (e.description.isNotEmpty)
            _card([
              Text('Keterangan', style: Lx.cardHeading),
              const SizedBox(height: Lx.s8),
              Text(e.description,
                  style: Lx.body.copyWith(color: Lx.text, height: 1.55)),
            ]),
          if (e.materials.isNotEmpty)
            _card([
              Row(
                children: [
                  Expanded(child: Text('Materi', style: Lx.cardHeading)),
                  Text('${e.materials.length} materi', style: Lx.metadata),
                ],
              ),
              const SizedBox(height: Lx.s4),
              for (var i = 0; i < e.materials.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Lx.s8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: Lx.primaryLight, shape: BoxShape.circle),
                        child: Text('${i + 1}',
                            style: Lx.metadata.copyWith(
                                color: Lx.primary,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: Lx.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.materials[i].title,
                                style: Lx.cardHeading.copyWith(fontSize: 14)),
                            if (e.materials[i].speaker.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded,
                                      size: 13, color: Lx.textMuted),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(e.materials[i].speaker,
                                        style: Lx.metadata),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: Lx.s12),
        padding: const EdgeInsets.all(Lx.s16),
        decoration: Lx.card(),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  /// Title on the level's colour, with the date block and the chips.
  Widget _hero(MobileEvent e, EventLevel? level,
      ({String label, Color fg, Color tint})? status) {
    final d = e.start;
    final tint = level?.tint ?? Lx.primaryLight;
    final fg = level?.fg ?? Lx.primary;
    return Container(
      padding: const EdgeInsets.all(Lx.s16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(Lx.rSection),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: Lx.s8),
            decoration: BoxDecoration(
              color: Lx.surface,
              borderRadius: BorderRadius.circular(Lx.rButton + 2),
            ),
            child: Column(
              children: [
                Text(d == null ? '' : daysShort[d.weekday - 1],
                    style: Lx.metadata
                        .copyWith(color: fg, fontWeight: FontWeight.w700)),
                Text(d == null ? '–' : '${d.day}',
                    style: Lx.userName
                        .copyWith(color: fg, fontSize: 24, height: 1.1)),
                Text(d == null ? '' : monthsShort[d.month - 1],
                    style: Lx.metadata.copyWith(color: fg)),
              ],
            ),
          ),
          const SizedBox(width: Lx.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e.isAnnouncement)
                  Row(
                    children: [
                      Icon(Icons.campaign_outlined, size: 16, color: fg),
                      const SizedBox(width: 4),
                      Text('Pengumuman',
                          style: Lx.metadata.copyWith(
                              color: fg, fontWeight: FontWeight.w700)),
                    ],
                  ),
                Text(e.title,
                    style: Lx.sectionHeading.copyWith(
                        decoration: e.status == 'Cancelled'
                            ? TextDecoration.lineThrough
                            : null)),
                const SizedBox(height: Lx.s8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (level != null)
                    EventChip(level.label, level.fg, Lx.surface,
                        icon: level.icon),
                  EventChip(e.category, Lx.primary, Lx.surface),
                  if (status != null)
                    EventChip(status.label, status.fg, status.tint),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Lx.textSecondary),
            const SizedBox(width: Lx.s8),
            Expanded(child: Text(text, style: Lx.greeting.copyWith(color: Lx.text))),
          ],
        ),
      );
}

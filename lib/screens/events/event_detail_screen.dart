import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../launcher/launcher_models.dart' show EventLevel, monthsShort;
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
        padding: const EdgeInsets.all(Lx.s16),
        children: [
          Text(e.title, style: Lx.sectionHeading),
          const SizedBox(height: Lx.s8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            EventChip(e.category, Lx.primary, Lx.primaryLight),
            if (level != null) EventChip(level.label, level.fg, level.tint),
            if (status != null)
              EventChip(status.label, status.fg, status.tint),
          ]),
          const SizedBox(height: Lx.s16),
          _row(Icons.calendar_today_outlined, _dateText()),
          if (!e.isAnnouncement)
            _row(Icons.schedule_outlined, eventWhen(e)),
          if (e.location.isNotEmpty)
            _row(Icons.location_on_outlined, e.location),
          if (e.description.isNotEmpty) ...[
            const SizedBox(height: Lx.s16),
            Text('Keterangan', style: Lx.cardHeading),
            const SizedBox(height: 4),
            Text(e.description, style: Lx.greeting.copyWith(height: 1.5)),
          ],
          if (e.materials.isNotEmpty) ...[
            const SizedBox(height: Lx.s16),
            Text('Materi', style: Lx.cardHeading),
            const SizedBox(height: 4),
            for (var i = 0; i < e.materials.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${i + 1}. ${e.materials[i].title}'
                  '${e.materials[i].speaker.isEmpty ? '' : ' — ${e.materials[i].speaker}'}',
                  style: Lx.greeting.copyWith(color: Lx.text, height: 1.4),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: Lx.s8),
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

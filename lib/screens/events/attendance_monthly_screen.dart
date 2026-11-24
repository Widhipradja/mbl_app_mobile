import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart' show MonthPill, EmptyState;
import '../launcher/launcher_models.dart' show monthsShort;
import 'attendance_data.dart';
import 'attendance_roster_screen.dart';
import 'event_data.dart';
import 'events_list_screen.dart' show EventChip;

/// The numbers line of one card. A completed event shows the full count;
/// any other shows `Absent: Not recorded yet` (an untouched roster would
/// read as everybody absent).
String monthlyNumbersLine(MonthlyAttendanceItem e) => e.isCompleted
    ? 'Present ${e.present}/${e.expected} (${e.rate.round()}%)'
    : 'Present ${e.present}/${e.expected}';

String monthlyDetailLine(MonthlyAttendanceItem e) => e.isCompleted
    ? 'Permission ${e.permission} · Absent ${e.absent}'
    : 'Absent: Not recorded yet';

/// Monthly report: one card per event that tracks attendance (not Cancelled).
class AttendanceMonthlyScreen extends StatefulWidget {
  const AttendanceMonthlyScreen({
    super.key,
    this.repo = attendanceRepo,
    this.initialMonth,
  });

  final AttendanceRepository repo;
  final DateTime? initialMonth;

  @override
  State<AttendanceMonthlyScreen> createState() =>
      _AttendanceMonthlyScreenState();
}

class _AttendanceMonthlyScreenState extends State<AttendanceMonthlyScreen> {
  late DateTime _month = () {
    final m = widget.initialMonth ?? DateTime.now();
    return DateTime(m.year, m.month);
  }();
  List<MonthlyAttendanceItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final month = _month;
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
    });
    try {
      final res = await widget.repo.monthly(month);
      if (!mounted || month != _month) return;
      setState(() => _items = res.events);
    } catch (e) {
      debugPrint('Attendance monthly error: $e');
      if (!mounted || month != _month) return;
      setState(() => _error = attendanceError(e));
    } finally {
      if (mounted && month == _month) setState(() => _loading = false);
    }
  }

  void _setMonth(DateTime m) {
    setState(() => _month = DateTime(m.year, m.month));
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Lx.background,
        appBar: AppBar(title: const Text('Attendance report')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s8),
            child: MonthPill(
              month: _month,
              onChanged: _setMonth,
              last: DateTime(DateTime.now().year + 2, 12),
            ),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _body()),
          ),
        ]),
      );

  Widget _body() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 64),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Lx.s24),
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.cloud_off_rounded, size: 36, color: Lx.textMuted),
          const SizedBox(height: Lx.s12),
          Text(_error!, textAlign: TextAlign.center, style: Lx.body),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Lx.s24),
        children: const [
          SizedBox(height: 32),
          EmptyState(
            icon: Icons.fact_check_outlined,
            text: 'No events with attendance this month.',
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s24),
      children: [for (final e in _items) _card(e)],
    );
  }

  Widget _card(MonthlyAttendanceItem e) {
    final d = parseEventDay(e.startDate);
    final date =
        d == null ? e.startDate : '${d.day} ${monthsShort[d.month - 1]} ${d.year}';
    final chip = attendanceStatusChip(e.status);
    return Padding(
      padding: const EdgeInsets.only(top: Lx.s8),
      child: Material(
        color: Lx.surface,
        borderRadius: BorderRadius.circular(Lx.rCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AttendanceRosterScreen(
                  eventId: e.eventId, repo: widget.repo))),
          child: Container(
            padding: const EdgeInsets.all(Lx.s16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lx.rCard),
              border: Border.all(color: Lx.border),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(e.title, style: Lx.cardHeading)),
                    EventChip(chip.label, chip.fg, chip.tint),
                  ]),
                  const SizedBox(height: 2),
                  Text(date, style: Lx.metadata),
                  const SizedBox(height: Lx.s12),
                  if (e.isCompleted) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (e.rate / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Lx.border,
                        color: Lx.success,
                      ),
                    ),
                    const SizedBox(height: Lx.s8),
                  ],
                  Text(monthlyNumbersLine(e),
                      style: Lx.body.copyWith(color: Lx.text)),
                  Text(monthlyDetailLine(e), style: Lx.metadata),
                ]),
          ),
        ),
      ),
    );
  }
}

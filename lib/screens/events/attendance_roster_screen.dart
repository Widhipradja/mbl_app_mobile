import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/launcher_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/configuration_provider.dart';
import '../../providers/home_summary_provider.dart';
import '../../providers/zakat_provider.dart';
import '../launcher/launcher_models.dart' show monthsShort;
import 'attendance_data.dart';
import 'event_data.dart';
import 'events_list_screen.dart' show EventChip, eventStatusChip;

/// `Present 40 of 63 · Permission 5 · Absent 18`. Every number is the
/// server's tally; `Absent` is a number only for a completed event.
String attendanceSummaryLine(AttendanceRoster r) {
  final t = r.tally;
  if (t == null) return 'No roster yet';
  final absent = r.isCompleted ? '${t.absent}' : 'Not recorded yet';
  return 'Present ${t.present} of ${t.expected} · Permission ${t.permission}'
      ' · Absent${r.isCompleted ? ' ' : ': '}$absent';
}

({String label, Color fg, Color tint}) attendanceStatusChip(String status) {
  final c = eventStatusChip(status);
  final fg = c?.fg ?? Lx.primary;
  final tint = c?.tint ?? Lx.primaryLight;
  return (label: status, fg: fg, tint: tint);
}

/// Roster of one event: mark who came, add notes, fill or clear the list.
///
/// Writes go straight to the server. A row flips at once and flips back if
/// the server refuses; after every successful write the roster is read again,
/// because the numbers (tally) are the server's, never worked out here.
class AttendanceRosterScreen extends StatefulWidget {
  const AttendanceRosterScreen({
    super.key,
    required this.eventId,
    this.repo = attendanceRepo,
    this.onSignInAgain,
  });

  final String eventId;

  final AttendanceRepository repo;

  /// Replaces the default sign-out + login (tests).
  final Future<void> Function()? onSignInAgain;

  @override
  State<AttendanceRosterScreen> createState() => _AttendanceRosterScreenState();
}

class _AttendanceRosterScreenState extends State<AttendanceRosterScreen> {
  AttendanceRoster? _roster;
  bool _loading = true;
  bool _unauthorized = false;
  String? _error;
  String _query = '';
  _Sex _tab = _Sex.men;
  bool _reloading = false, _reloadQueued = false;
  bool _bulkBusy = false;
  int _inflight = 0;
  final _pending = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _locked {
    final r = _roster;
    return r == null || r.isCompleted || !r.trackAttendance;
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Leaves for the detail screen and says why.
  void _leave(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(text)));
    Navigator.of(context).pop();
  }

  Future<void> _load({bool silent = false, bool afterWrite = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await widget.repo.roster(widget.eventId);
      if (!mounted) return;
      // Rows still being written, or another reload already asked for: this
      // answer is out of date, and the next one replaces it.
      if (afterWrite && (_pending.isNotEmpty || _reloadQueued)) return;
      setState(() {
        _roster = r;
        _error = null;
        _unauthorized = false;
      });
    } catch (e) {
      debugPrint('Attendance load error: $e');
      if (!mounted) return;
      if (silent) {
        _snack(afterWrite
            ? 'Saved, but the numbers could not be refreshed. Pull down to '
                'refresh.'
            : attendanceError(e));
      } else {
        _fail(e, initial: true);
      }
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  /// Reload after a write. One reload runs at a time; asks that arrive while
  /// it runs share the next one. While other rows are still being written the
  /// last of them does the reload.
  Future<void> _reloadAfterWrite() async {
    if (_inflight > 0) return;
    if (_reloading) {
      _reloadQueued = true;
      return;
    }
    _reloading = true;
    try {
      do {
        _reloadQueued = false;
        await _load(silent: true, afterWrite: true);
      } while (_reloadQueued && mounted);
    } finally {
      _reloading = false;
      _reloadQueued = false;
    }
  }

  /// What each refusal means for the screen.
  void _fail(Object e, {bool initial = false}) {
    final text = attendanceError(e);
    switch (attendanceFailure(e)) {
      case AttendanceFailure.notWriter:
      case AttendanceFailure.moduleOff:
      case AttendanceFailure.eventNotFound:
        _leave(text);
      case AttendanceFailure.notProvisioned:
        // The session is fine: no sign-out, the user chooses.
        setState(() => _unauthorized = true);
      case AttendanceFailure.locked:
      case AttendanceFailure.notRostered:
      case AttendanceFailure.notTracked:
        _snack(text);
        _load(silent: true);
      default:
        if (initial && _roster == null) {
          setState(() => _error = text);
        } else {
          _snack(text);
        }
    }
  }

  void _replace(AttendanceRow row) {
    final r = _roster;
    if (r == null) return;
    setState(() => _roster =
        r.withRows([for (final x in r.rows) x.memberId == row.memberId ? row : x]));
  }

  /// One member: show the change now, undo it if the server says no.
  Future<void> _write(
    AttendanceRow row, {
    bool? isAttending,
    String? presenceMode,
    String? remark,
  }) async {
    if (_locked || _bulkBusy || _pending.contains(row.memberId)) return;
    _pending.add(row.memberId);
    _inflight++;
    _replace(row.copyWith(
        isAttending: isAttending, presenceMode: presenceMode, remark: remark));
    var ok = false;
    try {
      await widget.repo.setOne(widget.eventId, row.memberId,
          isAttending: isAttending, presenceMode: presenceMode, remark: remark);
      ok = true;
    } catch (e) {
      debugPrint('Attendance write error: $e');
      if (mounted) {
        _replace(row);
        _fail(e);
      }
    } finally {
      _pending.remove(row.memberId);
      _inflight--;
    }
    // Wait for the last write in flight, so a reload never undoes another row.
    if (ok && mounted) await _reloadAfterWrite();
  }

  Future<void> _bulk(bool attending) async {
    final r = _roster;
    if (r == null || _locked || _bulkBusy || r.rows.isEmpty) return;
    if (!attending) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Clear all'),
          content: const Text('Mark everyone as not present? Notes are kept.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear all')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _bulkBusy = true);
    try {
      // One request for the whole roster, never one per member.
      await widget.repo
          .setMany(widget.eventId, [for (final x in r.rows) x.memberId], attending);
      if (mounted) await _reloadAfterWrite();
    } catch (e) {
      debugPrint('Attendance bulk error: $e');
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _generate() async {
    if (_locked || _bulkBusy) return;
    setState(() => _bulkBusy = true);
    try {
      final res = await widget.repo.sync(widget.eventId);
      _snack(res.unchanged
          ? 'Attendance list already up to date'
          : 'Attendance list updated: ${res.added} added, ${res.removed} removed');
      if (mounted) await _load(silent: true);
    } catch (e) {
      debugPrint('Attendance sync error: $e');
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _editNote(AttendanceRow row) async {
    final locked = _locked;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(name: row.name, initial: row.remark, readOnly: locked),
    );
    if (text == null || locked || !mounted) return;
    if (text == row.remark) return;
    await _write(row, remark: text);
  }

  void _summary() {
    final r = _roster;
    final t = r?.tally;
    if (r == null || t == null) return;
    final pct = r.isCompleted && t.expected > 0
        ? ' (${(t.present * 100 / t.expected).round()}%)'
        : '';
    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(k, style: Lx.body)),
            Text(v, style: Lx.cardHeading),
          ]),
        );
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Summary'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          line('Expected', '${t.expected}'),
          line('Present', '${t.present}$pct'),
          line('Permission', '${t.permission}'),
          line('Absent', r.isCompleted ? '${t.absent}' : 'Not recorded yet'),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _signInAgain() async {
    final custom = widget.onSignInAgain;
    if (custom != null) return custom();
    final auth = context.read<AuthProvider>();
    final zakat = context.read<ZakatProvider>();
    final config = context.read<ConfigurationProvider>();
    final home = context.read<HomeSummaryProvider>();
    await auth.logout();
    zakat.reset();
    config.reset();
    home.reset();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final r = _roster;
    final canWrite = !_locked && !_bulkBusy;
    return Scaffold(
      backgroundColor: Lx.background,
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            tooltip: 'Generate attendance list',
            onPressed: canWrite ? _generate : null,
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          IconButton(
            tooltip: 'Summary',
            onPressed: r?.tally == null ? null : _summary,
            icon: const Icon(Icons.pie_chart_outline_rounded),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_unauthorized) {
      return _Message(
        icon: Icons.lock_outline_rounded,
        text: attendanceNotRecognized,
        action: 'Sign in again',
        onAction: _signInAgain,
      );
    }
    final r = _roster;
    if (_loading && r == null) return const _Skeleton();
    if (r == null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        text: _error ?? 'Something went wrong. Please try again.',
        action: 'Retry',
        onAction: _load,
      );
    }
    final rows = r.rows;
    final empty = rows.isEmpty || r.tally == null;
    final men = rows.where((e) => e.sex == 'M').toList();
    final women = rows.where((e) => e.sex == 'F').toList();
    final other = rows.where((e) => e.sex != 'M' && e.sex != 'F').toList();
    // The Unspecified tab exists only while someone is in it.
    final tab = _tab == _Sex.other && other.isEmpty ? _Sex.men : _tab;
    final shown = (tab == _Sex.men
            ? men
            : tab == _Sex.women
                ? women
                : other)
        .where((e) =>
            _query.isEmpty || e.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    int here(List<AttendanceRow> l) => l.where((e) => e.isAttending).length;
    final tooMany = rows.length > attendanceBulkMax;

    return Column(
      children: [
        if (r.isCompleted)
          Container(
            width: double.infinity,
            color: const Color(0xFFFEF3C7),
            padding: const EdgeInsets.all(Lx.s12),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 18, color: Color(0xFF92400E)),
              const SizedBox(width: Lx.s8),
              Expanded(
                child: Text(
                    'This event is completed, so its attendance is locked. '
                    'Reopen it in the web app to change it.',
                    style: Lx.metadata.copyWith(color: const Color(0xFF92400E))),
              ),
            ]),
          ),
        _header(r),
        if (!r.trackAttendance)
          const Expanded(
            child: _Message(
                icon: Icons.event_busy_outlined,
                text: 'This event does not track attendance.'),
          )
        else if (empty)
          Expanded(
            child: _Message(
              icon: Icons.groups_outlined,
              text: 'Nobody is on this roster yet.',
              action: r.isCompleted ? null : 'Generate attendance list',
              onAction: _bulkBusy ? null : _generate,
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s8),
            child: Row(children: [
              for (final (t, label, list) in [
                (_Sex.men, 'Men', men),
                (_Sex.women, 'Women', women),
                if (other.isNotEmpty) (_Sex.other, 'Unspecified', other),
              ]) ...[
                if (t != _Sex.men) const SizedBox(width: Lx.s8),
                Expanded(
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: SizedBox(
                        width: double.infinity,
                        child: Text('$label (${here(list)}/${list.length})',
                            textAlign: TextAlign.center)),
                    selected: tab == t,
                    onSelected: (_) => setState(() => _tab = t),
                  ),
                ),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s8),
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search name',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(silent: true),
              child: shown.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(Lx.s24),
                          child: Center(child: Text('No one matches.')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _rowTile(shown[i]),
                    ),
            ),
          ),
          if (!_locked)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Lx.s12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (tooMany)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Lx.s8),
                      child: Text(
                          'Too many members for one request (max $attendanceBulkMax).',
                          style: Lx.metadata),
                    ),
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _bulkBusy || tooMany ? null : () => _bulk(true),
                        child: const Text('Mark all present'),
                      ),
                    ),
                    const SizedBox(width: Lx.s12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _bulkBusy || tooMany ? null : () => _bulk(false),
                        child: const Text('Clear all'),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
        ],
      ],
    );
  }

  Widget _header(AttendanceRoster r) {
    final e = r.event;
    final d = parseEventDay(e.startDate);
    final date = d == null
        ? e.startDate
        : '${d.day} ${monthsShort[d.month - 1]} ${d.year}';
    final chip = attendanceStatusChip(e.status);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(Lx.s16),
      padding: const EdgeInsets.all(Lx.s16),
      decoration: Lx.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(e.title, style: Lx.cardHeading)),
          EventChip(chip.label, chip.fg, chip.tint),
        ]),
        const SizedBox(height: 2),
        Text(date, style: Lx.metadata),
        const SizedBox(height: Lx.s8),
        Text(attendanceSummaryLine(r), style: Lx.body.copyWith(color: Lx.text)),
      ]),
    );
  }

  Widget _rowTile(AttendanceRow row) {
    final locked = _locked;
    final busy = _pending.contains(row.memberId);
    final hasNote = row.remark.isNotEmpty;
    return InkWell(
      onTap: locked || busy
          ? null
          : () => _write(row, isAttending: !row.isAttending),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Lx.s16, vertical: 6),
        child: Row(children: [
          Icon(
            row.isAttending
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: row.isAttending ? Lx.success : Lx.textMuted,
          ),
          const SizedBox(width: Lx.s12),
          Expanded(child: Text(row.name, style: Lx.body.copyWith(color: Lx.text))),
          if (!locked || hasNote)
            IconButton(
              tooltip: 'Note',
              visualDensity: VisualDensity.compact,
              onPressed: busy ? null : () => _editNote(row),
              icon: Icon(
                hasNote ? Icons.sticky_note_2_rounded : Icons.edit_note_rounded,
                color: hasNote ? Lx.warning : Lx.textMuted,
              ),
            ),
          if (row.isAttending) ...[
            Text('Online', style: Lx.metadata),
            Switch(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: row.isOnline,
              onChanged: locked || busy
                  ? null
                  : (v) => _write(row, presenceMode: v ? 'online' : 'offline'),
            ),
          ],
        ]),
      ),
    );
  }
}

enum _Sex { men, women, other }

class _NoteDialog extends StatefulWidget {
  const _NoteDialog(
      {required this.name, required this.initial, required this.readOnly});
  final String name, initial;
  final bool readOnly;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.name),
        content: TextField(
          controller: _c,
          readOnly: widget.readOnly,
          maxLength: attendanceRemarkMax,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. sick, out of town',
            helperText: 'An absent member with a note counts as permission.',
            helperMaxLines: 2,
          ),
        ),
        actions: widget.readOnly
            ? [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
              ]
            : [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, _c.text.trim()),
                    child: const Text('Save')),
              ],
      );
}

class _Message extends StatelessWidget {
  const _Message(
      {required this.icon, required this.text, this.action, this.onAction});
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Lx.s24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 36, color: Lx.textMuted),
            const SizedBox(height: Lx.s12),
            Text(text, textAlign: TextAlign.center, style: Lx.body),
            if (action != null) ...[
              const SizedBox(height: Lx.s12),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ]),
        ),
      );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Lx.s16),
        child: Column(children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 52,
              margin: const EdgeInsets.only(bottom: Lx.s12),
              decoration: BoxDecoration(
                color: Lx.border,
                borderRadius: BorderRadius.circular(Lx.rButton),
              ),
            ),
        ]),
      );
}

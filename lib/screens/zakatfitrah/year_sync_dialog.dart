import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/zakat_year.dart';
import '../../providers/auth_provider.dart';
import '../../services/zakat_year_sync_service.dart';

/// Lets the user copy master data from an earlier Zakat year into [target],
/// so a new year only needs small revisions. Pops `true` if anything ran.
class YearSyncDialog extends StatefulWidget {
  const YearSyncDialog({
    super.key,
    required this.target,
    required this.years,
    required this.primaryColor,
  });

  final ZakatYear target;
  final List<ZakatYear> years;
  final Color primaryColor;

  @override
  State<YearSyncDialog> createState() => _YearSyncDialogState();
}

class _YearSyncDialogState extends State<YearSyncDialog> {
  final _service = ZakatYearSyncService();
  late final List<ZakatYear> _sources;
  ZakatYear? _source;
  final Set<YearSyncItem> _selected = {...YearSyncItem.values};

  bool _running = false;
  bool _done = false;
  YearSyncItem? _current;
  final Map<YearSyncItem, String> _results = {};
  final Map<YearSyncItem, bool> _errors = {};

  @override
  void initState() {
    super.initState();
    _sources = widget.years.where((y) => y.id != widget.target.id).toList()
      ..sort((a, b) => b.hijriYear.compareTo(a.hijriYear));
    // Default to the closest earlier year.
    _source = _sources.firstWhere(
      (y) => y.hijriYear < widget.target.hijriYear,
      orElse: () => _sources.isNotEmpty ? _sources.first : widget.target,
    );
    if (_sources.isEmpty) _source = null;
  }

  Future<void> _run() async {
    final source = _source;
    if (source == null || _selected.isEmpty) return;

    final user = context.read<AuthProvider>().user;
    final by = user?.userId ?? user?.id ?? '';

    setState(() {
      _running = true;
      _results.clear();
      _errors.clear();
    });

    // Muzakki last: it is the slowest and the others are what users check first.
    final order = YearSyncItem.values.where(_selected.contains).toList()
      ..sort((a, b) {
        int rank(YearSyncItem i) => i == YearSyncItem.muzakki ? 1 : 0;
        return rank(a).compareTo(rank(b));
      });

    for (final item in order) {
      if (!mounted) return;
      setState(() => _current = item);
      try {
        final r = await _service.run(
          item,
          source: source,
          target: widget.target,
          createdBy: by,
        );
        _results[item] = r.summary;
        _errors[item] = r.failed > 0;
      } catch (_) {
        _results[item] = 'Gagal disalin';
        _errors[item] = true;
      }
    }

    if (!mounted) return;
    setState(() {
      _running = false;
      _done = true;
      _current = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showResults = _running || _done;

    return PopScope(
      canPop: !_running,
      child: AlertDialog(
        title: const Text('Salin dari Tahun Sebelumnya'),
        content: SizedBox(
          width: double.maxFinite,
          child: _sources.isEmpty
              ? const Text('Belum ada tahun lain yang bisa dijadikan sumber.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Salin ke: ${widget.target.label}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<ZakatYear>(
                        value: _source,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Salin dari tahun',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final y in _sources)
                            DropdownMenuItem(value: y, child: Text(y.label)),
                        ],
                        onChanged: _running
                            ? null
                            : (v) => setState(() {
                                  _source = v;
                                  _results.clear();
                                  _done = false;
                                }),
                      ),
                      const SizedBox(height: 8),
                      for (final item in YearSyncItem.values)
                        _row(item, showResults),
                      const SizedBox(height: 8),
                      Text(
                        'Data yang sudah ada di tahun ini tidak ditimpa atau '
                        'dihapus; hanya yang belum ada yang ditambahkan.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: _running
                ? null
                : () => Navigator.pop(context, _results.isNotEmpty),
            child: Text(_done ? 'Tutup' : 'Batal'),
          ),
          if (!_done && _sources.isNotEmpty)
            ElevatedButton(
              onPressed: _running || _selected.isEmpty || _source == null
                  ? null
                  : _run,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salin'),
            ),
        ],
      ),
    );
  }

  Widget _row(YearSyncItem item, bool showResults) {
    final result = _results[item];
    final isError = _errors[item] ?? false;
    final selected = _selected.contains(item);

    Widget? trailing;
    if (showResults && selected) {
      if (_current == item) {
        trailing = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      } else if (result != null) {
        trailing = Icon(
          isError ? Icons.error_outline : Icons.check_circle,
          size: 18,
          color: isError ? const Color(0xFFD97706) : widget.primaryColor,
        );
      }
    }

    return CheckboxListTile(
      value: selected,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: widget.primaryColor,
      onChanged: _running
          ? null
          : (v) => setState(() {
                v == true ? _selected.add(item) : _selected.remove(item);
              }),
      title: Row(
        children: [
          Expanded(
            child: Text(item.label, style: const TextStyle(fontSize: 13)),
          ),
          if (trailing != null) trailing,
        ],
      ),
      subtitle: Text(
        result ?? item.hint,
        style: TextStyle(
          fontSize: 11,
          color: result == null
              ? Colors.grey.shade600
              : (isError ? const Color(0xFFD97706) : widget.primaryColor),
        ),
      ),
    );
  }
}

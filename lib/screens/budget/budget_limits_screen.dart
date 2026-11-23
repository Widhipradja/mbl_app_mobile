import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart';
import '../finance/finance_data.dart' show RupiahInputFormatter, rp, thousands;
import '../savings/ledger_widgets.dart' show monthNames;
import 'budget_data.dart';
import 'budget_widgets.dart';

/// Monthly budget per expense category. A row left empty or 0 means no
/// budget. Only the rows that changed are sent.
class BudgetLimitsScreen extends StatefulWidget {
  const BudgetLimitsScreen({super.key, required this.month});

  final DateTime month;

  @override
  State<BudgetLimitsScreen> createState() => _BudgetLimitsScreenState();
}

class _BudgetLimitsScreenState extends State<BudgetLimitsScreen> {
  late DateTime _month = DateTime(widget.month.year, widget.month.month);
  List<BudgetCategory>? _categories;
  final Map<String, TextEditingController> _fields = {};
  Map<String, int> _saved = {};

  /// Budgets of the period before this one, by category id; empty when it
  /// had none or could not be read.
  Map<String, int> _previous = const {};

  /// Spent this month per category, to set a limit against; empty when the
  /// summary could not be read.
  Map<String, int> _spent = const {};
  final _total = ValueNotifier<int>(0);
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _total.dispose();
    super.dispose();
  }

  int _value(String id) =>
      int.tryParse(_fields[id]?.text.replaceAll(RegExp(r'\D'), '') ?? '') ?? 0;

  void _recompute() =>
      _total.value = _fields.keys.fold(0, (s, id) => s + _value(id));

  Future<void> _load() async {
    final month = _month;
    setState(() {
      _error = null;
      _categories = null;
    });
    try {
      final r = await Future.wait<dynamic>([
        budgetRepo.categories(),
        budgetRepo.limits(month),
        budgetRepo
            .summary(month)
            .then<BudgetSummary?>((s) => s)
            .catchError((Object e) => null),
        // Only offered as a shortcut: a failure just hides it.
        budgetRepo
            .limits(DateTime(month.year, month.month - 1))
            .catchError((Object e) => <String, int>{}),
      ]);
      if (!mounted || month != _month) return;
      final cats = (r[0] as List<BudgetCategory>)
          .where((c) => !c.isIncome && c.active)
          .toList();
      final limits = r[1] as Map<String, int>;
      for (final c in _fields.values) {
        c.dispose();
      }
      _fields
        ..clear()
        ..addEntries([
          for (final c in cats)
            MapEntry(
                c.id,
                TextEditingController(
                    text: (limits[c.id] ?? 0) > 0
                        ? thousands(limits[c.id]!)
                        : '')),
        ]);
      _saved = {for (final c in cats) c.id: limits[c.id] ?? 0};
      _previous = r[3] as Map<String, int>;
      final summary = r[2] as BudgetSummary?;
      _spent = {
        for (final l in summary?.categories ?? const <BudgetCategoryLine>[])
          l.categoryId: l.spent,
      };
      setState(() => _categories = cats);
      _recompute();
    } catch (e) {
      debugPrint('BudgetLimits load error: $e');
      if (mounted && month == _month) setState(() => _error = budgetError(e));
    }
  }

  void _setMonth(DateTime m) {
    setState(() => _month = DateTime(m.year, m.month));
    _load();
  }

  Map<String, int> get _copyable => limitsToCopy(
        previous: _previous,
        current: {for (final id in _fields.keys) id: _value(id)},
      );

  DateTime get _previousMonth => DateTime(_month.year, _month.month - 1);

  /// Fills the empty rows from the period before. Nothing is saved until
  /// Simpan, and rows already filled are left alone.
  void _copyPrevious() {
    final copy = _copyable;
    if (copy.isEmpty) return;
    for (final e in copy.entries) {
      _fields[e.key]?.text = thousands(e.value);
    }
    _recompute();
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text('${copy.length} anggaran disalin. '
              'Tekan Simpan untuk menyimpannya.')));
  }

  /// "Salin dari Oktober 2026": shown while the earlier period has budgets
  /// this one lacks.
  Widget _copyCard(Map<String, int> copy) {
    final p = _previousMonth;
    final total = copy.values.fold<int>(0, (a, b) => a + b);
    return Container(
      margin: const EdgeInsets.only(bottom: Lx.s12),
      padding: const EdgeInsets.all(Lx.s12),
      decoration: BoxDecoration(
        color: Lx.primaryLight,
        borderRadius: BorderRadius.circular(Lx.rCard),
      ),
      child: Row(
        children: [
          const Icon(Icons.copy_all_rounded, color: Lx.primary),
          const SizedBox(width: Lx.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${monthNames[p.month - 1]} ${p.year}',
                    style: Lx.cardHeading.copyWith(fontSize: 14)),
                Text('${copy.length} anggaran, total ${rp(total)}',
                    style: Lx.metadata.copyWith(fontFeatures: tabular)),
              ],
            ),
          ),
          const SizedBox(width: Lx.s8),
          FilledButton.tonal(
            onPressed: _saving ? null : _copyPrevious,
            child: const Text('Salin'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final changed = [
      for (final id in _fields.keys)
        if (_value(id) != _saved[id]) id,
    ];
    if (changed.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final failed = <String>[];
    for (final id in changed) {
      try {
        await budgetRepo.setLimit(id, _value(id), _month);
        _saved[id] = _value(id);
      } catch (e) {
        debugPrint('BudgetLimits save error: $e');
        failed.add(id);
        if (failed.length == 1) _error = budgetError(e);
      }
    }
    if (!mounted) return;
    if (failed.isEmpty) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = '${failed.length} anggaran belum tersimpan. $_error';
      });
    }
  }

  Widget _row(BudgetCategory c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Lx.s8),
        child: Row(
          children: [
            CategoryAvatar(c.name, income: false, size: 36),
            const SizedBox(width: Lx.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Lx.cardHeading.copyWith(fontSize: 14)),
                  Text(
                      (_spent[c.id] ?? 0) > 0
                          ? 'Terpakai ${rp(_spent[c.id]!)}'
                          : 'Belum ada pengeluaran',
                      style: Lx.metadata.copyWith(fontFeatures: tabular)),
                ],
              ),
            ),
            const SizedBox(width: Lx.s12),
            SizedBox(
              width: 140,
              height: 48,
              child: TextField(
                controller: _fields[c.id],
                enabled: !_saving,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.end,
                scrollPadding: const EdgeInsets.only(bottom: 120),
                inputFormatters: [RupiahInputFormatter()],
                onChanged: (_) => _recompute(),
                style: Lx.cardHeading.copyWith(fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: '0',
                  prefixText: 'Rp ',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: Lx.s12, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cats = _categories;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Atur Anggaran')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s8),
              child: BudgetMonthPill(
                month: _month,
                onChanged: _saving ? (_) {} : _setMonth,
                extraMonths: 1,
              ),
            ),
            Expanded(
              child: cats == null
                  ? (_error != null
                      ? Center(child: RetryState(_error!, onRetry: _load))
                      : const Center(child: CircularProgressIndicator()))
                  : cats.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(Lx.s24),
                            child: EmptyState(
                              icon: Icons.category_rounded,
                              text: 'Belum ada kategori pengeluaran. '
                                  'Tambahkan dulu di menu Kategori.',
                            ),
                          ),
                        )
                      : ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.symmetric(
                              horizontal: Lx.s16, vertical: Lx.s8),
                          children: [
                            Text(
                                'Isi batas belanja per kategori untuk bulan '
                                'ini. Kosongkan atau isi 0 bila tidak '
                                'dianggarkan.',
                                style: Lx.body),
                            const SizedBox(height: Lx.s12),
                            if (_copyable.isNotEmpty) _copyCard(_copyable),
                            SectionCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Lx.s12, vertical: Lx.s4),
                              child: Column(
                                children: [
                                  for (var i = 0; i < cats.length; i++) ...[
                                    if (i > 0)
                                      const Divider(
                                          height: 1,
                                          indent: 48,
                                          color: Lx.border),
                                    _row(cats[i]),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
        bottomNavigationBar: cats == null || cats.isEmpty
            ? null
            : Material(
                color: Lx.surface,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Lx.border))),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(Lx.s16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Lx.s8),
                              child: Text(_error!,
                                  style:
                                      Lx.metadata.copyWith(color: Lx.danger)),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: ValueListenableBuilder<int>(
                                  valueListenable: _total,
                                  builder: (_, v, __) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Total anggaran',
                                          style: Lx.metadata),
                                      Text(rp(v),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Lx.sectionHeading.copyWith(
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: Lx.s16),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed: _saving ? null : _save,
                                  style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: Lx.s24)),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Text('Simpan'),
                                ),
                              ),
                            ],
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
}

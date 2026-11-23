import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart';
import '../finance/finance_data.dart' show rp, rpShort;
import '../savings/ledger_widgets.dart' show monthNames;
import 'budget_data.dart';
import 'budget_transactions_screen.dart';
import 'budget_widgets.dart';

/// Where the money went in a month: spending (or income) per category with
/// its share and the change from last month, the daily average, the biggest
/// expenses, and a six-month trend. Tap a category to see its transactions.
class BudgetReportScreen extends StatefulWidget {
  const BudgetReportScreen({super.key, required this.month});

  final DateTime month;

  @override
  State<BudgetReportScreen> createState() => _BudgetReportScreenState();
}

class _BudgetReportScreenState extends State<BudgetReportScreen> {
  static const _trendMonths = 6;

  late DateTime _month = DateTime(widget.month.year, widget.month.month);
  bool _income = false;

  /// Summaries of the [_trendMonths] months ending at [_month], oldest
  /// first; null where one could not be read.
  List<BudgetSummary?>? _trend;
  List<BudgetTxn> _txns = const [];
  Map<String, bool> _incomeOf = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final month = _month;
    setState(() => _error = null);
    final months = [
      for (var i = _trendMonths - 1; i >= 0; i--)
        DateTime(month.year, month.month - i),
    ];
    try {
      final r = await Future.wait<dynamic>([
        // The trend tolerates a missing month; the selected one does not.
        for (final m in months)
          m == month
              ? budgetRepo.summary(m)
              : budgetRepo
                  .summary(m)
                  .then<BudgetSummary?>((s) => s)
                  .catchError((Object e) => null),
        budgetRepo.transactions(month),
        budgetRepo.categories(),
      ]);
      if (!mounted || month != _month) return;
      setState(() {
        _trend = [
          for (var i = 0; i < _trendMonths; i++) r[i] as BudgetSummary?
        ];
        _txns = r[_trendMonths] as List<BudgetTxn>;
        _incomeOf = {
          for (final c in r[_trendMonths + 1] as List<BudgetCategory>)
            c.id: c.isIncome
        };
      });
    } catch (e) {
      debugPrint('BudgetReport load error: $e');
      if (mounted && month == _month) setState(() => _error = budgetError(e));
    }
  }

  void _setMonth(DateTime m) {
    setState(() {
      _month = DateTime(m.year, m.month);
      _trend = null;
    });
    _load();
  }

  BudgetSummary get _current => _trend![_trendMonths - 1]!;
  BudgetSummary? get _previous => _trend![_trendMonths - 2];

  /// The categories of the chosen type with something in them, largest
  /// first, plus what is left over when some entries have no category.
  List<_Row> _rows() {
    final s = _current;
    final prev = _previous;
    final list = s.categories
        .where((c) => c.isIncome == _income && c.spent > 0)
        .toList()
      ..sort((a, b) => b.spent.compareTo(a.spent));
    final rows = [
      for (final c in list)
        _Row(
          id: c.categoryId,
          name: c.name,
          amount: c.spent,
          before: prev?.categories
              .where((p) => p.categoryId == c.categoryId)
              .fold<int?>(null, (_, p) => p.spent),
        ),
    ];
    final total = _income ? s.income : s.expense;
    final rest = total - rows.fold<int>(0, (a, r) => a + r.amount);
    if (rest > 0)
      rows.add(_Row(id: null, name: 'Tanpa kategori', amount: rest));
    return rows;
  }

  Color _rowColor(_Row r) => r.id == null
      ? const Color(0xFFCBD5E1)
      : categoryLook(r.name, income: _income).color;

  Widget _summary() {
    final s = _current;
    final total = _income ? s.income : s.expense;
    final prevTotal = _previous == null
        ? null
        : (_income ? _previous!.income : _previous!.expense);
    // Days of the period so far (all of them for a past one): what the
    // daily average is divided by.
    final days = budgetRepo.rangeOf(_month).daysCountedAt(DateTime.now());
    final rows = _rows();

    return SectionCard(
      child: Column(
        children: [
          if (rows.isEmpty)
            EmptyState(
              icon: Icons.pie_chart_outline_rounded,
              text: _income
                  ? 'Belum ada pemasukan bulan ini.'
                  : 'Belum ada pengeluaran bulan ini.',
            )
          else
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: 2,
                      centerSpaceRadius: 68,
                      sections: [
                        for (final r in rows)
                          PieChartSectionData(
                            value: r.amount.toDouble(),
                            color: _rowColor(r),
                            radius: 26,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_income ? 'Total masuk' : 'Total keluar',
                          style: Lx.metadata),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 120,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(rp(total),
                              style: Lx.sectionHeading.copyWith(
                                  color: _income ? Lx.success : Lx.text,
                                  fontFeatures: tabular)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: Lx.s12),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'Dibanding bulan lalu',
                  prevTotal != null && prevTotal > 0
                      ? _Delta(now: total, before: prevTotal, upIsBad: !_income)
                      : Text('–', style: Lx.cardHeading),
                ),
              ),
              Container(width: 1, height: 36, color: Lx.border),
              const SizedBox(width: Lx.s12),
              Expanded(
                child: _stat(
                  _income ? 'Jumlah transaksi' : 'Rata-rata per hari',
                  Text(
                      _income
                          ? '${_txns.where((t) => (_incomeOf[t.categoryId] ?? t.typeIncome) == true).length}'
                          : rp(days > 0 ? (total / days).round() : 0),
                      style: Lx.cardHeading.copyWith(fontFeatures: tabular)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, Widget value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Lx.metadata),
          const SizedBox(height: 2),
          value,
        ],
      );

  Widget _categories() {
    final rows = _rows();
    if (rows.isEmpty) return const SizedBox.shrink();
    final total = _income ? _current.income : _current.expense;
    return SectionCard(
      title: 'Per kategori',
      subtitle: 'Ketuk kategori untuk melihat transaksinya',
      padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
      child: Column(
        children: [
          for (final r in rows)
            InkWell(
              borderRadius: BorderRadius.circular(Lx.rButton),
              onTap: r.id == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BudgetTransactionsScreen(
                          month: _month, categoryId: r.id))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Lx.s8),
                child: Row(
                  children: [
                    CategoryAvatar(r.id == null ? '' : r.name,
                        income: _income, size: 36),
                    const SizedBox(width: Lx.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(r.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Lx.cardHeading.copyWith(fontSize: 14)),
                              ),
                              Text(rp(r.amount),
                                  style: Lx.cardHeading.copyWith(
                                      fontSize: 14, fontFeatures: tabular)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          RoundBar(
                              value: total == 0 ? 0 : r.amount / total,
                              color: _rowColor(r),
                              height: 6),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                  '${total == 0 ? 0 : (r.amount * 100 / total).round()}% dari total',
                                  style: Lx.metadata),
                              const Spacer(),
                              if (_previous != null && r.id != null)
                                r.before == null || r.before == 0
                                    ? Text('baru bulan ini', style: Lx.metadata)
                                    : _Delta(
                                        now: r.amount,
                                        before: r.before!,
                                        upIsBad: !_income),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The three biggest expenses of the month.
  Widget _biggest() {
    final list = _txns
        .where((t) => (_incomeOf[t.categoryId] ?? t.typeIncome) == false)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (_income || list.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Pengeluaran terbesar',
      padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
      child: Column(
        children: [
          for (final t in list.take(3))
            BudgetTxnRow(txn: t, isIncome: false, showDate: true),
        ],
      ),
    );
  }

  Widget _trendChart() {
    final data = _trend!;
    var top = 1;
    for (final s in data) {
      if (s == null) continue;
      if (s.income > top) top = s.income;
      if (s.expense > top) top = s.expense;
    }
    DateTime monthAt(int i) =>
        DateTime(_month.year, _month.month - (data.length - 1 - i));
    Widget bar(int v, Color c, bool on) => Container(
          width: 11,
          height: 4 + 100 * (v / top),
          decoration: BoxDecoration(
            color: on ? c : c.withOpacity(0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        );
    return SectionCard(
      title: '$_trendMonths bulan terakhir',
      subtitle: 'Ketuk bulan untuk membukanya',
      child: Column(
        children: [
          Row(
            children: [
              _legend('Pemasukan', Lx.success),
              const SizedBox(width: Lx.s16),
              _legend('Pengeluaran', Lx.danger),
            ],
          ),
          const SizedBox(height: Lx.s12),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < data.length; i++)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Lx.rSmall),
                      onTap: i == data.length - 1
                          ? null
                          : () => _setMonth(monthAt(i)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (data[i] == null)
                            Text('–', style: Lx.metadata)
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                bar(data[i]!.income, Lx.success,
                                    i == data.length - 1),
                                const SizedBox(width: 3),
                                bar(data[i]!.expense, Lx.danger,
                                    i == data.length - 1),
                              ],
                            ),
                          const SizedBox(height: 6),
                          Text(
                            monthNames[monthAt(i).month - 1].substring(0, 3),
                            style: Lx.metadata.copyWith(
                                color: i == data.length - 1 ? Lx.text : null,
                                fontWeight: i == data.length - 1
                                    ? FontWeight.w700
                                    : null),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Lx.s12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Lx.s12),
            decoration: BoxDecoration(
              color: Lx.background,
              borderRadius: BorderRadius.circular(Lx.rButton),
            ),
            child: Text(
                'Rata-rata pengeluaran ${rpShort(_avgExpense(data))} per bulan.',
                style: Lx.metadata.copyWith(color: Lx.text)),
          ),
        ],
      ),
    );
  }

  int _avgExpense(List<BudgetSummary?> data) {
    final ok = data.whereType<BudgetSummary>().toList();
    if (ok.isEmpty) return 0;
    return (ok.fold<int>(0, (a, s) => a + s.expense) / ok.length).round();
  }

  Widget _legend(String label, Color c) => Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: Lx.metadata),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final ready = _trend != null && _trend![_trendMonths - 1] != null;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Laporan')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s24),
            children: [
              BudgetMonthPill(month: _month, onChanged: _setMonth),
              const SizedBox(height: Lx.s12),
              if (_error != null)
                RetryState(_error!, onRetry: _load)
              else if (!ready)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                FlowTypeToggle(
                  income: _income,
                  onChanged: (v) => setState(() => _income = v),
                ),
                const SizedBox(height: Lx.s12),
                _summary(),
                _categories(),
                _biggest(),
                _trendChart(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row {
  const _Row(
      {required this.id,
      required this.name,
      required this.amount,
      this.before});

  /// Null for the "no category" remainder.
  final String? id;
  final String name;
  final int amount;

  /// The same category last month, null when it was not listed.
  final int? before;
}

/// "▲ 12%" against the previous month. For spending a rise is bad (red) and
/// a fall good (green); for income it is the other way round.
class _Delta extends StatelessWidget {
  const _Delta({
    required this.now,
    required this.before,
    required this.upIsBad,
    this.suffix = '',
  });

  final int now, before;
  final bool upIsBad;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (before == 0) return const SizedBox.shrink();
    final pct = ((now - before) * 100 / before).round();
    if (pct == 0) {
      return Text('Sama', style: Lx.metadata);
    }
    final up = pct > 0;
    final bad = up == upIsBad;
    final color = bad ? Lx.danger : Lx.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 12, color: color),
          const SizedBox(width: 2),
          Text('${pct.abs()}%${suffix.isEmpty ? '' : ' $suffix'}',
              style: Lx.metadata
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

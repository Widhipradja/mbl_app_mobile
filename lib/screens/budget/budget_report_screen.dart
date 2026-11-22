import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../finance/finance_data.dart' show rp, rpShort, monthLabel;
import '../finance/finance_widgets.dart';
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

  Widget _toggle() => SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Pengeluaran')),
          ButtonSegment(value: true, label: Text('Pemasukan')),
        ],
        selected: {_income},
        onSelectionChanged: (s) => setState(() => _income = s.first),
      );

  Widget _total() {
    final s = _current;
    final total = _income ? s.income : s.expense;
    final prevTotal = _previous == null
        ? null
        : (_income ? _previous!.income : _previous!.expense);
    final now = DateTime.now();
    final isThisMonth = _month.year == now.year && _month.month == now.month;
    final days =
        isThisMonth ? now.day : DateTime(_month.year, _month.month + 1, 0).day;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Lx.s16),
      decoration: BoxDecoration(
        color: Lx.primaryLight,
        borderRadius: BorderRadius.circular(Lx.rCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_income ? 'Total pemasukan' : 'Total pengeluaran',
              style: Lx.metadata),
          Text(rp(total),
              style: Lx.greeting
                  .copyWith(color: _income ? Lx.success : Lx.danger)),
          const SizedBox(height: Lx.s8),
          if (prevTotal != null && prevTotal > 0)
            _Delta(
                now: total,
                before: prevTotal,
                upIsBad: !_income,
                suffix: 'dari bulan lalu'),
          if (!_income && days > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Rata-rata ${rp((total / days).round())} per hari',
                  style: Lx.metadata),
            ),
        ],
      ),
    );
  }

  Widget _categories() {
    final rows = _rows();
    final total = _income ? _current.income : _current.expense;
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: Lx.s24),
        child: Center(
            child: Text(
                _income
                    ? 'Belum ada pemasukan bulan ini.'
                    : 'Belum ada pengeluaran bulan ini.',
                style: Lx.body)),
      );
    }
    final top = rows.first.amount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Lx.s24),
        Text('Per kategori', style: Lx.sectionHeading),
        const SizedBox(height: Lx.s12),
        for (final r in rows)
          InkWell(
            onTap: r.id == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BudgetTransactionsScreen(
                        month: _month, categoryId: r.id))),
            child: Padding(
              padding: const EdgeInsets.only(bottom: Lx.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(r.name, style: Lx.cardHeading)),
                      Text(rp(r.amount), style: Lx.cardHeading),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: top == 0 ? 0 : r.amount / top,
                      minHeight: 6,
                      backgroundColor: Lx.border,
                      color: _income ? Lx.success : Lx.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                          '${total == 0 ? 0 : (r.amount * 100 / total).round()}% '
                          'dari total',
                          style: Lx.metadata),
                      const Spacer(),
                      if (_previous != null && r.id != null)
                        r.before == null || r.before == 0
                            ? Text('baru', style: Lx.metadata)
                            : _Delta(
                                now: r.amount,
                                before: r.before!,
                                upIsBad: !_income),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The three biggest expenses of the month.
  Widget _biggest() {
    final list = _txns.where((t) => _incomeOf[t.categoryId] == false).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (_income || list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Lx.s8),
        Text('Pengeluaran terbesar', style: Lx.sectionHeading),
        for (var i = 0; i < list.take(3).length; i++) ...[
          if (i > 0) hairline,
          BudgetTxnRow(txn: list[i], isIncome: false, showDate: true),
        ],
      ],
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
    Widget bar(int v, Color c) => Container(
          width: 12,
          height: 4 + 96 * (v / top),
          decoration: BoxDecoration(
            color: c,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Lx.s24),
        Row(
          children: [
            Expanded(
                child: Text('$_trendMonths bulan terakhir',
                    style: Lx.sectionHeading)),
            _legend('Masuk', Lx.success),
            const SizedBox(width: Lx.s12),
            _legend('Keluar', Lx.danger),
          ],
        ),
        const SizedBox(height: Lx.s12),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < data.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: i == data.length - 1
                        ? null
                        : () => _setMonth(DateTime(
                            _month.year, _month.month - (data.length - 1 - i))),
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
                              bar(data[i]!.income, Lx.success),
                              const SizedBox(width: 3),
                              bar(data[i]!.expense, Lx.danger),
                            ],
                          ),
                        const SizedBox(height: 6),
                        Text(
                          monthNames[DateTime(_month.year,
                                          _month.month - (data.length - 1 - i))
                                      .month -
                                  1]
                              .substring(0, 3),
                          style: Lx.metadata.copyWith(
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
        const SizedBox(height: Lx.s8),
        Text('Rata-rata pengeluaran ${rpShort(_avgExpense(data))} per bulan.',
            style: Lx.metadata),
      ],
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
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
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
              MonthSwitcher(month: _month, onChanged: _setMonth),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: Lx.s24),
                  child: Column(
                    children: [
                      Text(_error!,
                          style: Lx.body, textAlign: TextAlign.center),
                      TextButton(
                          onPressed: _load, child: const Text('Coba lagi')),
                    ],
                  ),
                )
              else if (!ready)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _toggle(),
                const SizedBox(height: Lx.s16),
                _total(),
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
      return Text('Sama seperti bulan lalu', style: Lx.metadata);
    }
    final up = pct > 0;
    final bad = up == upIsBad;
    return Text(
      '${up ? '▲' : '▼'} ${pct.abs()}%${suffix.isEmpty ? '' : ' $suffix'}',
      style: Lx.metadata.copyWith(
          color: bad ? Lx.danger : Lx.success, fontWeight: FontWeight.w600),
    );
  }
}

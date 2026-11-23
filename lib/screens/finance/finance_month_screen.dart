import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../budget/budget_widgets.dart';
import 'finance_data.dart';
import 'finance_new_screen.dart';
import 'finance_voice_screen.dart';
import 'finance_widgets.dart';

enum _Filter { all, income, expense }

/// All transactions of one month, grouped by day, with a type filter.
class FinanceMonthScreen extends StatefulWidget {
  const FinanceMonthScreen({super.key, required this.month});

  final DateTime month;

  @override
  State<FinanceMonthScreen> createState() => _FinanceMonthScreenState();
}

class _FinanceMonthScreenState extends State<FinanceMonthScreen> {
  late DateTime _month = DateTime(widget.month.year, widget.month.month);
  _Filter _filter = _Filter.all;
  FinanceMonth? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final month = _month;
    setState(() => _error = null);
    try {
      final d = await financeRepo.month(month);
      if (!mounted || month != _month) return;
      setState(() => _data = d);
    } catch (e) {
      debugPrint('FinanceMonth load error: $e');
      if (mounted && month == _month) {
        setState(() => _error = financeError(e));
      }
    }
  }

  void _setMonth(DateTime m) {
    setState(() {
      _month = DateTime(m.year, m.month);
      _data = null;
    });
    _load();
  }

  /// The same "Catat" choice as the dashboard.
  Future<void> _add() async {
    final pick = await showAddEntrySheet(context);
    if (!mounted || pick == null) return;
    final screen = switch (pick) {
      'voice' => const FinanceVoiceScreen(),
      'income' => const FinanceNewScreen(initialIncome: true),
      _ => const FinanceNewScreen(),
    };
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (saved == true && mounted) _load();
  }

  List<FinanceTxn> _shown(FinanceMonth d) => d.txns.where((t) {
        switch (_filter) {
          case _Filter.income:
            return t.isIncome;
          case _Filter.expense:
            return !t.isIncome;
          case _Filter.all:
            return true;
        }
      }).toList();

  /// One white card per day, under its date and the day's balance.
  List<Widget> _rows(List<FinanceTxn> list) {
    if (list.isEmpty) {
      return [
        BudgetEmpty(
          icon: Icons.receipt_long_rounded,
          text: _filter == _Filter.all
              ? 'Belum ada transaksi bulan ini.'
              : 'Tidak ada transaksi dengan filter ini.',
          action: 'Catat transaksi',
          onAction: _add,
        ),
      ];
    }
    final days = <DateTime, List<FinanceTxn>>{};
    for (final t in list) {
      days
          .putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => [])
          .add(t);
    }
    return [
      for (final e in days.entries) ...[
        BudgetDayHeader(
          label: dateLabel(e.key),
          net: e.value.fold<int>(
              0, (s, t) => s + (t.isIncome ? t.amount : -t.amount)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Lx.s12),
          decoration: Lx.card(),
          child: Column(
            children: [
              for (var i = 0; i < e.value.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 52, color: Lx.border),
                TxnRow(txn: e.value[i]),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _chip(String label, _Filter f) => ChoiceChip(
        label: Text(label),
        selected: _filter == f,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = f),
      );

  Widget _totals(int income, int expense) {
    Widget cell(String label, int v, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Lx.metadata),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(rp(v),
                    style: Lx.cardHeading
                        .copyWith(color: color, fontFeatures: tabular)),
              ),
            ],
          ),
        );
    final net = income - expense;
    return Container(
      padding: const EdgeInsets.all(Lx.s12),
      decoration: Lx.card(),
      child: Row(
        children: [
          cell('Pemasukan', income, Lx.success),
          Container(width: 1, height: 32, color: Lx.border),
          const SizedBox(width: Lx.s12),
          cell('Pengeluaran', expense, Lx.text),
          Container(width: 1, height: 32, color: Lx.border),
          const SizedBox(width: Lx.s12),
          cell('Selisih', net, net < 0 ? Lx.danger : Lx.primary),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final list = d == null ? const <FinanceTxn>[] : _shown(d);
    var income = 0, expense = 0;
    for (final t in list) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Transaksi Kas')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Catat'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s8),
              child: BudgetMonthPill(month: _month, onChanged: _setMonth),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Lx.s16),
                children: [
                  _chip('Semua', _Filter.all),
                  const SizedBox(width: Lx.s8),
                  _chip('Pemasukan', _Filter.income),
                  const SizedBox(width: Lx.s8),
                  _chip('Pengeluaran', _Filter.expense),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(child: BudgetRetry(_error!, onRetry: _load))
                  : d == null
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                                Lx.s16, Lx.s8, Lx.s16, 96),
                            children: [
                              _totals(income, expense),
                              ..._rows(list),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

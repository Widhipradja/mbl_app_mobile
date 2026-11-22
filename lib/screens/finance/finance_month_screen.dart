import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import 'finance_data.dart';
import 'finance_new_screen.dart';
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

  Future<void> _new() async {
    final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const FinanceNewScreen()));
    if (saved == true && mounted) _load();
  }

  List<Widget> _rows(FinanceMonth d) {
    final list = d.txns.where((t) {
      switch (_filter) {
        case _Filter.income:
          return t.isIncome;
        case _Filter.expense:
          return !t.isIncome;
        case _Filter.all:
          return true;
      }
    }).toList();
    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 64),
          child: Center(child: Text('Tidak ada transaksi.', style: Lx.body)),
        ),
      ];
    }
    final out = <Widget>[];
    DateTime? day;
    for (final t in list) {
      final same = day != null &&
          day.year == t.date.year &&
          day.month == t.date.month &&
          day.day == t.date.day;
      if (!same) {
        out.add(GroupLabel(dateLabel(t.date)));
      } else {
        out.add(hairline);
      }
      day = t.date;
      out.add(TxnRow(txn: t));
    }
    return out;
  }

  Widget _chip(String label, _Filter f) => ChoiceChip(
        label: Text(label),
        selected: _filter == f,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = f),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Transaksi')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _new,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Transaksi'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Lx.s8),
              child: MonthSwitcher(month: _month, onChanged: _setMonth),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Lx.s16),
              child: Row(
                children: [
                  _chip('Semua', _Filter.all),
                  const SizedBox(width: Lx.s8),
                  _chip('Masuk', _Filter.income),
                  const SizedBox(width: Lx.s8),
                  _chip('Keluar', _Filter.expense),
                ],
              ),
            ),
            if (d != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Lx.s16, Lx.s12, Lx.s16, Lx.s4),
                child: Row(
                  children: [
                    Text('Masuk ${rp(d.income)}',
                        style: Lx.metadata.copyWith(color: Lx.success)),
                    const Spacer(),
                    Text('Keluar ${rp(d.expense)}',
                        style: Lx.metadata.copyWith(color: Lx.danger)),
                  ],
                ),
              ),
            const Divider(height: Lx.s8, thickness: 1, color: Lx.border),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: Lx.body),
                          TextButton(
                              onPressed: _load, child: const Text('Coba lagi')),
                        ],
                      ),
                    )
                  : d == null
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                                Lx.s16, 0, Lx.s16, 96),
                            children: _rows(d),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

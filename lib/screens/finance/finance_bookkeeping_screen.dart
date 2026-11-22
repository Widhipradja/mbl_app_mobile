import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import 'finance_data.dart';
import 'finance_widgets.dart';

/// Daily bookkeeping of one month: lines per report group with the running
/// balance (`finance/daily-bookkeeping`).
class FinanceBookkeepingScreen extends StatefulWidget {
  const FinanceBookkeepingScreen({super.key, required this.month});

  final DateTime month;

  @override
  State<FinanceBookkeepingScreen> createState() =>
      _FinanceBookkeepingScreenState();
}

class _FinanceBookkeepingScreenState extends State<FinanceBookkeepingScreen> {
  late DateTime _month = DateTime(widget.month.year, widget.month.month);
  FinanceBookkeeping? _data;
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
      final d = await financeRepo.bookkeeping(month);
      if (mounted && month == _month) setState(() => _data = d);
    } catch (e) {
      debugPrint('FinanceBookkeeping load error: $e');
      if (mounted && month == _month) setState(() => _error = financeError(e));
    }
  }

  void _setMonth(DateTime m) {
    setState(() {
      _month = DateTime(m.year, m.month);
      _data = null;
    });
    _load();
  }

  Widget _group(BookGroup g) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GroupLabel(g.label),
          Text(
              'Awal ${rp(g.opening)} · Masuk ${rp(g.income)} · '
              'Keluar ${rp(g.expense)} · Akhir ${rp(g.closing)}',
              style: Lx.metadata),
          const SizedBox(height: Lx.s8),
          for (var i = 0; i < g.lines.length; i++) ...[
            if (i > 0) hairline,
            _line(g.lines[i]),
          ],
          if (g.lines.isEmpty) Text('Tidak ada baris.', style: Lx.body),
        ],
      );

  Widget _line(BookLine l) {
    final income = l.income > 0;
    final amount = income ? l.income : l.expense;
    final color = income ? Lx.success : Lx.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Lx.s8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.description.isEmpty ? l.category : l.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Lx.cardHeading),
                Text('${dateShort(l.date)} · ${l.category}',
                    style: Lx.metadata),
              ],
            ),
          ),
          const SizedBox(width: Lx.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${income ? '+' : '−'}${thousands(amount)}',
                  style: Lx.cardHeading.copyWith(color: color)),
              Text('Saldo ${thousands(l.balance)}', style: Lx.metadata),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pembukuan Harian')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Lx.s8),
              child: MonthSwitcher(month: _month, onChanged: _setMonth),
            ),
            const Divider(height: 1, thickness: 1, color: Lx.border),
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
                                Lx.s16, Lx.s12, Lx.s16, Lx.s24),
                            children: [
                              Text(
                                  'Saldo awal ${rp(d.totalOpening)} → '
                                  'akhir ${rp(d.totalClosing)}',
                                  style: Lx.cardHeading),
                              if (d.difference != 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Selisih ${rp(d.difference)}',
                                      style: Lx.metadata
                                          .copyWith(color: Lx.warning)),
                                ),
                              if (d.groups.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 64),
                                  child: Center(
                                      child: Text('Belum ada pembukuan.',
                                          style: Lx.body)),
                                ),
                              for (final g in d.groups) _group(g),
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

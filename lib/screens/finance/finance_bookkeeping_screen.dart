import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart';
import 'finance_data.dart';

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

  Widget _stat(String label, int v, {Color color = Lx.text}) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Lx.metadata),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(rp(v),
                  style: Lx.cardHeading.copyWith(
                      fontSize: 13, color: color, fontFeatures: tabular)),
            ),
          ],
        ),
      );

  Widget _group(BookGroup g) => SectionCard(
        padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryAvatar(g.label, size: 32),
                const SizedBox(width: Lx.s8),
                Expanded(child: Text(g.label, style: Lx.cardHeading)),
              ],
            ),
            const SizedBox(height: Lx.s12),
            Container(
              padding: const EdgeInsets.all(Lx.s12),
              decoration: BoxDecoration(
                color: Lx.background,
                borderRadius: BorderRadius.circular(Lx.rButton),
              ),
              child: Column(
                children: [
                  Row(children: [
                    _stat('Saldo awal', g.opening),
                    _stat('Saldo akhir', g.closing, color: Lx.primary),
                  ]),
                  const SizedBox(height: Lx.s8),
                  Row(children: [
                    _stat('Masuk', g.income, color: Lx.success),
                    _stat('Keluar', g.expense),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: Lx.s4),
            if (g.lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Lx.s12),
                child: Text('Tidak ada transaksi.', style: Lx.body),
              ),
            for (var i = 0; i < g.lines.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Lx.border),
              _line(g.lines[i]),
            ],
          ],
        ),
      );

  Widget _line(BookLine l) {
    final income = l.income > 0;
    final amount = income ? l.income : l.expense;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.description.isEmpty ? l.category : l.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Lx.cardHeading.copyWith(fontSize: 14)),
                Text('${dateShort(l.date)} · ${l.category}',
                    style: Lx.metadata),
              ],
            ),
          ),
          const SizedBox(width: Lx.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(signedRp(amount, income),
                  style: Lx.cardHeading.copyWith(
                      fontSize: 14,
                      color: moneyColor(income),
                      fontFeatures: tabular)),
              Text('Saldo ${rp(l.balance)}',
                  style: Lx.metadata.copyWith(fontFeatures: tabular)),
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
              padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s8),
              child: MonthPill(month: _month, onChanged: _setMonth),
            ),
            Expanded(
              child: _error != null
                  ? Center(child: RetryState(_error!, onRetry: _load))
                  : d == null
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                                Lx.s16, Lx.s4, Lx.s16, Lx.s24),
                            children: [
                              SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total semua kelompok',
                                        style: Lx.metadata),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _stat('Saldo awal', d.totalOpening),
                                        const Icon(Icons.arrow_forward_rounded,
                                            size: 18, color: Lx.textMuted),
                                        const SizedBox(width: Lx.s12),
                                        _stat('Saldo akhir', d.totalClosing,
                                            color: Lx.primary),
                                      ],
                                    ),
                                    if (d.difference != 0) ...[
                                      const SizedBox(height: Lx.s8),
                                      Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded,
                                              size: 16, color: Lx.warning),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                                'Selisih ${rp(d.difference)} '
                                                'belum dijelaskan.',
                                                style: Lx.metadata.copyWith(
                                                    color: Lx.warning)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (d.groups.isEmpty)
                                const SectionCard(
                                  child: EmptyState(
                                    icon: Icons.menu_book_rounded,
                                    text: 'Belum ada pembukuan bulan ini.',
                                  ),
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

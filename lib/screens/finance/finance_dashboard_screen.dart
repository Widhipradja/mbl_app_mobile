import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import 'finance_bookkeeping_screen.dart';
import 'finance_data.dart';
import 'finance_month_screen.dart';
import 'finance_new_screen.dart';
import 'finance_pending_screen.dart';
import 'finance_voice_screen.dart';
import 'finance_widgets.dart';

/// Finance dashboard: balance and month totals, quick actions, expense per
/// category and the latest transactions.
class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  FinanceMonth? _data;
  int _pending = 0;
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
    });
    try {
      // The badge is secondary: a failing pending call must not hide the month.
      final pendingFuture = financeRepo
          .pending()
          .then((l) => l.length)
          .catchError((Object e) => _pending);
      final data = await financeRepo.month(month);
      final pending = await pendingFuture;
      if (!mounted || month != _month) return;
      setState(() {
        _data = data;
        _pending = pending;
      });
    } catch (e) {
      debugPrint('FinanceDashboard load error: $e');
      if (mounted && month == _month) {
        setState(() => _error = financeError(e));
      }
    } finally {
      if (mounted && month == _month) setState(() => _loading = false);
    }
  }

  void _setMonth(DateTime m) {
    setState(() => _month = DateTime(m.year, m.month));
    _load();
  }

  Future<void> _new({required bool income}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FinanceNewScreen(initialIncome: income),
    ));
    if (saved == true && mounted) _load();
  }

  void _openMonth() => Navigator.of(context)
      .push(
          MaterialPageRoute(builder: (_) => FinanceMonthScreen(month: _month)))
      .then((_) => _load());

  Widget _balanceCard(FinanceMonth d) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Lx.s16),
        decoration: BoxDecoration(
          color: Lx.primaryLight,
          borderRadius: BorderRadius.circular(Lx.rCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo akhir ${monthLabel(d.month)}', style: Lx.metadata),
            const SizedBox(height: 2),
            Text(rp(d.closing),
                style: Lx.greeting.copyWith(color: Lx.primaryDark)),
            Text('Saldo awal ${rp(d.opening)}', style: Lx.metadata),
            const SizedBox(height: Lx.s12),
            Row(
              children: [
                _flow('Masuk', d.income, Lx.success, Icons.south_west_rounded),
                const SizedBox(width: Lx.s16),
                _flow('Keluar', d.expense, Lx.danger, Icons.north_east_rounded),
              ],
            ),
            if (d.difference != 0) ...[
              const SizedBox(height: Lx.s12),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Lx.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        'Selisih ledger ${rp(d.difference)}: ada pergerakan '
                        'yang belum dijelaskan baris register.',
                        style: Lx.metadata.copyWith(color: Lx.warning)),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  Widget _flow(String label, int v, Color c, IconData icon) => Expanded(
        child: Row(
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 4),
            Flexible(
              child: Text('$label ${rpShort(v)}',
                  overflow: TextOverflow.ellipsis,
                  style: Lx.cardHeading.copyWith(color: c)),
            ),
          ],
        ),
      );

  Future<void> _voice() async {
    final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const FinanceVoiceScreen()));
    if (done == true && mounted) _load();
  }

  Future<void> _pendingScreen() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FinancePendingScreen()));
    if (mounted) _load();
  }

  Widget _links() => Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Badge(
              isLabelVisible: _pending > 0,
              label: Text('$_pending'),
              child: const Icon(Icons.hourglass_top_rounded, color: Lx.primary),
            ),
            title: const Text('Menunggu persetujuan', style: Lx.cardHeading),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _pendingScreen,
          ),
          hairline,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined, color: Lx.primary),
            title: const Text('Pembukuan harian', style: Lx.cardHeading),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FinanceBookkeepingScreen(month: _month))),
          ),
        ],
      );

  Widget _actions() => Column(
        children: [
          _actionRow(),
          const SizedBox(height: Lx.s12),
          OutlinedButton.icon(
            onPressed: _voice,
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Catat dengan suara'),
          ),
        ],
      );

  Widget _actionRow() => Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _new(income: true),
              style: FilledButton.styleFrom(
                  backgroundColor: Lx.success,
                  minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Pemasukan'),
            ),
          ),
          const SizedBox(width: Lx.s12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _new(income: false),
              style: FilledButton.styleFrom(
                  backgroundColor: Lx.danger,
                  minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.remove_rounded),
              label: const Text('Pengeluaran'),
            ),
          ),
        ],
      );

  Widget _categories(FinanceMonth d) {
    final rows = d.expenseByCategory;
    if (rows.isEmpty) return const SizedBox.shrink();
    final top = rows.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Lx.s24),
        Text('Pengeluaran per kategori', style: Lx.sectionHeading),
        const SizedBox(height: Lx.s12),
        for (final e in rows.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: Lx.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(e.key, style: Lx.body)),
                    Text(rp(e.value), style: Lx.cardHeading),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: top == 0 ? 0 : e.value / top,
                    minHeight: 6,
                    backgroundColor: Lx.border,
                    color: Lx.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _recent(FinanceMonth d) {
    final rows = d.txns.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Lx.s12),
        Row(
          children: [
            Expanded(
                child: Text('Transaksi terbaru', style: Lx.sectionHeading)),
            TextButton(onPressed: _openMonth, child: const Text('Lihat semua')),
          ],
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Lx.s16),
            child: Text('Belum ada transaksi bulan ini.', style: Lx.body),
          ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) hairline,
          TxnRow(txn: rows[i], showDate: true),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Keuangan')),
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
                      Text(_error!, style: Lx.body),
                      TextButton(
                          onPressed: _load, child: const Text('Coba lagi')),
                    ],
                  ),
                )
              else if (d == null || _loading && d.month != _month)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _balanceCard(d),
                const SizedBox(height: Lx.s16),
                _actions(),
                const SizedBox(height: Lx.s8),
                _links(),
                _categories(d),
                _recent(d),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

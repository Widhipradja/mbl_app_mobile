import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../budget/budget_widgets.dart';
import 'finance_bookkeeping_screen.dart';
import 'finance_data.dart';
import 'finance_month_screen.dart';
import 'finance_new_screen.dart';
import 'finance_pending_screen.dart';
import 'finance_voice_screen.dart';
import 'finance_widgets.dart';

/// Finance dashboard: the organisation's balance for the month, shortcuts,
/// what waits for approval, expense per category and the latest entries.
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

  Future<void> _go(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _load();
  }

  Future<void> _push(Widget screen) async {
    final done = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (done == true && mounted) _load();
  }

  Future<void> _add() async {
    final pick = await showAddEntrySheet(context);
    if (!mounted || pick == null) return;
    switch (pick) {
      case 'voice':
        await _push(const FinanceVoiceScreen());
      case 'income':
        await _push(const FinanceNewScreen(initialIncome: true));
      default:
        await _push(const FinanceNewScreen());
    }
  }

  // ── Balance ──────────────────────────────────────────────────────────────

  Widget _balance(FinanceMonth d) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Lx.s20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Lx.rSection),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
          ),
          boxShadow: Lx.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo kas akhir ${monthLabel(d.month)}',
                style: Lx.metadata.copyWith(color: Colors.white70)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(rp(d.closing),
                  style: Lx.userName.copyWith(
                      color: Colors.white,
                      fontSize: 30,
                      fontFeatures: tabular)),
            ),
            const SizedBox(height: 2),
            Text('Saldo awal ${rp(d.opening)}',
                style: Lx.metadata
                    .copyWith(color: Colors.white70, fontFeatures: tabular)),
            const SizedBox(height: Lx.s16),
            Row(
              children: [
                _flow('Pemasukan', d.income, Icons.south_west_rounded,
                    const Color(0xFFBBF7D0)),
                const SizedBox(width: Lx.s12),
                _flow('Pengeluaran', d.expense, Icons.north_east_rounded,
                    const Color(0xFFFECACA)),
              ],
            ),
            if (d.difference != 0) ...[
              const SizedBox(height: Lx.s12),
              Container(
                padding: const EdgeInsets.all(Lx.s8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(Lx.rSmall),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: Color(0xFFB45309)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'Selisih ledger ${rp(d.difference)}: ada pergerakan '
                          'yang belum dijelaskan baris register.',
                          style: Lx.metadata
                              .copyWith(color: const Color(0xFF92400E))),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  Widget _flow(String label, int v, IconData icon, Color accent) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(Lx.s12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(Lx.rButton),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: accent),
                  const SizedBox(width: 4),
                  Text(label,
                      style: Lx.metadata.copyWith(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(rp(v),
                    style: Lx.cardHeading.copyWith(
                        color: Colors.white, fontFeatures: tabular)),
              ),
            ],
          ),
        ),
      );

  // ── Shortcuts ────────────────────────────────────────────────────────────

  Widget _shortcuts() {
    Widget tile(IconData icon, String label, Color color, Color tint,
            VoidCallback onTap,
            {int badge = 0}) =>
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Lx.rTile),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Lx.s8),
              child: Column(
                children: [
                  Badge(
                    isLabelVisible: badge > 0,
                    label: Text('$badge'),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(Lx.rButton + 2),
                      ),
                      child: Icon(icon, color: color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      style: Lx.moduleLabel.copyWith(fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Lx.s12),
      child: Row(
        children: [
          tile(Icons.receipt_long_rounded, 'Transaksi', Lx.primary,
              Lx.primaryLight, () => _go(FinanceMonthScreen(month: _month))),
          tile(Icons.fact_check_rounded, 'Persetujuan',
              const Color(0xFFEA580C), const Color(0xFFFFEDD5),
              () => _go(const FinancePendingScreen()),
              badge: _pending),
          tile(Icons.menu_book_rounded, 'Pembukuan', const Color(0xFF7C3AED),
              Lx.secondaryLight,
              () => _go(FinanceBookkeepingScreen(month: _month))),
        ],
      ),
    );
  }

  /// A reminder when something waits for the treasurer.
  Widget _pendingBanner() => Padding(
        padding: const EdgeInsets.only(bottom: Lx.s12),
        child: Material(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(Lx.rCard),
          child: InkWell(
            borderRadius: BorderRadius.circular(Lx.rCard),
            onTap: () => _go(const FinancePendingScreen()),
            child: Container(
              padding: const EdgeInsets.all(Lx.s12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Lx.rCard),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: Color(0xFFEA580C)),
                  const SizedBox(width: Lx.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$_pending transaksi menunggu persetujuan',
                            style: Lx.cardHeading.copyWith(fontSize: 14)),
                        Text('Belum masuk saldo sampai disetujui bendahara.',
                            style: Lx.metadata),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Lx.textSecondary),
                ],
              ),
            ),
          ),
        ),
      );

  // ── Categories ───────────────────────────────────────────────────────────

  Widget _categories(FinanceMonth d) {
    final rows = d.expenseByCategory;
    if (rows.isEmpty) return const SizedBox.shrink();
    final total = d.expense == 0
        ? rows.fold<int>(0, (a, e) => a + e.value)
        : d.expense;
    return BudgetCard(
      title: 'Pengeluaran per kategori',
      subtitle: rows.length > 5 ? '5 terbesar dari ${rows.length}' : null,
      padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
      child: Column(
        children: [
          for (final e in rows.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Lx.s8),
              child: Row(
                children: [
                  CategoryAvatar(e.key, income: false, size: 36),
                  const SizedBox(width: Lx.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(e.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Lx.cardHeading.copyWith(fontSize: 14)),
                            ),
                            Text(rp(e.value),
                                style: Lx.cardHeading.copyWith(
                                    fontSize: 14, fontFeatures: tabular)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        BudgetBar(
                            value: total == 0 ? 0 : e.value / total,
                            color: categoryLook(e.key, income: false).color,
                            height: 6),
                        const SizedBox(height: 4),
                        Text(
                            '${total == 0 ? 0 : (e.value * 100 / total).round()}% dari pengeluaran',
                            style: Lx.metadata),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _recent(FinanceMonth d) {
    final rows = d.txns.take(5).toList();
    return BudgetCard(
      title: 'Transaksi terbaru',
      action: rows.isEmpty ? null : 'Lihat semua',
      onAction: () => _go(FinanceMonthScreen(month: _month)),
      padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
      child: rows.isEmpty
          ? BudgetEmpty(
              icon: Icons.receipt_long_rounded,
              text: 'Belum ada transaksi bulan ini.',
              action: 'Catat sekarang',
              onAction: _add,
            )
          : Column(
              children: [
                for (final t in rows) TxnRow(txn: t, showDate: true),
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
        appBar: AppBar(title: const Text('Keuangan')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Catat'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, 96),
            children: [
              BudgetMonthPill(month: _month, onChanged: _setMonth),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Lx.s12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.groups_outlined,
                          size: 15, color: Lx.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Kas organisasi. Transaksi baru menunggu persetujuan '
                        'bendahara sebelum masuk saldo.',
                        style: Lx.metadata.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                BudgetRetry(_error!, onRetry: _load)
              else if (d == null || _loading && d.month != _month)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _balance(d),
                _shortcuts(),
                if (_pending > 0) _pendingBanner(),
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

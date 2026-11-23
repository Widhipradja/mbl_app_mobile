import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart';
import '../finance/finance_data.dart' show rp;
import '../finance/finance_widgets.dart' show showAddEntrySheet;
import 'budget_categories_screen.dart';
import 'budget_data.dart';
import 'budget_form_screen.dart';
import 'budget_limits_screen.dart';
import 'budget_report_screen.dart';
import 'budget_transactions_screen.dart';
import 'budget_voice_screen.dart';
import 'budget_widgets.dart';

/// The personal wallet: the month's balance at a glance, shortcuts to the
/// rest of the module, budget use, and the latest entries.
class BudgetWalletScreen extends StatefulWidget {
  const BudgetWalletScreen({super.key});

  @override
  State<BudgetWalletScreen> createState() => _BudgetWalletScreenState();
}

class _BudgetWalletScreenState extends State<BudgetWalletScreen> {
  /// Budget rows shown on the home card; the rest are one tap away.
  static const _budgetRows = 4;

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  BudgetSummary? _summary;
  List<BudgetTxn> _recent = const [];
  Map<String, bool> _income = const {};
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
      final r = await Future.wait([
        budgetRepo.summary(month),
        budgetRepo.transactions(month, limit: 5),
        budgetRepo.categories(),
      ]);
      if (!mounted || month != _month) return;
      setState(() {
        _summary = r[0] as BudgetSummary;
        _recent = r[1] as List<BudgetTxn>;
        _income = {
          for (final c in r[2] as List<BudgetCategory>) c.id: c.isIncome
        };
      });
    } catch (e) {
      debugPrint('BudgetWallet load error: $e');
      if (mounted && month == _month) setState(() => _error = budgetError(e));
    }
  }

  void _setMonth(DateTime m) {
    setState(() {
      _month = DateTime(m.year, m.month);
      _summary = null;
    });
    _load();
  }

  Future<void> _go(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _load();
  }

  bool? _typeOf(BudgetTxn t) => _income[t.categoryId] ?? t.typeIncome;

  /// Detail first (the voice note shows there), then change or delete.
  Future<void> _open(BudgetTxn t) async {
    final act = await showBudgetTxnDetail(context, t, _typeOf(t));
    if (!mounted || act == null) return;
    if (act == 'edit') {
      await _go(BudgetFormScreen(txn: t));
    } else {
      try {
        await budgetRepo.deleteTransaction(t.id);
        if (mounted) _load();
      } catch (e) {
        debugPrint('BudgetWallet delete error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(budgetError(e))));
        }
      }
    }
  }

  /// One button, then the choice: what happened, or say it.
  Future<void> _add() async {
    final pick = await showAddEntrySheet(context);
    if (!mounted || pick == null) return;
    switch (pick) {
      case 'voice':
        await _go(const BudgetVoiceScreen());
      case 'income':
        await _go(const BudgetFormScreen(initialIncome: true));
      default:
        await _go(const BudgetFormScreen());
    }
  }

  /// What this module is for, for someone opening it the first time.
  Widget _intro() => Padding(
        padding: const EdgeInsets.only(top: Lx.s12, bottom: Lx.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.lock_outline_rounded,
                  size: 15, color: Lx.textSecondary),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Catatan keuangan pribadi: pemasukan dan pengeluaran harian '
                '(ketik atau ucapkan), anggaran per kategori, dan laporan ke '
                'mana uang Anda pergi. Hanya Anda yang melihatnya.',
                style: Lx.metadata.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      );

  // ── Balance ──────────────────────────────────────────────────────────────

  Widget _balance(BudgetSummary s) {
    final used = s.income > 0 ? s.expense / s.income : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Lx.s20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Lx.rSection),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Lx.bannerStart, Lx.primary],
        ),
        boxShadow: Lx.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saldo bulan ini',
              style: Lx.metadata.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rp(s.net),
              style: Lx.userName.copyWith(
                  color: Colors.white, fontSize: 30, fontFeatures: tabular),
            ),
          ),
          if (s.net < 0)
            Text('Pengeluaran melebihi pemasukan',
                style: Lx.metadata.copyWith(color: const Color(0xFFFECACA))),
          const SizedBox(height: Lx.s16),
          Row(
            children: [
              _flow('Pemasukan', s.income, Icons.south_west_rounded,
                  const Color(0xFFBBF7D0)),
              const SizedBox(width: Lx.s12),
              _flow('Pengeluaran', s.expense, Icons.north_east_rounded,
                  const Color(0xFFFECACA)),
            ],
          ),
          if (used != null) ...[
            const SizedBox(height: Lx.s16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: used.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white24,
                color: used > 1 ? const Color(0xFFFCA5A5) : Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(used * 100).round()}% pemasukan sudah terpakai',
              style: Lx.metadata.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

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
            VoidCallback onTap) =>
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Lx.rTile),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Lx.s8),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(Lx.rButton + 2),
                    ),
                    child: Icon(icon, color: color),
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
              Lx.primaryLight, () => _go(BudgetTransactionsScreen(month: _month))),
          tile(Icons.pie_chart_rounded, 'Laporan', const Color(0xFF7C3AED),
              Lx.secondaryLight, () => _go(BudgetReportScreen(month: _month))),
          tile(Icons.track_changes_rounded, 'Anggaran', const Color(0xFFEA580C),
              const Color(0xFFFFEDD5), () => _go(BudgetLimitsScreen(month: _month))),
          tile(Icons.category_rounded, 'Kategori', const Color(0xFF0D9488),
              const Color(0xFFCCFBF1), () => _go(const BudgetCategoriesScreen())),
        ],
      ),
    );
  }

  // ── Budget ───────────────────────────────────────────────────────────────

  Widget _budget(BudgetSummary s) {
    final lines = s.budgeted;
    if (lines.isEmpty) {
      return SectionCard(
        title: 'Anggaran bulan ini',
        child: EmptyState(
          icon: Icons.track_changes_rounded,
          text: 'Tentukan batas belanja per kategori, lalu pantau sisanya '
              'di sini.',
          action: 'Atur anggaran',
          onAction: () => _go(BudgetLimitsScreen(month: _month)),
        ),
      );
    }
    final total = s.limitTotal;
    final spent = s.spentInBudget;
    final pct = total == 0 ? 0.0 : spent * 100 / total;
    final over = spent > total;
    final more = lines.length - _budgetRows;
    return SectionCard(
      title: 'Anggaran bulan ini',
      action: 'Atur',
      onAction: () => _go(BudgetLimitsScreen(month: _month)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: rp(over ? spent - total : total - spent),
                        style: Lx.sectionHeading.copyWith(
                            color: over ? Lx.danger : Lx.text,
                            fontFeatures: tabular)),
                    TextSpan(
                        text: over ? '  melebihi anggaran' : '  tersisa',
                        style: Lx.metadata),
                  ]),
                ),
              ),
              Text('dari ${rp(total)}',
                  style: Lx.metadata.copyWith(fontFeatures: tabular)),
            ],
          ),
          const SizedBox(height: Lx.s8),
          RoundBar(value: pct / 100, color: budgetColor(pct, over), height: 10),
          const SizedBox(height: Lx.s8),
          for (final l in lines.take(_budgetRows))
            BudgetProgressRow(
              line: l,
              onTap: () => _go(BudgetTransactionsScreen(
                  month: _month, categoryId: l.categoryId)),
            ),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: Lx.s4),
              child: Text('+$more kategori lain di Anggaran',
                  style: Lx.metadata),
            ),
        ],
      ),
    );
  }

  // ── Recent ───────────────────────────────────────────────────────────────

  Widget _recentCard() => SectionCard(
        title: 'Transaksi terbaru',
        action: _recent.isEmpty ? null : 'Lihat semua',
        onAction: () => _go(BudgetTransactionsScreen(month: _month)),
        padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
        child: _recent.isEmpty
            ? EmptyState(
                icon: Icons.receipt_long_rounded,
                text: 'Belum ada transaksi bulan ini.',
                action: 'Catat sekarang',
                onAction: _add,
              )
            : Column(
                children: [
                  for (final t in _recent)
                    BudgetTxnRow(
                      txn: t,
                      isIncome: _typeOf(t),
                      showDate: true,
                      onTap: () => _open(t),
                    ),
                ],
              ),
      );

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Dompet Saya')),
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
              MonthPill(month: _month, onChanged: _setMonth),
              _intro(),
              if (_error != null)
                RetryState(_error!, onRetry: _load)
              else if (s == null)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _balance(s),
                _shortcuts(),
                _budget(s),
                _recentCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

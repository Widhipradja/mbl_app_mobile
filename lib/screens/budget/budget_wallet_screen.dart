import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../finance/finance_data.dart' show rp, rpShort;
import '../finance/finance_widgets.dart';
import 'budget_categories_screen.dart';
import 'budget_data.dart';
import 'budget_form_screen.dart';
import 'budget_limits_screen.dart';
import 'budget_report_screen.dart';
import 'budget_transactions_screen.dart';
import 'budget_voice_screen.dart';
import 'budget_widgets.dart';

/// The personal wallet: the month at a glance, budget per category, quick
/// add, and the way to everything else.
class BudgetWalletScreen extends StatefulWidget {
  const BudgetWalletScreen({super.key});

  @override
  State<BudgetWalletScreen> createState() => _BudgetWalletScreenState();
}

class _BudgetWalletScreenState extends State<BudgetWalletScreen> {
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

  /// Detail first (the voice note shows there), then change or delete.
  Future<void> _open(BudgetTxn t) async {
    final act = await showBudgetTxnDetail(context, t, _income[t.categoryId]);
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

  /// What this screen is for, in a line, for someone opening it first.
  Widget _intro() => Container(
        margin: const EdgeInsets.only(bottom: Lx.s16),
        padding: const EdgeInsets.all(Lx.s12),
        decoration: BoxDecoration(
          color: Lx.surface,
          borderRadius: BorderRadius.circular(Lx.rButton),
          border: Border.all(color: Lx.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: Lx.primary),
            const SizedBox(width: Lx.s8),
            Expanded(
              child: Text(
                'Catatan keuangan pribadi Anda: pemasukan dan pengeluaran '
                'harian (ketik atau rekam suara), anggaran per kategori, dan '
                'laporan ke mana uang Anda pergi. Hanya Anda yang melihatnya.',
                style: Lx.metadata.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _card(BudgetSummary s) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Lx.s16),
        decoration: BoxDecoration(
          color: Lx.primaryLight,
          borderRadius: BorderRadius.circular(Lx.rCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sisa bulan ini', style: Lx.metadata),
            const SizedBox(height: 2),
            Text(rp(s.net),
                style: Lx.greeting
                    .copyWith(color: s.net < 0 ? Lx.danger : Lx.primaryDark)),
            const SizedBox(height: Lx.s12),
            Row(
              children: [
                _flow('Masuk', s.income, Lx.success, Icons.south_west_rounded),
                const SizedBox(width: Lx.s16),
                _flow('Keluar', s.expense, Lx.danger, Icons.north_east_rounded),
              ],
            ),
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

  Widget _budgetSection(BudgetSummary s) {
    final lines = s.budgeted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Lx.s24),
        Row(
          children: [
            Expanded(
                child: Text('Anggaran bulan ini', style: Lx.sectionHeading)),
            TextButton(
                onPressed: () => _go(BudgetLimitsScreen(month: _month)),
                child: Text(lines.isEmpty ? 'Atur' : 'Ubah')),
          ],
        ),
        if (lines.isEmpty)
          Text(
              'Belum ada anggaran. Atur batas per kategori untuk memantau '
              'pengeluaran.',
              style: Lx.body)
        else ...[
          Text('Terpakai ${rp(s.spentInBudget)} dari ${rp(s.limitTotal)}',
              style: Lx.metadata),
          const SizedBox(height: Lx.s12),
          for (final l in lines) BudgetProgressRow(line: l),
        ],
      ],
    );
  }

  Widget _recentSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Lx.s8),
          Row(
            children: [
              Expanded(
                  child: Text('Transaksi terbaru', style: Lx.sectionHeading)),
              TextButton(
                onPressed: () => _go(BudgetTransactionsScreen(month: _month)),
                child: const Text('Lihat semua'),
              ),
            ],
          ),
          if (_recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Lx.s16),
              child: Text('Belum ada transaksi bulan ini.', style: Lx.body),
            ),
          for (var i = 0; i < _recent.length; i++) ...[
            if (i > 0) hairline,
            BudgetTxnRow(
              txn: _recent[i],
              isIncome: _income[_recent[i].categoryId],
              showDate: true,
              onTap: () => _open(_recent[i]),
            ),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dompet Saya'),
          actions: [
            IconButton(
              tooltip: 'Laporan',
              onPressed: () => _go(BudgetReportScreen(month: _month)),
              icon: const Icon(Icons.bar_chart_rounded),
            ),
            IconButton(
              tooltip: 'Kelola kategori',
              onPressed: () => _go(const BudgetCategoriesScreen()),
              icon: const Icon(Icons.category_outlined),
            ),
          ],
        ),
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
              MonthSwitcher(month: _month, onChanged: _setMonth),
              _intro(),
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
              else if (s == null)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _card(s),
                const SizedBox(height: Lx.s8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pie_chart_outline_rounded,
                      color: Lx.primary),
                  title:
                      const Text('Laporan per kategori', style: Lx.cardHeading),
                  subtitle: Text('Ke mana uang Anda pergi bulan ini',
                      style: Lx.metadata),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _go(BudgetReportScreen(month: _month)),
                ),
                _budgetSection(s),
                _recentSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

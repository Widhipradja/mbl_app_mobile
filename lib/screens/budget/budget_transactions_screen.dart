import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart';
import '../finance/finance_data.dart' show rp, dateLabel;
import '../finance/finance_widgets.dart' show showAddEntrySheet;
import 'budget_data.dart';
import 'budget_form_screen.dart';
import 'budget_voice_screen.dart';
import 'budget_widgets.dart';

enum _Filter { all, income, expense }

/// Transactions of one month, grouped by day. Tap to edit, swipe to delete.
class BudgetTransactionsScreen extends StatefulWidget {
  const BudgetTransactionsScreen(
      {super.key, required this.month, this.categoryId});

  final DateTime month;

  /// Opens already filtered on this category (from the report).
  final String? categoryId;

  @override
  State<BudgetTransactionsScreen> createState() =>
      _BudgetTransactionsScreenState();
}

class _BudgetTransactionsScreenState extends State<BudgetTransactionsScreen> {
  late DateTime _month = DateTime(widget.month.year, widget.month.month);
  _Filter _filter = _Filter.all;
  late String? _categoryId = widget.categoryId;
  List<BudgetTxn>? _txns;
  List<BudgetCategory> _categories = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  BudgetCategory? get _category {
    for (final c in _categories) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  Map<String, bool> get _income =>
      {for (final c in _categories) c.id: c.isIncome};

  Future<void> _load() async {
    final month = _month;
    setState(() => _error = null);
    try {
      final r = await Future.wait([
        budgetRepo.transactions(month, categoryId: _categoryId),
        budgetRepo.categories(),
      ]);
      if (!mounted || month != _month) return;
      setState(() {
        _txns = r[0] as List<BudgetTxn>;
        _categories = r[1] as List<BudgetCategory>;
      });
    } catch (e) {
      debugPrint('BudgetTransactions load error: $e');
      if (mounted && month == _month) setState(() => _error = budgetError(e));
    }
  }

  void _setMonth(DateTime m) {
    setState(() {
      _month = DateTime(m.year, m.month);
      _txns = null;
    });
    _load();
  }

  Future<void> _edit([BudgetTxn? t]) async {
    final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => BudgetFormScreen(txn: t)));
    if (saved == true && mounted) _load();
  }

  /// The same "Catat" choice as the wallet.
  Future<void> _add() async {
    final pick = await showAddEntrySheet(context);
    if (!mounted || pick == null) return;
    final screen = switch (pick) {
      'voice' => const BudgetVoiceScreen(),
      'income' => const BudgetFormScreen(initialIncome: true),
      _ => const BudgetFormScreen(),
    };
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (saved == true && mounted) _load();
  }

  /// Detail first (the voice note shows there), then change or delete.
  Future<void> _open(BudgetTxn t) async {
    final act = await showBudgetTxnDetail(context, t, _income[t.categoryId] ?? t.typeIncome);
    if (!mounted || act == null) return;
    if (act == 'edit') {
      await _edit(t);
    } else if (await _confirmDelete(t) && mounted) {
      _load();
    }
  }

  Future<bool> _confirmDelete(BudgetTxn t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content:
            Text('${t.description.isEmpty ? t.categoryName : t.description} · '
                '${rp(t.amount)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Lx.danger),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await budgetRepo.deleteTransaction(t.id);
      return true;
    } catch (e) {
      debugPrint('BudgetTransactions delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(budgetError(e))));
      }
      return false;
    }
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<BudgetCategory?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Lx.primaryLight,
                    child: Icon(Icons.all_inclusive_rounded,
                        color: Lx.primary, size: 20)),
                title: const Text('Semua kategori'),
                trailing: _category == null
                    ? const Icon(Icons.check_rounded, color: Lx.primary)
                    : null,
                onTap: () => Navigator.pop(context, null),
              ),
              for (final c in _categories)
                ListTile(
                  leading: CategoryAvatar(c.name, income: c.isIncome),
                  title: Text(c.name),
                  subtitle: Text(c.isIncome ? 'Pemasukan' : 'Pengeluaran'),
                  trailing: _category?.id == c.id
                      ? const Icon(Icons.check_rounded, color: Lx.primary)
                      : null,
                  onTap: () => Navigator.pop(context, c),
                ),
            ],
          ),
        ),
      ),
    );
    // A dismissed sheet also returns null; only an explicit choice reloads.
    if (!mounted) return;
    if (picked?.id != _categoryId) {
      setState(() {
        _categoryId = picked?.id;
        _txns = null;
      });
      _load();
    }
  }

  List<BudgetTxn> get _shown => (_txns ?? const []).where((t) {
        final inc = _income[t.categoryId] ?? t.typeIncome;
        switch (_filter) {
          case _Filter.income:
            return inc == true;
          case _Filter.expense:
            return inc == false;
          case _Filter.all:
            return true;
        }
      }).toList();

  Widget _chip(String label, _Filter f) => ChoiceChip(
        label: Text(label),
        selected: _filter == f,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = f),
      );

  /// One white card per day, under its date and the day's balance.
  List<Widget> _rows(List<BudgetTxn> list) {
    if (list.isEmpty) {
      return [
        EmptyState(
          icon: Icons.receipt_long_rounded,
          text: _categoryId != null || _filter != _Filter.all
              ? 'Tidak ada transaksi dengan filter ini.'
              : 'Belum ada transaksi bulan ini.',
          action: 'Catat transaksi',
          onAction: _add,
        ),
      ];
    }
    final days = <DateTime, List<BudgetTxn>>{};
    for (final t in list) {
      days.putIfAbsent(t.date, () => []).add(t);
    }
    return [
      for (final e in days.entries) ...[
        DayHeader(
          label: dateLabel(e.key),
          net: e.value.fold<int>(0, (s, t) {
            final inc = _income[t.categoryId] ?? t.typeIncome;
            return inc == null ? s : s + (inc ? t.amount : -t.amount);
          }),
        ),
        Container(
          decoration: Lx.card(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < e.value.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, indent: 64, color: Lx.border),
                _dismissible(e.value[i]),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _dismissible(BudgetTxn t) => Dismissible(
        key: ValueKey(t.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDelete(t),
        onDismissed: (_) => _load(),
        background: Container(
          color: Lx.danger,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: Lx.s16),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.white),
              SizedBox(width: 4),
              Text('Hapus', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Lx.s12),
          child: BudgetTxnRow(
              txn: t,
              isIncome: _income[t.categoryId] ?? t.typeIncome,
              onTap: () => _open(t)),
        ),
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
    final all = _txns;
    final list = _shown;
    var income = 0, expense = 0;
    for (final t in list) {
      final inc = _income[t.categoryId] ?? t.typeIncome;
      if (inc == true) income += t.amount;
      if (inc == false) expense += t.amount;
    }
    final cat = _category;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Transaksi')),
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
                  const SizedBox(width: Lx.s8),
                  InputChip(
                    avatar: cat == null
                        ? const Icon(Icons.filter_list_rounded, size: 18)
                        : Icon(categoryLook(cat.name, income: cat.isIncome).icon,
                            size: 16,
                            color:
                                categoryLook(cat.name, income: cat.isIncome).color),
                    label: Text(cat?.name ?? 'Kategori'),
                    selected: cat != null,
                    showCheckmark: false,
                    onPressed: _categories.isEmpty ? null : _pickCategory,
                    onDeleted: cat == null
                        ? null
                        : () {
                            setState(() {
                              _categoryId = null;
                              _txns = null;
                            });
                            _load();
                          },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(child: RetryState(_error!, onRetry: _load))
                  : all == null
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
                              if (all.length >= 200)
                                Padding(
                                  padding: const EdgeInsets.only(top: Lx.s16),
                                  child: Text(
                                      'Menampilkan 200 transaksi terbaru. '
                                      'Gunakan filter kategori untuk '
                                      'mempersempit.',
                                      style: Lx.metadata),
                                ),
                              if (list.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: Lx.s12),
                                  child: Text(
                                      'Geser transaksi ke kiri untuk menghapus.',
                                      textAlign: TextAlign.center,
                                      style: Lx.metadata),
                                ),
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

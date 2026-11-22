import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../finance/finance_data.dart' show rp, dateLabel;
import '../finance/finance_widgets.dart';
import 'budget_data.dart';
import 'budget_form_screen.dart';
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

  /// Detail first (the voice note shows there), then change or delete.
  Future<void> _open(BudgetTxn t) async {
    final act = await showBudgetTxnDetail(context, t, _income[t.categoryId]);
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
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Semua kategori'),
              trailing: _category == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, null),
            ),
            for (final c in _categories)
              ListTile(
                title: Text(c.name),
                subtitle: Text(c.isIncome ? 'Pemasukan' : 'Pengeluaran'),
                trailing:
                    _category?.id == c.id ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, c),
              ),
          ],
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
        final inc = _income[t.categoryId];
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

  List<Widget> _rows(List<BudgetTxn> list) {
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
      final same = day != null && day == t.date;
      out.add(same ? hairline : GroupLabel(dateLabel(t.date)));
      day = t.date;
      out.add(Dismissible(
        key: ValueKey(t.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDelete(t),
        onDismissed: (_) => _load(),
        background: Container(
          color: Lx.danger,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: Lx.s16),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        child: Container(
          color: Lx.background,
          child: BudgetTxnRow(
              txn: t, isIncome: _income[t.categoryId], onTap: () => _open(t)),
        ),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final all = _txns;
    final list = _shown;
    var income = 0, expense = 0;
    for (final t in list) {
      final inc = _income[t.categoryId];
      if (inc == true) income += t.amount;
      if (inc == false) expense += t.amount;
    }
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Transaksi')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _edit,
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('Semua', _Filter.all),
                    const SizedBox(width: Lx.s8),
                    _chip('Masuk', _Filter.income),
                    const SizedBox(width: Lx.s8),
                    _chip('Keluar', _Filter.expense),
                    const SizedBox(width: Lx.s8),
                    ActionChip(
                      avatar: const Icon(Icons.filter_list_rounded, size: 18),
                      label: Text(_category?.name ?? 'Kategori'),
                      onPressed: _categories.isEmpty ? null : _pickCategory,
                    ),
                  ],
                ),
              ),
            ),
            if (all != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Lx.s16, Lx.s12, Lx.s16, Lx.s4),
                child: Row(
                  children: [
                    Text('Masuk ${rp(income)}',
                        style: Lx.metadata.copyWith(color: Lx.success)),
                    const Spacer(),
                    Text('Keluar ${rp(expense)}',
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
                  : all == null
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                                Lx.s16, 0, Lx.s16, 96),
                            children: [
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

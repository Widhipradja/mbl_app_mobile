import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../finance/finance_widgets.dart' show GroupLabel, hairline;
import 'budget_data.dart';

/// Add a category, or rename / retype [existing]. Returns the saved one.
Future<BudgetCategory?> showCategoryDialog(BuildContext context,
    {BudgetCategory? existing, bool income = false}) {
  return showDialog<BudgetCategory>(
    context: context,
    builder: (_) => _CategoryDialog(existing: existing, income: income),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.existing, required this.income});

  final BudgetCategory? existing;
  final bool income;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late bool _income = widget.existing?.isIncome ?? widget.income;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Isi nama kategori.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final old = widget.existing;
      BudgetCategory saved;
      if (old == null) {
        saved = await budgetRepo.addCategory(name, _income);
      } else {
        await budgetRepo.updateCategory(old, name: name, income: _income);
        saved = BudgetCategory(
            id: old.id, name: name, isIncome: _income, active: old.active);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      debugPrint('BudgetCategory save error: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = budgetError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Kategori baru' : 'Ubah kategori'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Nama, mis. Makan'),
          ),
          const SizedBox(height: Lx.s12),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Pengeluaran')),
              ButtonSegment(value: true, label: Text('Pemasukan')),
            ],
            selected: {_income},
            onSelectionChanged:
                _saving ? null : (s) => setState(() => _income = s.first),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Lx.s8),
              child:
                  Text(_error!, style: Lx.metadata.copyWith(color: Lx.danger)),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(
            onPressed: _saving ? null : _save, child: const Text('Simpan')),
      ],
    );
  }
}

/// Manage categories: add, rename, switch off (kept for history) or delete.
/// Deleting keeps past transactions, which carry their own category name.
class BudgetCategoriesScreen extends StatefulWidget {
  const BudgetCategoriesScreen({super.key});

  @override
  State<BudgetCategoriesScreen> createState() => _BudgetCategoriesScreenState();
}

class _BudgetCategoriesScreenState extends State<BudgetCategoriesScreen> {
  List<BudgetCategory>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await budgetRepo.categories();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      debugPrint('BudgetCategories load error: $e');
      if (mounted) setState(() => _error = budgetError(e));
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _edit([BudgetCategory? c]) async {
    final saved = await showCategoryDialog(context, existing: c);
    if (saved != null && mounted) _load();
  }

  Future<void> _toggle(BudgetCategory c, bool active) async {
    try {
      await budgetRepo.updateCategory(c, active: active);
      await _load();
    } catch (e) {
      debugPrint('BudgetCategories toggle error: $e');
      if (mounted) _toast(budgetError(e));
    }
  }

  Future<void> _delete(BudgetCategory c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus "${c.name}"?'),
        content: const Text(
            'Transaksi yang sudah ada tetap tersimpan dengan nama kategori ini.'),
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
    if (ok != true) return;
    try {
      await budgetRepo.deleteCategory(c.id);
      await _load();
    } catch (e) {
      debugPrint('BudgetCategories delete error: $e');
      if (mounted) _toast(budgetError(e));
    }
  }

  List<Widget> _group(String title, List<BudgetCategory> list) {
    if (list.isEmpty) return const [];
    return [
      GroupLabel(title),
      for (var i = 0; i < list.length; i++) ...[
        if (i > 0) hairline,
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(list[i].name,
              style: Lx.cardHeading
                  .copyWith(color: list[i].active ? Lx.text : Lx.textMuted)),
          subtitle:
              list[i].active ? null : Text('Nonaktif', style: Lx.metadata),
          onTap: () => _edit(list[i]),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: list[i].active,
                onChanged: (v) => _toggle(list[i], v),
              ),
              IconButton(
                tooltip: 'Hapus',
                onPressed: () => _delete(list[i]),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Kategori')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _edit,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Kategori'),
        ),
        body: _error != null
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
            : items == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, 96),
                      children: [
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 64),
                            child: Center(
                                child: Text('Belum ada kategori.',
                                    style: Lx.body)),
                          ),
                        ..._group('Pengeluaran',
                            items.where((c) => !c.isIncome).toList()),
                        ..._group('Pemasukan',
                            items.where((c) => c.isIncome).toList()),
                      ],
                    ),
                  ),
      ),
    );
  }
}

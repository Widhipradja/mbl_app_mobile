import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart';
import 'budget_data.dart';

const _expenseIdeas = [
  'Makan', 'Transportasi', 'Belanja', 'Tagihan', 'Pulsa & Internet', //
  'Kesehatan', 'Pendidikan', 'Sedekah', 'Hiburan',
];
const _incomeIdeas = ['Gaji', 'Bonus', 'Usaha', 'Hadiah', 'Kiriman', 'Investasi'];

/// Add a category, or rename / retype [existing]. Returns the saved one.
/// [taken] are names already in use, left out of the suggestions.
Future<BudgetCategory?> showCategoryDialog(BuildContext context,
    {BudgetCategory? existing,
    bool income = false,
    Set<String> taken = const {}}) {
  return showModalBottomSheet<BudgetCategory>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Theme(
      data: Lx.theme,
      child: _CategorySheet(existing: existing, income: income, taken: taken),
    ),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet(
      {this.existing, required this.income, required this.taken});

  final BudgetCategory? existing;
  final bool income;
  final Set<String> taken;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late bool _income = widget.existing?.isIncome ?? widget.income;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

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
    final name = _name.text.trim();
    final taken = widget.taken.map((t) => t.toLowerCase()).toSet();
    final ideas = (_income ? _incomeIdeas : _expenseIdeas)
        .where((i) => !taken.contains(i.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Lx.s20, 0, Lx.s20, Lx.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_editing ? 'Ubah kategori' : 'Kategori baru',
                  style: Lx.sectionHeading),
              const SizedBox(height: 2),
              Text(
                  'Kategori mengelompokkan transaksi, misalnya Makan atau '
                  'Gaji, supaya laporan mudah dibaca.',
                  style: Lx.metadata),
              const SizedBox(height: Lx.s16),
              Text('Jenis', style: Lx.cardHeading),
              const SizedBox(height: Lx.s8),
              FlowTypeToggle(
                income: _income,
                expenseLabel: 'Uang keluar',
                incomeLabel: 'Uang masuk',
                onChanged: _saving ? null : (v) => setState(() => _income = v),
              ),
              const SizedBox(height: Lx.s16),
              Text('Nama', style: Lx.cardHeading),
              const SizedBox(height: Lx.s8),
              TextField(
                controller: _name,
                autofocus: !_editing,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  hintText: _income ? 'Mis. Gaji' : 'Mis. Makan',
                  counterText: '',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CategoryAvatar(name, income: _income, size: 32),
                  ),
                ),
              ),
              if (!_editing && ideas.isNotEmpty) ...[
                const SizedBox(height: Lx.s12),
                Text('Saran', style: Lx.metadata),
                const SizedBox(height: 6),
                Wrap(
                  spacing: Lx.s8,
                  runSpacing: Lx.s8,
                  children: [
                    for (final i in ideas)
                      ActionChip(
                        avatar: Icon(categoryLook(i, income: _income).icon,
                            size: 16,
                            color: categoryLook(i, income: _income).color),
                        label: Text(i),
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                  _name.text = i;
                                  _error = null;
                                }),
                      ),
                  ],
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: Lx.s12),
                  child: Text(_error!,
                      style: Lx.metadata.copyWith(color: Lx.danger)),
                ),
              const SizedBox(height: Lx.s20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_editing ? 'Simpan Perubahan' : 'Buat Kategori'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Manage categories by type: add, rename, switch off (kept for history) or
/// delete. Deleting keeps past transactions, which carry their own name.
class BudgetCategoriesScreen extends StatefulWidget {
  const BudgetCategoriesScreen({super.key});

  @override
  State<BudgetCategoriesScreen> createState() => _BudgetCategoriesScreenState();
}

class _BudgetCategoriesScreenState extends State<BudgetCategoriesScreen> {
  List<BudgetCategory>? _items;
  bool _income = false;
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
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _items = list);
    } catch (e) {
      debugPrint('BudgetCategories load error: $e');
      if (mounted) setState(() => _error = budgetError(e));
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _edit([BudgetCategory? c]) async {
    final saved = await showCategoryDialog(context,
        existing: c,
        income: _income,
        taken: {for (final i in _items ?? const <BudgetCategory>[]) i.name});
    if (saved == null || !mounted) return;
    // Show the tab the category ended up in.
    setState(() => _income = saved.isIncome);
    _load();
  }

  Future<void> _toggle(BudgetCategory c, bool active) async {
    try {
      await budgetRepo.updateCategory(c, active: active);
      await _load();
      if (mounted) {
        _toast(active
            ? '"${c.name}" aktif lagi.'
            : '"${c.name}" dinonaktifkan. Riwayatnya tetap ada.');
      }
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
            'Transaksi yang sudah ada tetap tersimpan dengan nama kategori '
            'ini. Kalau hanya ingin menyembunyikannya dari form, pilih '
            'Nonaktifkan.'),
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

  Widget _row(BudgetCategory c) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Lx.s4),
        leading: CategoryAvatar(c.name, income: c.isIncome, muted: !c.active),
        title: Text(c.name,
            style: Lx.cardHeading
                .copyWith(color: c.active ? Lx.text : Lx.textMuted)),
        subtitle: c.active
            ? null
            : Text('Tidak muncul di form', style: Lx.metadata),
        onTap: () => _edit(c),
        trailing: PopupMenuButton<String>(
          tooltip: 'Pilihan',
          icon: const Icon(Icons.more_vert_rounded, color: Lx.textSecondary),
          onSelected: (v) {
            switch (v) {
              case 'edit':
                _edit(c);
              case 'off':
                _toggle(c, false);
              case 'on':
                _toggle(c, true);
              case 'delete':
                _delete(c);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Ubah'),
                    contentPadding: EdgeInsets.zero)),
            PopupMenuItem(
                value: c.active ? 'off' : 'on',
                child: ListTile(
                    leading: Icon(c.active
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    title: Text(c.active ? 'Nonaktifkan' : 'Aktifkan'),
                    contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Lx.danger),
                    title: Text('Hapus', style: TextStyle(color: Lx.danger)),
                    contentPadding: EdgeInsets.zero)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final ofType = (items ?? const <BudgetCategory>[])
        .where((c) => c.isIncome == _income)
        .toList();
    final active = ofType.where((c) => c.active).toList();
    final inactive = ofType.where((c) => !c.active).toList();
    final word = _income ? 'pemasukan' : 'pengeluaran';

    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Kategori')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _edit,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Kategori baru'),
        ),
        body: _error != null
            ? Center(child: RetryState(_error!, onRetry: _load))
            : items == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, 96),
                      children: [
                        FlowTypeToggle(
                          income: _income,
                          onChanged: (v) => setState(() => _income = v),
                        ),
                        const SizedBox(height: Lx.s16),
                        if (active.isEmpty && inactive.isEmpty)
                          SectionCard(
                            child: EmptyState(
                              icon: Icons.category_rounded,
                              text: 'Belum ada kategori $word.',
                              action: 'Buat kategori',
                              onAction: _edit,
                            ),
                          ),
                        if (active.isNotEmpty)
                          SectionCard(
                            title: 'Aktif',
                            subtitle:
                                '${active.length} kategori · ketuk untuk mengubah',
                            padding: const EdgeInsets.fromLTRB(
                                Lx.s12, Lx.s16, Lx.s4, Lx.s8),
                            child: Column(
                                children: [for (final c in active) _row(c)]),
                          ),
                        if (inactive.isNotEmpty)
                          SectionCard(
                            title: 'Nonaktif',
                            subtitle:
                                'Disembunyikan dari form, riwayatnya tetap ada',
                            padding: const EdgeInsets.fromLTRB(
                                Lx.s12, Lx.s16, Lx.s4, Lx.s8),
                            child: Column(
                                children: [for (final c in inactive) _row(c)]),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

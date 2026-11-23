import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/launcher_tokens.dart';
import '../finance/finance_data.dart'
    show RupiahInputFormatter, dateLabel, thousands;
import 'budget_categories_screen.dart';
import 'budget_data.dart';
import 'budget_widgets.dart';

/// Add or edit a personal transaction. Income or expense comes from the
/// category's type, so the category is required. Pops `true` once saved or
/// deleted.
class BudgetFormScreen extends StatefulWidget {
  const BudgetFormScreen({super.key, this.txn, this.initialIncome = false});

  final BudgetTxn? txn;
  final bool initialIncome;

  @override
  State<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends State<BudgetFormScreen> {
  late final _amount = TextEditingController(
      text: widget.txn == null ? '' : thousands(widget.txn!.amount));
  late final _description =
      TextEditingController(text: widget.txn?.description ?? '');
  late bool _income = widget.initialIncome;
  late DateTime _date = widget.txn?.date ?? DateTime.now();
  List<BudgetCategory> _categories = const [];
  String? _categoryId;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _error;

  bool get _editing => widget.txn != null;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.txn?.categoryId;
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  int get _value =>
      int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await budgetRepo.categories();
      if (!mounted) return;
      setState(() {
        _categories = list;
        final current = list.where((c) => c.id == _categoryId);
        if (current.isNotEmpty) {
          _income = current.first.isIncome;
        } else {
          // The category is gone (or none): the user picks again.
          _categoryId = null;
        }
      });
    } catch (e) {
      debugPrint('BudgetForm categories error: $e');
      if (mounted) setState(() => _loadError = budgetError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<BudgetCategory> get _shown => _categories
      .where((c) => c.isIncome == _income && (c.active || c.id == _categoryId))
      .toList();

  Future<void> _addCategory() async {
    final c = await showCategoryDialog(context,
        income: _income, taken: {for (final c in _categories) c.name});
    if (c == null || !mounted) return;
    setState(() {
      _categories = [..._categories, c];
      _categoryId = c.id;
      _income = c.isIncome;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 31)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final categoryId = _categoryId;
    if (_value <= 0) {
      setState(() => _error = 'Isi nominal lebih dari Rp 0.');
      return;
    }
    if (categoryId == null) {
      setState(() => _error = 'Pilih kategori.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final desc = _description.text.trim();
      if (_editing) {
        await budgetRepo.updateTransaction(widget.txn!.id,
            amount: _value,
            categoryId: categoryId,
            description: desc,
            date: _date,
            source: widget.txn!.source);
      } else {
        await budgetRepo.addTransaction(
            amount: _value,
            categoryId: categoryId,
            description: desc,
            date: _date);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('BudgetForm save error: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = budgetError(e);
        });
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Transaksi ini akan dihapus dari dompet Anda.'),
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await budgetRepo.deleteTransaction(widget.txn!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('BudgetForm delete error: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = budgetError(e);
        });
      }
    }
  }

  Widget _label(String t, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: Lx.s20, bottom: Lx.s8),
        child: Row(
          children: [
            Expanded(child: Text(t, style: Lx.cardHeading)),
            if (trailing != null) trailing,
          ],
        ),
      );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _amountCard(Color color) => Container(
        margin: const EdgeInsets.only(top: Lx.s16),
        padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
        decoration: Lx.card(),
        child: Column(
          children: [
            Text(_income ? 'Uang masuk' : 'Uang keluar', style: Lx.metadata),
            TextField(
              controller: _amount,
              enabled: !_saving,
              autofocus: !_editing,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
              onChanged: (_) => setState(() => _error = null),
              style: Lx.userName.copyWith(
                  fontSize: 32, color: color, fontFeatures: tabular),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: Lx.userName.copyWith(
                    fontSize: 32, color: Lx.textMuted.withOpacity(0.6)),
                prefixText: 'Rp ',
                prefixStyle: Lx.sectionHeading.copyWith(color: Lx.textMuted),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ],
        ),
      );

  Widget _categoryGrid() {
    final shown = _shown;
    Widget tile(
        {required Widget icon,
        required String label,
        required bool selected,
        required VoidCallback? onTap}) {
      final color = _income ? Lx.success : Lx.primary;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Lx.rButton),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: Lx.s8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.08) : Lx.surface,
            borderRadius: BorderRadius.circular(Lx.rButton),
            border: Border.all(
                color: selected ? color : Lx.border, width: selected ? 2 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Lx.metadata.copyWith(
                      color: selected ? Lx.text : Lx.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Lx.s8,
      crossAxisSpacing: Lx.s8,
      childAspectRatio: 0.82,
      children: [
        for (final c in shown)
          tile(
            icon: CategoryAvatar(c.name, income: c.isIncome, size: 36),
            label: c.name,
            selected: _categoryId == c.id,
            onTap: _saving
                ? null
                : () => setState(() {
                      _categoryId = c.id;
                      _error = null;
                    }),
          ),
        tile(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Lx.launcherBorder),
            ),
            child: const Icon(Icons.add_rounded, color: Lx.primary, size: 20),
          ),
          label: 'Baru',
          selected: false,
          onTap: _saving ? null : _addCategory,
        ),
      ],
    );
  }

  Widget _dateChoices() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final isToday = _sameDay(_date, now);
    final isYesterday = _sameDay(_date, yesterday);
    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: _saving ? null : (_) => onTap(),
        );
    return Wrap(
      spacing: Lx.s8,
      runSpacing: Lx.s8,
      children: [
        chip('Hari ini', isToday, () => setState(() => _date = now)),
        chip('Kemarin', isYesterday, () => setState(() => _date = yesterday)),
        ActionChip(
          avatar: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(isToday || isYesterday ? 'Pilih tanggal' : dateLabel(_date)),
          side: isToday || isYesterday
              ? null
              : const BorderSide(color: Lx.primary, width: 1.5),
          onPressed: _saving ? null : _pickDate,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _income ? Lx.success : Lx.text;
    final accent = _income ? Lx.success : Lx.primary;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Ubah Transaksi' : 'Catat Transaksi'),
          actions: [
            if (_editing)
              IconButton(
                tooltip: 'Hapus',
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: _loadError != null
            ? BudgetRetry(_loadError!, onRetry: _load)
            : ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s24),
                children: [
                  BudgetTypeToggle(
                    income: _income,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() {
                              if (v == _income) return;
                              _income = v;
                              _categoryId = null;
                            }),
                  ),
                  _amountCard(color),
                  _label('Kategori',
                      trailing: _categoryId == null
                          ? Text('Pilih satu',
                              style: Lx.metadata.copyWith(color: Lx.textMuted))
                          : null),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(Lx.s12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    if (_shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Lx.s8),
                        child: Text(
                            'Belum ada kategori ${_income ? 'pemasukan' : 'pengeluaran'}. '
                            'Buat satu dengan tombol Baru.',
                            style: Lx.body),
                      ),
                    _categoryGrid(),
                  ],
                  _label('Tanggal'),
                  _dateChoices(),
                  _label('Keterangan',
                      trailing: Text('Opsional',
                          style: Lx.metadata.copyWith(color: Lx.textMuted))),
                  TextField(
                    controller: _description,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(120)],
                    decoration: InputDecoration(
                      hintText: _income
                          ? 'Mis. gaji November'
                          : 'Mis. makan siang di warung',
                      prefixIcon: const Icon(Icons.notes_rounded,
                          color: Lx.textMuted),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: Material(
          color: Lx.surface,
          child: DecoratedBox(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Lx.border))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Lx.s16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Lx.s8),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 16, color: Lx.danger),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(_error!,
                                  style:
                                      Lx.metadata.copyWith(color: Lx.danger)),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _saving || _loading ? null : _save,
                        style: FilledButton.styleFrom(backgroundColor: accent),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_editing
                                ? 'Simpan Perubahan'
                                : _income
                                    ? 'Simpan Pemasukan'
                                    : 'Simpan Pengeluaran'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

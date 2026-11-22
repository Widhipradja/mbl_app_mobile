import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/launcher_tokens.dart';
import '../finance/finance_data.dart'
    show RupiahInputFormatter, dateLabel, thousands;
import '../finance/finance_widgets.dart' show hairline;
import 'budget_categories_screen.dart';
import 'budget_data.dart';

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
    final c = await showCategoryDialog(context, income: _income);
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
            date: _date);
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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: Lx.s20, bottom: Lx.s8),
        child: Text(t, style: Lx.cardHeading),
      );

  @override
  Widget build(BuildContext context) {
    final color = _income ? Lx.success : Lx.danger;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Ubah Transaksi' : 'Transaksi Baru'),
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
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, style: Lx.body),
                    TextButton(
                        onPressed: _load, child: const Text('Coba lagi')),
                  ],
                ),
              )
            : ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s24),
                children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Pengeluaran')),
                      ButtonSegment(value: true, label: Text('Pemasukan')),
                    ],
                    selected: {_income},
                    onSelectionChanged: _saving
                        ? null
                        : (s) => setState(() {
                              _income = s.first;
                              _categoryId = null;
                            }),
                  ),
                  const SizedBox(height: Lx.s16),
                  Text('Nominal',
                      style: Lx.metadata, textAlign: TextAlign.center),
                  TextField(
                    controller: _amount,
                    enabled: !_saving,
                    autofocus: !_editing,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [RupiahInputFormatter()],
                    onChanged: (_) => setState(() => _error = null),
                    style: Lx.greeting.copyWith(color: color),
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixText: 'Rp ',
                      prefixStyle: Lx.greeting.copyWith(color: Lx.textMuted),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                  hairline,
                  _label('Kategori'),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(Lx.s12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Wrap(
                      spacing: Lx.s8,
                      runSpacing: Lx.s8,
                      children: [
                        for (final c in _shown)
                          ChoiceChip(
                            label: Text(c.name),
                            selected: _categoryId == c.id,
                            showCheckmark: false,
                            onSelected: _saving
                                ? null
                                : (_) => setState(() {
                                      _categoryId = c.id;
                                      _error = null;
                                    }),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Kategori'),
                          onPressed: _saving ? null : _addCategory,
                        ),
                      ],
                    ),
                  _label('Tanggal'),
                  InkWell(
                    onTap: _saving ? null : _pickDate,
                    borderRadius: BorderRadius.circular(Lx.rButton),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: Lx.s12),
                      decoration: BoxDecoration(
                        color: Lx.surface,
                        borderRadius: BorderRadius.circular(Lx.rButton),
                        border: Border.all(color: Lx.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(dateLabel(_date), style: Lx.body)),
                          const Icon(Icons.calendar_today_outlined,
                              size: 18, color: Lx.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  _label('Keterangan (opsional)'),
                  TextField(
                    controller: _description,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(120)],
                    decoration:
                        const InputDecoration(hintText: 'Mis. beli kopi'),
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
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(_error!,
                              style: Lx.metadata.copyWith(color: Lx.danger)),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _saving || _loading ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_editing ? 'Simpan Perubahan' : 'Simpan'),
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

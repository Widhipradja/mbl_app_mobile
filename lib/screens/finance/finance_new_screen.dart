import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/launcher_tokens.dart';
import 'finance_data.dart';
import 'finance_widgets.dart';

/// New transaction: type, amount, account (category), date and a description.
/// It is sent as a submission that waits for the treasurer (KU) to approve.
/// Pops `true` once sent.
///
/// After a voice recording the server could not read, [transcript] is sent
/// along and the [candidates] accounts are listed first.
class FinanceNewScreen extends StatefulWidget {
  const FinanceNewScreen({
    super.key,
    this.initialIncome = false,
    this.transcript = '',
    this.candidates = const [],
  });

  final bool initialIncome;
  final String transcript;
  final List<String> candidates;

  @override
  State<FinanceNewScreen> createState() => _FinanceNewScreenState();
}

class _FinanceNewScreenState extends State<FinanceNewScreen> {
  final _amount = TextEditingController();
  final _title = TextEditingController();
  late bool _income = widget.initialIncome;
  List<FinanceAccount> _accounts = const [];
  FinanceAccount? _account;
  bool _loadingAccounts = true;
  String? _accountsError;

  /// One key per form, so a retry after a timeout cannot book it twice.
  final _key = 'app-${DateTime.now().microsecondsSinceEpoch}';
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  int get _value =>
      int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  Future<void> _loadCategories() async {
    setState(() {
      _loadingAccounts = true;
      _accountsError = null;
    });
    try {
      final list = await financeRepo.accounts();
      if (mounted) setState(() => _accounts = list);
    } catch (e) {
      debugPrint('FinanceNew accounts error: $e');
      if (mounted) setState(() => _accountsError = financeError(e));
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  /// Accounts of the chosen type, the voice candidates first.
  List<FinanceAccount> get _shown {
    final c = widget.candidates.map((e) => e.toLowerCase()).toSet();
    final list = _accounts.where((a) => a.isIncome == _income).toList();
    int rank(FinanceAccount a) => c.contains(a.name.toLowerCase()) ? 0 : 1;
    return [...list]..sort((a, b) => rank(a).compareTo(rank(b)));
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
    if (_value <= 0) {
      setState(() => _error = 'Isi nominal lebih dari Rp 0.');
      return;
    }
    final account = _account;
    if (account == null) {
      setState(() => _error = 'Pilih kategori.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await financeRepo.submit(
        idempotencyKey: _key,
        account: account,
        amount: _value,
        description:
            _title.text.trim().isEmpty ? account.name : _title.text.trim(),
        date: _date,
        transcript: widget.transcript,
      );
      messenger.showSnackBar(const SnackBar(
          content: Text('Terkirim. Menunggu persetujuan bendahara.')));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('FinanceNew save error: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = financeError(e);
        });
      }
    }
  }

  Widget _typeSwitch() => SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Pengeluaran')),
          ButtonSegment(value: true, label: Text('Pemasukan')),
        ],
        selected: {_income},
        onSelectionChanged: _saving
            ? null
            : (s) {
                setState(() {
                  _income = s.first;
                  _account = null;
                });
              },
      );

  Widget _amountField() {
    final color = _income ? Lx.success : Lx.danger;
    return Column(
      children: [
        Text('Nominal', style: Lx.metadata),
        TextField(
          controller: _amount,
          enabled: !_saving,
          autofocus: true,
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
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: Lx.s20, bottom: Lx.s8),
        child: Text(t, style: Lx.cardHeading),
      );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Transaksi Baru')),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s24),
          children: [
            if (widget.transcript.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Lx.s12),
                margin: const EdgeInsets.only(bottom: Lx.s12),
                decoration: BoxDecoration(
                  color: Lx.primaryLight,
                  borderRadius: BorderRadius.circular(Lx.rButton),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yang terdengar', style: Lx.metadata),
                    Text('"${widget.transcript}"', style: Lx.body),
                  ],
                ),
              ),
            ],
            _typeSwitch(),
            const SizedBox(height: Lx.s16),
            _amountField(),
            hairline,
            _label('Kategori'),
            if (_loadingAccounts)
              const Padding(
                padding: EdgeInsets.all(Lx.s12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_accountsError != null)
              Row(
                children: [
                  Expanded(
                      child: Text(_accountsError!,
                          style: Lx.metadata.copyWith(color: Lx.danger))),
                  TextButton(
                      onPressed: _loadCategories,
                      child: const Text('Coba lagi')),
                ],
              )
            else
              Wrap(
                spacing: Lx.s8,
                runSpacing: Lx.s8,
                children: [
                  for (final a in _shown)
                    ChoiceChip(
                      label: Text(a.name),
                      selected: _account?.id == a.id,
                      showCheckmark: false,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() {
                                _account = a;
                                _error = null;
                              }),
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
                    Expanded(child: Text(dateLabel(_date), style: Lx.body)),
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: Lx.textSecondary),
                  ],
                ),
              ),
            ),
            _label('Keterangan (opsional)'),
            TextField(
              controller: _title,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              decoration:
                  const InputDecoration(hintText: 'Mis. Listrik masjid'),
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
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Simpan Transaksi'),
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

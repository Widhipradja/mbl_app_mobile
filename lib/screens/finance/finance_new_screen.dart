import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/launcher_tokens.dart';
import '../../widgets/app_ui.dart';
import 'finance_data.dart';

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

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _label(String t, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: Lx.s20, bottom: Lx.s8),
        child: Row(
          children: [
            Expanded(child: Text(t, style: Lx.cardHeading)),
            if (trailing != null) trailing,
          ],
        ),
      );

  Widget _amountCard() => Container(
        margin: const EdgeInsets.only(top: Lx.s16),
        padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
        decoration: Lx.card(),
        child: Column(
          children: [
            Text(_income ? 'Uang masuk kas' : 'Uang keluar kas',
                style: Lx.metadata),
            TextField(
              controller: _amount,
              enabled: !_saving,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
              onChanged: (_) => setState(() => _error = null),
              style: Lx.userName.copyWith(
                  fontSize: 32,
                  color: _income ? Lx.success : Lx.text,
                  fontFeatures: tabular),
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

  Widget _accountGrid() {
    final candidates = widget.candidates.map((e) => e.toLowerCase()).toSet();
    final color = _income ? Lx.success : Lx.primary;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Lx.s8,
      crossAxisSpacing: Lx.s8,
      childAspectRatio: 0.78,
      children: [
        for (final a in _shown)
          Builder(builder: (_) {
            final selected = _account?.id == a.id;
            final suggested = candidates.contains(a.name.toLowerCase());
            return InkWell(
              onTap: _saving
                  ? null
                  : () => setState(() {
                        _account = a;
                        _error = null;
                      }),
              borderRadius: BorderRadius.circular(Lx.rButton),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(vertical: Lx.s8, horizontal: 4),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.08) : Lx.surface,
                  borderRadius: BorderRadius.circular(Lx.rButton),
                  border: Border.all(
                      color: selected
                          ? color
                          : suggested
                              ? Lx.launcherBorder
                              : Lx.border,
                      width: selected ? 2 : 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CategoryAvatar(a.name, income: a.isIncome, size: 36),
                    const SizedBox(height: 6),
                    Text(a.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Lx.metadata.copyWith(
                            color: selected ? Lx.text : Lx.textSecondary,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500)),
                    if (suggested)
                      Text('Saran',
                          style: Lx.metadata.copyWith(
                              fontSize: 10,
                              color: Lx.primary,
                              fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }),
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
          label: Text(
              isToday || isYesterday ? 'Pilih tanggal' : dateLabel(_date)),
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
    final accent = _income ? Lx.success : Lx.primary;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Catat Transaksi Kas')),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(Lx.s16, 0, Lx.s16, Lx.s24),
          children: [
            if (widget.transcript.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Lx.s12),
                margin: const EdgeInsets.only(bottom: Lx.s12),
                decoration: BoxDecoration(
                  color: Lx.primaryLight,
                  borderRadius: BorderRadius.circular(Lx.rButton),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.mic_rounded, size: 18, color: Lx.primary),
                    const SizedBox(width: Lx.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Yang terdengar', style: Lx.metadata),
                          Text('"${widget.transcript}"',
                              style: Lx.body.copyWith(color: Lx.text)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            FlowTypeToggle(
              income: _income,
              onChanged: _saving
                  ? null
                  : (v) => setState(() {
                        if (v == _income) return;
                        _income = v;
                        _account = null;
                      }),
            ),
            _amountCard(),
            _label('Kategori',
                trailing: _account == null
                    ? Text('Pilih satu',
                        style: Lx.metadata.copyWith(color: Lx.textMuted))
                    : null),
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
            else if (_shown.isEmpty)
              Text(
                  'Belum ada kategori ${_income ? 'pemasukan' : 'pengeluaran'} '
                  'kas. Minta bendahara menambahkannya.',
                  style: Lx.body)
            else
              _accountGrid(),
            _label('Tanggal'),
            _dateChoices(),
            _label('Keterangan',
                trailing: Text('Opsional',
                    style: Lx.metadata.copyWith(color: Lx.textMuted))),
            TextField(
              controller: _title,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              decoration: const InputDecoration(
                hintText: 'Mis. Listrik masjid',
                prefixIcon: Icon(Icons.notes_rounded, color: Lx.textMuted),
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
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: Lx.s8),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 14, color: Lx.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                  'Masuk saldo setelah disetujui bendahara.',
                                  style: Lx.metadata),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(backgroundColor: accent),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Kirim untuk Disetujui'),
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

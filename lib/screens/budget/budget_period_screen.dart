import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import 'budget_data.dart';

/// Which day of the month a budget period starts, for people paid on the 25th
/// (period 25 - 24) as well as on the 1st (1 - 31). Saved on the server, so it
/// is the same on every device; it applies to all periods, past ones too.
/// Pops `true` when the day was saved.
class BudgetPeriodScreen extends StatefulWidget {
  const BudgetPeriodScreen({super.key});

  @override
  State<BudgetPeriodScreen> createState() => _BudgetPeriodScreenState();
}

class _BudgetPeriodScreenState extends State<BudgetPeriodScreen> {
  late final int _orig = budgetRepo.startDay;
  late int _day = _orig;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_day == _orig) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await budgetRepo.setPeriodStartDay(_day);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Periode anggaran diperbarui.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('BudgetPeriodScreen save error: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = budgetError(e);
        });
      }
    }
  }

  String get _explain => _day == 1
      ? 'Periode dimulai tanggal 1 dan berakhir di akhir bulan.'
      : 'Periode dimulai tanggal $_day dan berakhir tanggal ${_day - 1} '
          'bulan berikutnya. Namanya mengikuti bulan tempat periode berakhir.';

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Periode Anggaran')),
        body: ListView(
          padding: const EdgeInsets.all(Lx.s16),
          children: [
            Container(
              padding: const EdgeInsets.all(Lx.s16),
              decoration: Lx.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Periode dimulai tanggal', style: Lx.cardHeading),
                  const SizedBox(height: Lx.s4),
                  Text(
                      'Pilih tanggal gajian Anda. Pemasukan, pengeluaran, '
                      'anggaran, dan laporan dihitung per periode.',
                      style: Lx.metadata),
                  const SizedBox(height: Lx.s12),
                  Wrap(
                    spacing: Lx.s8,
                    runSpacing: Lx.s8,
                    children: [
                      for (var d = 1; d <= 28; d++)
                        ChoiceChip(
                          label: Text('$d'),
                          selected: _day == d,
                          showCheckmark: false,
                          selectedColor: Lx.primaryLight,
                          labelStyle: Lx.button.copyWith(
                              color: _day == d ? Lx.primary : Lx.textSecondary),
                          side: BorderSide(
                              color: _day == d ? Lx.primary : Lx.border),
                          onSelected:
                              _saving ? null : (_) => setState(() => _day = d),
                        ),
                    ],
                  ),
                  const SizedBox(height: Lx.s12),
                  Text(_explain, style: Lx.body.copyWith(color: Lx.text)),
                  const SizedBox(height: Lx.s4),
                  Text('Gajian tanggal 29-31? Pilih 28 atau 1.',
                      style: Lx.metadata),
                ],
              ),
            ),
            const SizedBox(height: Lx.s12),
            Container(
              padding: const EdgeInsets.all(Lx.s12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(Lx.rButton),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: Color(0xFFEA580C)),
                  const SizedBox(width: Lx.s8),
                  Expanded(
                    child: Text(
                        'Berlaku juga untuk periode yang sudah lewat, jadi '
                        'angka laporan lama ikut dihitung ulang. Transaksi '
                        'Anda tidak berubah. Anggaran yang sudah diatur '
                        'tetap di periodenya masing-masing.',
                        style: Lx.metadata.copyWith(
                            color: const Color(0xFF9A3412), height: 1.4)),
                  ),
                ],
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
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: Lx.s12),
                        padding: const EdgeInsets.all(Lx.s12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(Lx.rButton),
                        ),
                        child: Text(_error!,
                            style: Lx.metadata.copyWith(color: Lx.danger)),
                      ),
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
                            : const Text('Simpan'),
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

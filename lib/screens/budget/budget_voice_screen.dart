import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../config/launcher_tokens.dart';
import '../finance/finance_data.dart' show rp, RupiahInputFormatter;
import 'budget_data.dart';
import 'budget_form_screen.dart';

enum _Step { idle, recording, sending, result, pick }

/// Record a personal transaction by voice. On 200 the server has already
/// created it (the card offers "Selesai" or "Ubah"); on 422 the amount was
/// read but not the category, so the user picks one from the candidates and
/// nothing needs to be recorded again. Pops `true` once something was saved.
class BudgetVoiceScreen extends StatefulWidget {
  const BudgetVoiceScreen({super.key});

  /// The server takes at most 10 MiB; AAC is about 1 MB a minute.
  static const maxSeconds = 120;

  @override
  State<BudgetVoiceScreen> createState() => _BudgetVoiceScreenState();
}

class _BudgetVoiceScreenState extends State<BudgetVoiceScreen> {
  final _recorder = AudioRecorder();
  _Step _step = _Step.idle;
  int _seconds = 0;
  Timer? _timer;
  String? _path;
  String? _error;
  bool _saving = false;
  BudgetTxn? _result;
  bool? _resultIncome;
  BudgetVoiceUnreadable? _unread;
  List<BudgetCategory> _choices = const [];
  final _amount = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error =
            'Izin mikrofon ditolak. Aktifkan di pengaturan perangkat.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/budget-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
        path: path,
      );
      _path = path;
      setState(() {
        _step = _Step.recording;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= BudgetVoiceScreen.maxSeconds) _stop();
      });
    } catch (e) {
      debugPrint('BudgetVoice start error: $e');
      setState(() => _error = 'Rekaman tidak bisa dimulai.');
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await _recorder.cancel();
    if (mounted) setState(() => _step = _Step.idle);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder.stop() ?? _path;
    if (path == null || !mounted) return;
    if (_seconds < 1) {
      setState(() {
        _step = _Step.idle;
        _error = 'Rekaman terlalu singkat. Coba lagi.';
      });
      return;
    }
    await _send(path);
  }

  Future<void> _send(String path) async {
    setState(() {
      _step = _Step.sending;
      _error = null;
    });
    try {
      final bytes = await File(path).readAsBytes();
      final txn = await budgetRepo.voice(bytes, 'transaksi.m4a');
      final cats = await budgetRepo.categories().catchError((Object e) {
        debugPrint('BudgetVoice categories error: $e');
        return <BudgetCategory>[];
      });
      if (!mounted) return;
      final match = cats.where((c) => c.id == txn.categoryId);
      setState(() {
        _result = txn;
        _resultIncome = match.isEmpty ? null : match.first.isIncome;
        _step = _Step.result;
      });
    } on BudgetVoiceUnreadable catch (e) {
      final cats = await budgetRepo.categories().catchError((Object e) {
        debugPrint('BudgetVoice categories error: $e');
        return <BudgetCategory>[];
      });
      if (!mounted) return;
      final active =
          cats.where((c) => c.active && c.isIncome == e.isIncome).toList();
      final names = e.candidates.map((c) => c.toLowerCase()).toSet();
      final matched =
          active.where((c) => names.contains(c.name.toLowerCase())).toList();
      setState(() {
        _unread = e;
        // The server's candidates first; when none is one of the user's own
        // categories, every category of that type.
        _choices = matched.isNotEmpty ? matched : active;
        _amount.text = e.amount > 0 ? thousandsOf(e.amount) : '';
        _step = _Step.pick;
      });
    } catch (e) {
      debugPrint('BudgetVoice send error: $e');
      if (mounted) {
        setState(() {
          _step = _Step.idle;
          _error = budgetError(e);
        });
      }
    }
  }

  static String thousandsOf(int v) => v
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

  int get _amountValue =>
      int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  Future<void> _choose(BudgetCategory c) async {
    final u = _unread;
    if (u == null) return;
    if (_amountValue <= 0) {
      setState(() => _error = 'Isi nominalnya dulu.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await budgetRepo.addTransaction(
        amount: _amountValue,
        categoryId: c.id,
        description: u.transcript,
        date: DateTime.now(),
        source: 'voice',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('BudgetVoice choose error: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = budgetError(e);
        });
      }
    }
  }

  Future<void> _editResult() async {
    final t = _result;
    if (t == null) return;
    await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => BudgetFormScreen(txn: t)));
    // Created already, edited or not: the wallet has to refresh.
    if (mounted) Navigator.of(context).pop(true);
  }

  String get _clock => '${(_seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(_seconds % 60).toString().padLeft(2, '0')}';

  Widget _mic() {
    final recording = _step == _Step.recording;
    return Column(
      children: [
        Material(
          color: recording ? Lx.danger : Lx.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: recording ? _stop : _start,
            child: SizedBox(
              width: 112,
              height: 112,
              child: Icon(recording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 52, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: Lx.s16),
        Text(recording ? _clock : 'Ketuk untuk mulai merekam',
            style: recording ? Lx.greeting : Lx.body),
        if (recording)
          TextButton(onPressed: _cancel, child: const Text('Batal')),
      ],
    );
  }

  Widget _resultCard() {
    final t = _result!;
    final inc = _resultIncome;
    final color = inc == null
        ? Lx.textSecondary
        : inc
            ? Lx.success
            : Lx.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Lx.s16),
          decoration: Lx.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  inc == null
                      ? 'Transaksi'
                      : inc
                          ? 'Pemasukan'
                          : 'Pengeluaran',
                  style: Lx.metadata),
              Text(rp(t.amount), style: Lx.greeting.copyWith(color: color)),
              const SizedBox(height: Lx.s12),
              Text(t.categoryName.isEmpty ? 'Tanpa kategori' : t.categoryName,
                  style: Lx.cardHeading.copyWith(color: Lx.secondary)),
              if (t.description.isNotEmpty) Text(t.description, style: Lx.body),
              if (t.transcript.isNotEmpty) ...[
                const SizedBox(height: Lx.s12),
                Text('Yang terdengar', style: Lx.metadata),
                Text('"${t.transcript}"', style: Lx.body),
              ],
            ],
          ),
        ),
        const SizedBox(height: Lx.s16),
        Text('Transaksi sudah tersimpan.', style: Lx.metadata),
        const SizedBox(height: Lx.s16),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Selesai'),
          ),
        ),
        const SizedBox(height: Lx.s8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: _editResult,
            child: const Text('Ubah'),
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _step = _Step.idle;
            _result = null;
          }),
          child: const Text('Rekam transaksi lain'),
        ),
      ],
    );
  }

  Widget _pickCard() {
    final u = _unread!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Lx.s12),
          decoration: BoxDecoration(
            color: Lx.primaryLight,
            borderRadius: BorderRadius.circular(Lx.rButton),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Yang terdengar', style: Lx.metadata),
              Text('"${u.transcript}"', style: Lx.body),
            ],
          ),
        ),
        const SizedBox(height: Lx.s16),
        Text('Kategorinya belum dikenali. Pilih yang sesuai:',
            style: Lx.cardHeading),
        const SizedBox(height: Lx.s12),
        Text(u.isIncome ? 'Pemasukan' : 'Pengeluaran', style: Lx.metadata),
        TextField(
          controller: _amount,
          enabled: !_saving,
          keyboardType: TextInputType.number,
          inputFormatters: [RupiahInputFormatter()],
          onChanged: (_) => setState(() => _error = null),
          style:
              Lx.greeting.copyWith(color: u.isIncome ? Lx.success : Lx.danger),
          decoration: const InputDecoration(hintText: '0', prefixText: 'Rp '),
        ),
        const SizedBox(height: Lx.s16),
        if (_choices.isEmpty)
          Text(
              'Belum ada kategori ${u.isIncome ? 'pemasukan' : 'pengeluaran'}. '
              'Tambahkan dulu di Kelola kategori.',
              style: Lx.body)
        else
          Wrap(
            spacing: Lx.s8,
            runSpacing: Lx.s8,
            children: [
              for (final c in _choices)
                ActionChip(
                  label: Text(c.name),
                  onPressed: _saving ? null : () => _choose(c),
                ),
            ],
          ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.only(top: Lx.s16),
            child: Center(child: CircularProgressIndicator()),
          ),
        TextButton(
          onPressed: _saving
              ? null
              : () => setState(() {
                    _step = _Step.idle;
                    _unread = null;
                    _error = null;
                  }),
          child: const Text('Batal'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Rekam Transaksi')),
        body: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(Lx.s16),
            children: [
              if (_step == _Step.result)
                _resultCard()
              else if (_step == _Step.pick)
                _pickCard()
              else ...[
                const SizedBox(height: Lx.s24),
                Text(
                  'Sebutkan nominal dan keperluan. Contoh: "beli kopi dua '
                  'puluh lima ribu".',
                  textAlign: TextAlign.center,
                  style: Lx.body,
                ),
                const SizedBox(height: Lx.s32),
                if (_step == _Step.sending)
                  Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: Lx.s16),
                      Text('Mengubah suara menjadi catatan…', style: Lx.body),
                    ],
                  )
                else
                  Center(child: _mic()),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: Lx.s16),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: Lx.metadata.copyWith(color: Lx.danger)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

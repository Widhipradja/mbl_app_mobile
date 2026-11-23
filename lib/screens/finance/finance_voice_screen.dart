import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../config/launcher_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_summary_provider.dart';
import 'finance_data.dart';
import 'finance_new_screen.dart';

enum _Step { idle, recording, sending, result }

/// Add a transaction by speaking: record, send, then show the pending
/// submission (KU can approve it right away). When the server cannot read the
/// recording, the manual form opens with the transcript. Pops `true` once
/// something was sent.
class FinanceVoiceScreen extends StatefulWidget {
  const FinanceVoiceScreen({super.key});

  /// The server takes at most 10 MiB; AAC is about 1 MB a minute.
  static const maxSeconds = 120;

  @override
  State<FinanceVoiceScreen> createState() => _FinanceVoiceScreenState();
}

class _FinanceVoiceScreenState extends State<FinanceVoiceScreen> {
  final _recorder = AudioRecorder();
  _Step _step = _Step.idle;
  int _seconds = 0;
  Timer? _timer;
  String? _path;
  String? _error;
  bool _approving = false;
  bool _approved = false;
  FinanceSubmission? _result;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
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
          '${dir.path}/finance-${DateTime.now().millisecondsSinceEpoch}.m4a';
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
        if (_seconds >= FinanceVoiceScreen.maxSeconds) _stop();
      });
    } catch (e) {
      debugPrint('FinanceVoice start error: $e');
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
      _path = path;
    });
    try {
      final bytes = await File(path).readAsBytes();
      final r = await financeRepo.voice(bytes, 'transaksi.m4a');
      if (!mounted) return;
      setState(() {
        _result = r;
        _step = _Step.result;
      });
    } on VoiceUnreadable catch (e) {
      if (!mounted) return;
      // Hand over to the manual form with what was heard.
      final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => FinanceNewScreen(
            transcript: e.transcript, candidates: e.candidates),
      ));
      if (!mounted) return;
      if (sent == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _step = _Step.idle;
          _error = e.message.contains('amount')
              ? 'Nominal dan kategori tidak terbaca. Rekam ulang dengan jelas.'
              : 'Kategori tidak dikenali. Rekam ulang atau isi manual.';
        });
      }
    } catch (e) {
      debugPrint('FinanceVoice send error: $e');
      if (mounted) {
        setState(() {
          _step = _Step.idle;
          _error = financeError(e);
        });
      }
    }
  }

  Future<void> _approve() async {
    final r = _result;
    if (r == null) return;
    setState(() {
      _approving = true;
      _error = null;
    });
    try {
      await financeRepo.decide(r.id, 'approve');
      if (mounted) setState(() => _approved = true);
    } catch (e) {
      debugPrint('FinanceVoice approve error: $e');
      if (mounted) setState(() => _error = financeError(e));
    } finally {
      if (mounted) setState(() => _approving = false);
    }
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

  Widget _resultCard(bool ku) {
    final r = _result!;
    final color = r.isIncome ? Lx.success : Lx.danger;
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
              Text(r.isIncome ? 'Pemasukan' : 'Pengeluaran',
                  style: Lx.metadata),
              Text(rp(r.amount), style: Lx.greeting.copyWith(color: color)),
              const SizedBox(height: Lx.s12),
              Text(r.accountName,
                  style: Lx.cardHeading.copyWith(color: Lx.secondary)),
              Text(r.description, style: Lx.body),
              if (r.transcript.isNotEmpty) ...[
                const SizedBox(height: Lx.s12),
                Text('Yang terdengar', style: Lx.metadata),
                Text('"${r.transcript}"', style: Lx.body),
              ],
            ],
          ),
        ),
        const SizedBox(height: Lx.s16),
        Text(
          _approved
              ? 'Transaksi sudah disetujui dan tercatat.'
              : 'Pengajuan ini menunggu persetujuan bendahara.',
          style: Lx.metadata,
        ),
        const SizedBox(height: Lx.s16),
        if (ku && !_approved)
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _approving ? null : _approve,
              child: _approving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Setujui sekarang'),
            ),
          ),
        const SizedBox(height: Lx.s8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Selesai'),
          ),
        ),
        TextButton(
          onPressed: _approving
              ? null
              : () => setState(() {
                    _step = _Step.idle;
                    _result = null;
                    _approved = false;
                  }),
          child: const Text('Rekam transaksi lain'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.watch<HomeSummaryProvider>().hasRole(
        'KU', context.watch<AuthProvider>().user?.roleNames ?? const []);
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Catat dengan Suara')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Lx.s16),
            children: [
              if (_step == _Step.result)
                _resultCard(ku)
              else ...[
                const SizedBox(height: Lx.s24),
                Text(
                  'Sebutkan jenis, kategori, nominal dan keterangan. '
                  'Contoh: "beli snack musyawarah lima puluh ribu".',
                  textAlign: TextAlign.center,
                  style: Lx.body,
                ),
                const SizedBox(height: Lx.s32),
                if (_step == _Step.sending)
                  Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: Lx.s16),
                      Text('Mengirim dan membaca rekaman…', style: Lx.body),
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
              if (_step == _Step.idle || _step == _Step.recording) ...[
                const SizedBox(height: Lx.s32),
                Center(
                  child: TextButton.icon(
                    onPressed: _step == _Step.recording
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const FinanceNewScreen())),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Isi manual'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/launcher_tokens.dart';
import '../../services/api_service.dart';
import '../info/donation_form_screen.dart' show DonationProof, ProofKind;
import 'ledger_widgets.dart' show monthNames;

/// One shodaqoh item of a month that the member can put an amount on.
class _DepositItem {
  _DepositItem({
    required this.code,
    required this.name,
    required this.additional,
    int? suggested,
  }) : controller = TextEditingController(
            text: suggested == null || suggested <= 0 ? '' : '$suggested');

  /// `item_snapshot_id` from GET collection.
  final String code;
  final String name;

  /// Came from `additional_items`, so it is sent back there.
  final bool additional;
  final TextEditingController controller;

  int get amount =>
      int.tryParse(controller.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
}

/// Self-service deposit of amal jariyah for one month: an amount per item the
/// server lists for that month, an optional note, then it is sent as a pending
/// entry for the treasurer (KU) to verify. Pops `true` once sent.
///
/// See docs/AMAL_JARIYAH_DEPOSIT_API.md.
class AmalDepositFormScreen extends StatefulWidget {
  const AmalDepositFormScreen({super.key, required this.month});

  /// The month being deposited for (day ignored).
  final DateTime month;

  static const maxNotes = 500;
  static const maxProofBytes = 5 * 1024 * 1024;

  @override
  State<AmalDepositFormScreen> createState() => _AmalDepositFormScreenState();
}

class _AmalDepositFormScreenState extends State<AmalDepositFormScreen> {
  final _notes = TextEditingController();
  final List<_DepositItem> _items = [];
  bool _loading = true;
  bool _sending = false;
  String? _loadError;
  String? _amountError;
  String? _sendError;
  String? _proofError;
  DonationProof? _proof;

  String get _period => '${widget.month.year}-'
      '${widget.month.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final i in _items) {
      i.controller.dispose();
    }
    super.dispose();
  }

  static String _str(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  static List<_DepositItem> _parse(dynamic raw, String key, bool additional) {
    var src = raw;
    if (src is Map && src['data'] is Map) src = src['data'];
    final list = src is Map ? src[key] : null;
    if (list is! List) return const [];
    return [
      for (final r in list.whereType<Map>())
        _DepositItem(
          code: _str(r,
              ['item_snapshot_id', 'snapshot_id', 'item_code', 'code', 'id']),
          name: _str(r, ['item_name', 'name', 'nama', 'item_code', 'code']),
          additional: additional,
          suggested: double.tryParse(
                  (r['final_amount'] ?? r['amount'] ?? '').toString())
              ?.round(),
        ),
    ];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final resp = await ApiService().getCollection(_period);
      if (!mounted) return;
      final items = [
        ..._parse(resp.data, 'allocations', false),
      ];
      for (final i in _items) {
        i.controller.dispose();
      }
      setState(() {
        _items
          ..clear()
          ..addAll(items);
      });
    } catch (e) {
      debugPrint('AmalDepositFormScreen load error: $e');
      if (mounted) setState(() => _loadError = _failure(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The status picks the text; for 400 and 409 the server's own message is
  /// in Indonesian and shown as it is.
  static String _failure(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final reason = data is Map ? data['error']?.toString().trim() ?? '' : '';
      switch (e.response?.statusCode) {
        case 413:
          return 'Ukuran bukti terlalu besar untuk server.';
        case 400:
        case 409:
          if (reason.isNotEmpty) return reason;
          return e.response?.statusCode == 409
              ? 'Bulan ini sudah diinput.'
              : 'Data ditolak server. Periksa isian Anda.';
        case 401:
          return 'Sesi Anda berakhir. Silakan masuk lagi.';
        case 403:
          return 'Anda tidak punya akses untuk menyetor.';
        case 404:
          return 'Akun Anda belum terhubung ke data jamaah.';
        case 502:
        case 503:
        case 504:
          return 'Layanan sedang tidak tersedia. Coba lagi nanti.';
      }
      if (e.response == null) {
        return 'Tidak bisa terhubung ke server. Periksa koneksi Anda.';
      }
    }
    return 'Gagal memproses. Coba lagi.';
  }

  Future<DonationProof?> _pickFromDevice() async {
    final fromGallery = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri foto'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('File (JPG, PNG atau PDF)'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (fromGallery == null) return null;
    final picked = await FilePicker.platform.pickFiles(
      type: fromGallery ? FileType.image : FileType.custom,
      allowedExtensions:
          fromGallery ? null : const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;
    return DonationProof(name: file.name, bytes: bytes);
  }

  Future<void> _pickProof() async {
    try {
      final proof = await _pickFromDevice();
      if (!mounted || proof == null) return;
      if (proof.kind == null) {
        setState(() => _proofError =
            'Bukti harus berupa JPG, PNG atau PDF. Format lain, termasuk '
                'WebP, tidak diterima.');
        return;
      }
      if (proof.bytes.length > AmalDepositFormScreen.maxProofBytes) {
        setState(() => _proofError =
            'Ukuran bukti lebih dari 5 MB. Pilih file yang lebih kecil.');
        return;
      }
      setState(() {
        _proof = proof;
        _proofError = null;
      });
    } catch (e) {
      debugPrint('AmalDepositFormScreen pick error: $e');
      if (mounted) {
        setState(() => _proofError = 'File tidak bisa dibuka. Coba lagi.');
      }
    }
  }

  Widget _proofField() {
    final proof = _proof;
    if (proof == null) {
      return Material(
        color: Lx.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Lx.rButton),
          side: BorderSide(color: _proofError != null ? Lx.danger : Lx.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _sending ? null : _pickProof,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.upload_file_outlined, size: 30, color: Lx.primary),
                  SizedBox(height: 6),
                  Text('Pilih bukti transfer', style: Lx.cardHeading),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final kb = (proof.bytes.length / 1024).ceil();
    final size = kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '$kb KB';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: Lx.card(),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: proof.kind == ProofKind.pdf
                ? Container(
                    width: 64,
                    height: 64,
                    color: const Color(0xFFFEF3F2),
                    child: const Icon(Icons.picture_as_pdf_outlined,
                        color: Lx.danger, size: 30),
                  )
                : Image.memory(
                    proof.bytes,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: Lx.background,
                      child:
                          const Icon(Icons.image_outlined, color: Lx.textMuted),
                    ),
                  ),
          ),
          const SizedBox(width: Lx.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proof.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Lx.cardHeading),
                Text(size, style: Lx.metadata),
              ],
            ),
          ),
          TextButton(
            onPressed: _sending ? null : _pickProof,
            child: const Text('Ganti'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final filled = _items.where((i) => i.amount > 0).toList();
    setState(() {
      _amountError =
          filled.isEmpty ? 'Isi minimal satu jumlah lebih dari Rp 0.' : null;
      _proofError = _proof != null ? null : 'Lampirkan bukti transfer.';
      _sendError = null;
    });
    final proof = _proof;
    if (filled.isEmpty || proof == null) return;

    Map<String, dynamic> row(_DepositItem i) =>
        {'item_snapshot_id': i.code, 'amount': i.amount};
    final notes = _notes.text.trim();
    final regular = [
      for (final i in filled.where((i) => !i.additional)) row(i)
    ];
    final extra = [for (final i in filled.where((i) => i.additional)) row(i)];
    // Each entry needs a non-empty items or additional_items: empty ones are
    // left out. Status and member fields are never sent (server forces them).
    final entry = <String, dynamic>{
      'collected_for_period': _period,
      if (regular.isNotEmpty) 'items': regular,
      if (extra.isNotEmpty) 'additional_items': extra,
      if (notes.isNotEmpty) 'notes': notes,
      'collected_at': DateTime.now().toUtc().toIso8601String(),
    };

    setState(() => _sending = true);
    try {
      await ApiService().submitCollection(_period, [entry],
          proofBytes: proof.bytes, proofName: proof.name);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('AmalDepositFormScreen submit error: $e');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendError = _failure(e);
      });
    }
  }

  InputDecoration get _decoration {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Lx.rButton),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      filled: true,
      fillColor: Lx.surface,
      border: border(Lx.border),
      enabledBorder: border(Lx.border),
      focusedBorder: border(Lx.primary, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = '${monthNames[widget.month.month - 1]} ${widget.month.year}';
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Setor Amal Jariyah')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Lx.s24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_loadError!,
                                textAlign: TextAlign.center, style: Lx.body),
                            TextButton(
                                onPressed: _load,
                                child: const Text('Coba lagi')),
                          ],
                        ),
                      ),
                    )
                  : _form(title),
        ),
      ),
    );
  }

  Widget _form(String title) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(Lx.s16),
      children: [
        Container(
          padding: const EdgeInsets.all(Lx.s12),
          decoration: BoxDecoration(
            color: Lx.primaryLight,
            borderRadius: BorderRadius.circular(Lx.rCard),
          ),
          child: Row(
            children: [
              const Icon(Icons.volunteer_activism_rounded, color: Lx.primary),
              const SizedBox(width: Lx.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Setoran untuk', style: Lx.metadata),
                    Text(title, style: Lx.cardHeading),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Lx.s16),
        if (_items.isEmpty)
          Text('Belum ada item yang bisa disetor untuk bulan ini.',
              style: Lx.body),
        for (final i in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: Lx.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.name, style: Lx.cardHeading),
                const SizedBox(height: 6),
                TextField(
                  controller: i.controller,
                  enabled: !_sending,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() => _amountError = null),
                  decoration:
                      _decoration.copyWith(prefixText: 'Rp ', hintText: '0'),
                ),
              ],
            ),
          ),
        if (_amountError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Lx.s12),
            child: Text(_amountError!,
                style: Lx.metadata.copyWith(color: Lx.danger)),
          ),
        Text('Catatan (opsional)', style: Lx.cardHeading),
        const SizedBox(height: 6),
        TextField(
          controller: _notes,
          enabled: !_sending,
          minLines: 2,
          maxLines: 3,
          maxLength: AmalDepositFormScreen.maxNotes,
          textCapitalization: TextCapitalization.sentences,
          decoration: _decoration,
        ),
        const SizedBox(height: Lx.s8),
        Text('Bukti transfer', style: Lx.cardHeading),
        const SizedBox(height: 2),
        Text('JPG, PNG atau PDF, maksimal 5 MB.', style: Lx.metadata),
        const SizedBox(height: 6),
        _proofField(),
        if (_proofError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(_proofError!,
                style: Lx.metadata.copyWith(color: Lx.danger)),
          ),
        const SizedBox(height: Lx.s12),
        Text('Setoran menunggu verifikasi bendahara sebelum tercatat.',
            style: Lx.metadata),
        const SizedBox(height: Lx.s16),
        if (_sendError != null)
          Container(
            margin: const EdgeInsets.only(bottom: Lx.s12),
            padding: const EdgeInsets.all(Lx.s12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3F2),
              borderRadius: BorderRadius.circular(Lx.rButton),
            ),
            child: Text(_sendError!,
                style: Lx.metadata.copyWith(color: Lx.danger)),
          ),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _sending || _items.isEmpty ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Kirim Setoran'),
          ),
        ),
      ],
    );
  }
}

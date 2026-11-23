import 'dart:math';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/baraka_tokens.dart';
import '../../services/api_service.dart';

/// The file a member attaches as proof of the transfer.
class DonationProof {
  const DonationProof({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  /// What the file really is, read from its first bytes, not its name: the
  /// server does the same and accepts only JPEG, PNG and PDF (WebP is
  /// refused). Null for anything else.
  ProofKind? get kind {
    bool starts(List<int> sig) {
      if (bytes.length < sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (bytes[i] != sig[i]) return false;
      }
      return true;
    }

    if (starts(const [0xFF, 0xD8, 0xFF])) return ProofKind.jpeg;
    if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return ProofKind.png;
    }
    if (starts(const [0x25, 0x50, 0x44, 0x46])) return ProofKind.pdf;
    return null;
  }
}

enum ProofKind { jpeg, png, pdf }

/// How a donation ended.
enum DonationOutcome {
  /// Accepted (202): waits for the treasurer (KU) to approve it.
  pending,

  /// The server says this attempt was already approved (409): nothing to do.
  alreadyApproved,
}

/// What the form hands back once a donation is sent: how it ended and the
/// amount, in whole rupiah as digits.
class DonationResult {
  const DonationResult(this.outcome, this.amount);

  final DonationOutcome outcome;
  final String amount;
}

/// Sends a donation and says how it ended; throws when the server refuses it
/// or cannot be reached. [idempotencyKey] is the same for a retry of the same
/// donation and new for the next one.
typedef DonationSubmit = Future<DonationOutcome> Function({
  required String campaignId,
  required String amount,
  required String paidDate,
  required String notes,
  required DonationProof proof,
  required String idempotencyKey,
});

/// A random UUID (version 4).
String newUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0F) | 0x40;
  b[8] = (b[8] & 0x3F) | 0x80;
  String h(int from, int to) => [
        for (var i = from; i < to; i++) b[i].toRadixString(16).padLeft(2, '0'),
      ].join();
  return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
}

/// Form to donate (or donate again) to one fundraising campaign: the amount
/// the date of the transfer, an optional note and the proof (JPEG, PNG or
/// PDF). Pops with a [DonationResult] once sent.
///
/// See docs/FUNDRAISING_DONATION_API.md for the request.
class DonationFormScreen extends StatefulWidget {
  const DonationFormScreen({
    super.key,
    required this.campaignId,
    required this.campaignTitle,
    this.again = false,
    this.pickProof,
    this.submit,
  });

  final String campaignId;
  final String campaignTitle;

  /// The member has given to this campaign before.
  final bool again;

  /// Default: the device's gallery or file picker. Tests pass their own.
  final Future<DonationProof?> Function()? pickProof;

  /// Default: the API. Tests pass their own.
  final DonationSubmit? submit;

  /// Largest proof accepted, in bytes.
  static const maxProofBytes = 5 * 1024 * 1024;

  /// Longest note the server accepts.
  static const maxNotes = 500;

  @override
  State<DonationFormScreen> createState() => _DonationFormScreenState();
}

class _DonationFormScreenState extends State<DonationFormScreen> {
  static const _quickAmounts = [20000, 50000, 100000, 200000, 500000];

  final _amount = TextEditingController();
  final _notes = TextEditingController();
  DateTime _paidDate = DateTime.now();
  DonationProof? _proof;
  bool _sending = false;

  /// One key per donation attempt: kept for a retry of the same donation (so
  /// the server does not take it for a second one), replaced as soon as
  /// anything the donor typed or attached changes, and new for each new form.
  String? _attemptKey;
  String? _attemptSignature;

  // Shown under the field they belong to, after a first attempt to send.
  String? _amountError;
  String? _proofError;
  String? _sendError;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// The amount typed, digits only ("150.000" → "150000").
  String get _digits => _amount.text.replaceAll(RegExp(r'\D'), '');

  static String _dotted(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write('.');
      b.write(digits[i]);
    }
    return b.toString();
  }

  void _setAmount(int value) {
    final text = _dotted('$value');
    _amount.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _amountError = null);
  }

  /// Asks where the proof comes from, then opens that picker.
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
      final proof = await (widget.pickProof ?? _pickFromDevice)();
      if (!mounted || proof == null) return;
      if (proof.kind == null) {
        setState(() => _proofError =
            'Bukti harus berupa JPG, PNG atau PDF. Format lain, termasuk '
                'WebP, tidak diterima.');
        return;
      }
      if (proof.bytes.length > DonationFormScreen.maxProofBytes) {
        setState(() => _proofError = 'Ukuran bukti lebih dari 5 MB. '
            'Pilih file yang lebih kecil.');
        return;
      }
      setState(() {
        _proof = proof;
        _proofError = null;
      });
    } catch (e) {
      debugPrint('DonationFormScreen pick error: $e');
      if (mounted) {
        setState(() => _proofError = 'File tidak bisa dibuka. Coba lagi.');
      }
    }
  }

  Future<DonationOutcome> _sendToApi({
    required String campaignId,
    required String amount,
    required String paidDate,
    required String notes,
    required DonationProof proof,
    required String idempotencyKey,
  }) async {
    final resp = await ApiService().submitFundraisingDonation(
      campaignId: campaignId,
      amount: amount,
      paidDate: paidDate,
      notes: notes,
      proofBytes: proof.bytes,
      proofName: proof.name,
      idempotencyKey: idempotencyKey,
    );
    // 202 {donation_id, status: "pending"}; any other success is treated alike.
    debugPrint('Donation sent: ${resp.data}');
    return DonationOutcome.pending;
  }

  static String _isoDate(DateTime d) => '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', //
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  String _prettyDate(DateTime d) =>
      '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidDate,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Tanggal transfer',
    );
    if (picked != null && mounted) setState(() => _paidDate = picked);
  }

  /// The status picks the text. For a 400 the server's own reason is added:
  /// it says which field it did not accept.
  static String _failure(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final reason = data is Map ? data['error']?.toString().trim() ?? '' : '';
      switch (e.response?.statusCode) {
        case 400:
        case 422:
          return reason.isEmpty
              ? 'Donasi ditolak server. Periksa data yang diisi.'
              : 'Donasi ditolak server: $reason';
        case 404:
          return 'Akun Anda belum terhubung ke data anggota, atau '
              'penggalangan dana ini sudah tidak menerima donasi.';
        case 413:
          return 'Ukuran bukti terlalu besar untuk server.';
        case 502:
        case 503:
        case 504:
          return 'Layanan sedang tidak tersedia. Coba lagi nanti.';
      }
      if (e.response == null) {
        // No answer: it may or may not have arrived. Sending the same
        // donation again is safe, because it carries the same key.
        return 'Tidak ada jawaban dari server. Periksa koneksi Anda lalu '
            'kirim lagi; donasi yang sama tidak akan tercatat dua kali.';
      }
    }
    return 'Donasi gagal dikirim. Coba lagi.';
  }

  Future<void> _submit() async {
    final amount = BigInt.tryParse(_digits) ?? BigInt.zero;
    final proof = _proof;
    setState(() {
      _amountError =
          amount > BigInt.zero ? null : 'Isi jumlah donasi lebih dari Rp 0.';
      _proofError = proof != null ? null : 'Lampirkan bukti transaksi.';
      _sendError = null;
    });
    if (_amountError != null || proof == null) return;

    final paidDate = _isoDate(_paidDate);
    final notes = _notes.text.trim();

    // The same donation again (a retry after a timeout) keeps its key; any
    // change makes it a different donation with a new one.
    final signature =
        [amount, paidDate, notes, proof.name, proof.bytes.length].join('|');
    if (_attemptKey == null || _attemptSignature != signature) {
      _attemptKey = newUuid();
      _attemptSignature = signature;
    }

    setState(() => _sending = true);
    try {
      final outcome = await (widget.submit ?? _sendToApi)(
        campaignId: widget.campaignId,
        amount: amount.toString(),
        paidDate: paidDate,
        notes: notes,
        proof: proof,
        idempotencyKey: _attemptKey!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(DonationResult(outcome, amount.toString()));
    } catch (e) {
      debugPrint('DonationFormScreen submit error: $e');
      if (!mounted) return;
      // 409: the server already approved this very attempt. Nothing is lost.
      if (e is DioException && e.response?.statusCode == 409) {
        Navigator.of(context).pop(
            DonationResult(DonationOutcome.alreadyApproved, amount.toString()));
        return;
      }
      setState(() {
        _sending = false;
        _sendError = _failure(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bk.ground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Bk.text,
        elevation: 0,
        centerTitle: false,
        title: Text(widget.again ? 'Berdonasi Lagi' : 'Ikut Berdonasi',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Bk.brandSoft,
                borderRadius: BorderRadius.circular(Bk.radiusCard),
              ),
              child: Row(
                children: [
                  const Icon(Icons.volunteer_activism_rounded,
                      color: Bk.brand, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Donasi untuk', style: _muted),
                        Text(
                          widget.campaignTitle,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Bk.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Amount ──────────────────────────────────────────────────────
            const Text('Jumlah donasi', style: _label),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              enabled: !_sending,
              keyboardType: TextInputType.number,
              inputFormatters: [_RupiahInputFormatter()],
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Bk.text),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Bk.textMuted),
                hintText: '0',
                errorText: _amountError,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Bk.radiusButton),
                  borderSide: const BorderSide(color: Bk.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Bk.radiusButton),
                  borderSide: const BorderSide(color: Bk.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Bk.radiusButton),
                  borderSide: const BorderSide(color: Bk.brand, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in _quickAmounts)
                  ActionChip(
                    label: Text(_dotted('$a')),
                    onPressed: _sending ? null : () => _setAmount(a),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Bk.line),
                    labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Bk.brandDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Date and note ───────────────────────────────────────────────
            const Text('Tanggal transfer', style: _label),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Bk.radiusButton),
                side: const BorderSide(color: Bk.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _sending ? null : _pickDate,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: Bk.brand),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_prettyDate(_paidDate),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Bk.text)),
                      ),
                      const Icon(Icons.edit_calendar_outlined,
                          size: 18, color: Bk.textMuted),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Catatan (opsional)', style: _label),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              enabled: !_sending,
              maxLines: 3,
              minLines: 2,
              maxLength: DonationFormScreen.maxNotes,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Contoh: Infaq renovasi',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Bk.radiusButton),
                  borderSide: const BorderSide(color: Bk.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Bk.radiusButton),
                  borderSide: const BorderSide(color: Bk.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Bk.radiusButton),
                  borderSide: const BorderSide(color: Bk.brand, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Proof ───────────────────────────────────────────────────────
            const Text('Bukti transaksi', style: _label),
            const SizedBox(height: 4),
            const Text(
                'Bukti transfer berupa JPG, PNG atau PDF, maksimal 5 MB.',
                style: _muted),
            const SizedBox(height: 8),
            _proof == null ? _proofPicker() : _proofPreview(_proof!),
            if (_proofError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(_proofError!,
                    style: const TextStyle(fontSize: 12, color: Bk.danger)),
              ),
            const SizedBox(height: 24),

            if (_sendError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(Bk.radiusButton),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 18, color: Bk.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_sendError!,
                          style:
                              const TextStyle(fontSize: 13, color: Bk.danger)),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Bk.brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Bk.brand.withOpacity(0.5),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Bk.radiusButton),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Kirim Donasi',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proofPicker() {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bk.radiusButton),
        side: BorderSide(color: _proofError != null ? Bk.danger : Bk.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _sending ? null : _pickProof,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 22),
          child: Column(
            children: [
              Icon(Icons.upload_file_outlined, size: 30, color: Bk.brand),
              SizedBox(height: 6),
              Text('Pilih bukti transaksi',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Bk.brandDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proofPreview(DonationProof proof) {
    final kb = (proof.bytes.length / 1024).ceil();
    final size = kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '$kb KB';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: Bk.card(),
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
                        color: Bk.danger, size: 30),
                  )
                : Image.memory(
                    proof.bytes,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    // Not a picture the device can show: keep the file, show a mark.
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: Bk.idleBg,
                      child:
                          const Icon(Icons.image_outlined, color: Bk.textMuted),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proof.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Bk.text)),
                Text(size, style: _muted),
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

  static const _label =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Bk.text);
  static const _muted =
      TextStyle(fontSize: 12, color: Bk.textMuted, height: 1.4);
}

/// Keeps only digits and groups them in thousands as the user types
/// ("150000" → "150.000"), without a leading zero.
class _RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    if (digits.length > 12) digits = digits.substring(0, 12);
    final text = _DonationFormScreenState._dotted(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

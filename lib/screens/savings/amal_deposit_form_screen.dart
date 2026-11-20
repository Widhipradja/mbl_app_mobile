import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/launcher_tokens.dart';
import '../../services/api_service.dart';
import '../info/donation_form_screen.dart' show DonationProof, ProofKind;
import 'ledger_widgets.dart' show monthNames;

enum _Kind {
  /// A required item of the month (`allocations`): sent in `items`.
  required,

  /// An item of the additional catalog (`me/items`): sent in
  /// `additional_items` with its `catalog_item_id`.
  catalog,

  /// An additional item the member types in: `additional_items` with only a
  /// name.
  free,
}

/// One line of the form: an amount for one item.
class _DepositItem {
  _DepositItem({
    required this.kind,
    this.code = '',
    this.name = '',
    this.group = '',
    this.sortOrder = 0,
    int? suggested,
  })  : controller = TextEditingController(
            text: suggested == null || suggested <= 0 ? '' : '$suggested'),
        nameController = TextEditingController();

  final _Kind kind;

  /// `item_snapshot_id` (required item) or the catalog `id`.
  final String code;
  final String name;

  /// Free text set by the admin; shown as the heading of its section.
  final String group;
  final num sortOrder;
  final TextEditingController controller;

  /// The name of a [_Kind.free] item.
  final TextEditingController nameController;

  int get amount =>
      int.tryParse(controller.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  /// Position of [group]: Pusat, Daerah, Desa, Kelompok (ignoring case and
  /// surrounding spaces), any other group last.
  int get groupRank {
    const order = ['pusat', 'daerah', 'desa', 'kelompok'];
    final i = order.indexOf(group.trim().toLowerCase());
    return i < 0 ? order.length : i;
  }

  void dispose() {
    controller.dispose();
    nameController.dispose();
  }
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
  final List<_DepositItem> _catalog = [];
  final List<_DepositItem> _free = [];
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
    for (final i in [..._items, ..._catalog, ..._free]) {
      i.dispose();
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

  static num _order(dynamic v) => num.tryParse(v?.toString() ?? '') ?? 0;

  /// Sorted by group (Pusat, Daerah, Desa, Kelompok, others last), then by
  /// `sort_order`, then as the server sent them (the index breaks ties,
  /// because List.sort is not stable).
  static List<_DepositItem> _sorted(List<_DepositItem> list) {
    final at = {for (var i = 0; i < list.length; i++) list[i]: i};
    return [...list]..sort((a, b) {
        var c = a.groupRank.compareTo(b.groupRank);
        if (c == 0) c = a.sortOrder.compareTo(b.sortOrder);
        return c != 0 ? c : at[a]!.compareTo(at[b]!);
      });
  }

  /// `allocations` of GET collection.
  static List<_DepositItem> _parseAllocations(dynamic raw) {
    var src = raw;
    if (src is Map && src['data'] is Map) src = src['data'];
    final list = src is Map ? src['allocations'] : null;
    if (list is! List) return const [];
    return [
      for (final r in list.whereType<Map>())
        _DepositItem(
          kind: _Kind.required,
          code: _str(r, ['item_snapshot_id']),
          name: _str(r, ['item_name', 'item_code']),
          group: _str(r, ['group']),
          sortOrder: _order(r['sort_order']),
          suggested:
              double.tryParse((r['final_amount'] ?? '').toString())?.round(),
        ),
    ];
  }

  /// The array answered by GET me/items (active additional items).
  static List<_DepositItem> _parseCatalog(dynamic raw) {
    var src = raw;
    if (src is Map) src = src['data'] ?? src['items'];
    if (src is! List) return const [];
    return [
      for (final r in src.whereType<Map>())
        if (_str(r, ['id']).isNotEmpty && _str(r, ['name']).isNotEmpty)
          _DepositItem(
            kind: _Kind.catalog,
            code: _str(r, ['id']),
            name: _str(r, ['name']),
            group: _str(r, ['group']),
            sortOrder: _order(r['sort_order']),
          ),
    ];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = ApiService();
      // The catalog is optional: without it the required items still work.
      final catalogFuture = api
          .getShodaqohItems(isAdditional: true, isActive: true)
          .then<List<_DepositItem>>((r) => _parseCatalog(r.data))
          .catchError((Object e) {
        debugPrint('AmalDepositFormScreen catalog error: $e');
        return <_DepositItem>[];
      });
      final resp = await api.getCollection(_period);
      final catalog = await catalogFuture;
      if (!mounted) return;
      for (final i in [..._items, ..._catalog]) {
        i.dispose();
      }
      setState(() {
        _items
          ..clear()
          ..addAll(_sorted(_parseAllocations(resp.data)));
        _catalog
          ..clear()
          ..addAll(_sorted(catalog));
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
    final filled = [
      for (final i in [..._items, ..._catalog, ..._free])
        if (i.amount > 0) i,
    ];
    final unnamed = filled.any(
        (i) => i.kind == _Kind.free && i.nameController.text.trim().isEmpty);
    setState(() {
      _amountError = filled.isEmpty
          ? 'Isi minimal satu jumlah lebih dari Rp 0.'
          : unnamed
              ? 'Isi nama untuk setiap shodaqoh tambahan.'
              : null;
      _proofError = _proof != null ? null : 'Lampirkan bukti transfer.';
      _sendError = null;
    });
    final proof = _proof;
    if (_amountError != null || proof == null) return;

    // Amounts go as decimal strings (`actual_amount`).
    final regular = [
      for (final i in filled.where((i) => i.kind == _Kind.required))
        {'item_snapshot_id': i.code, 'actual_amount': '${i.amount}'},
    ];
    final extra = [
      for (final i in filled.where((i) => i.kind != _Kind.required))
        {
          if (i.kind == _Kind.catalog) 'catalog_item_id': i.code,
          'item_name':
              i.kind == _Kind.catalog ? i.name : i.nameController.text.trim(),
          if (i.group.isNotEmpty) 'group': i.group,
          'actual_amount': '${i.amount}',
        },
    ];
    final notes = _notes.text.trim();
    // Each entry needs a non-empty items or additional_items: empty ones are
    // left out. Status and member fields are never sent (server forces them).
    final entry = <String, dynamic>{
      'collected_for_period': _period,
      if (regular.isNotEmpty) 'items': regular,
      if (extra.isNotEmpty) 'additional_items': extra,
      if (notes.isNotEmpty) 'notes': notes,
      'collected_at': DateTime.now().toUtc().toIso8601String(),
    };

    // `month` is the current month; the entry's period may not be later.
    final now = DateTime.now();
    final current = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    setState(() => _sending = true);
    try {
      await ApiService().submitCollection(current, [entry],
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

  Widget _amountField(_DepositItem i) => TextField(
        controller: i.controller,
        enabled: !_sending,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() => _amountError = null),
        decoration: _decoration.copyWith(prefixText: 'Rp ', hintText: '0'),
      );

  /// The items with a heading each time the group changes.
  List<Widget> _section(List<_DepositItem> items) {
    final out = <Widget>[];
    String? group;
    for (final i in items) {
      final g = i.group.trim();
      if (g.isNotEmpty && g != group) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(g, style: Lx.metadata.copyWith(color: Lx.secondary)),
        ));
      }
      group = g;
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: Lx.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i.name, style: Lx.cardHeading),
            const SizedBox(height: 6),
            _amountField(i),
          ],
        ),
      ));
    }
    return out;
  }

  Widget _freeRow(int n) {
    final i = _free[n];
    return Padding(
      padding: const EdgeInsets.only(bottom: Lx.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: i.nameController,
                  enabled: !_sending,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() => _amountError = null),
                  decoration: _decoration.copyWith(hintText: 'Nama shodaqoh'),
                ),
              ),
              IconButton(
                tooltip: 'Hapus',
                onPressed: _sending
                    ? null
                    : () => setState(() => _free.removeAt(n).dispose()),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _amountField(i),
        ],
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
        ..._section(_items),
        if (_catalog.isNotEmpty) ...[
          Text('Shodaqoh tambahan', style: Lx.sectionHeading),
          const SizedBox(height: Lx.s8),
          ..._section(_catalog),
        ],
        for (var n = 0; n < _free.length; n++) _freeRow(n),
        TextButton.icon(
          onPressed: _sending
              ? null
              : () => setState(() => _free.add(_DepositItem(kind: _Kind.free))),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tambah shodaqoh lain'),
        ),
        const SizedBox(height: Lx.s8),
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

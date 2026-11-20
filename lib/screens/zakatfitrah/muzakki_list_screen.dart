import '../../config/baraka_tokens.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/app_configuration.dart';
import '../../models/muzakki.dart';
import '../../providers/auth_provider.dart';
import '../../providers/configuration_provider.dart';
import '../../providers/zakat_provider.dart';
import '../../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UUID v4 generator (no external package needed)
// ─────────────────────────────────────────────────────────────────────────────
String _generateFamilyId() {
  final rng = Random.secure();
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Amil model (from /api/zakat-fitrah/amil)
// ─────────────────────────────────────────────────────────────────────────────
class _Amil {
  final String id;
  final String name;
  final String groupName;

  const _Amil({required this.id, required this.name, this.groupName = ''});

  factory _Amil.fromJson(Map<String, dynamic> j) => _Amil(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        groupName: j['group_name'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class representing one family group
// ─────────────────────────────────────────────────────────────────────────────
class _FamilyGroup {
  final String familyId;
  final List<Muzakki> members; // already sorted

  const _FamilyGroup({required this.familyId, required this.members});

  Muzakki? get head =>
      members.where((m) => m.isHeadOfFamily).firstOrNull ?? members.firstOrNull;

  String get familyName {
    final h = head;
    if (h == null) return 'Keluarga';
    final s = h.surname.isNotEmpty ? h.surname : h.firstName;
    return 'Keluarga $s';
  }

  String get groupName => head?.groupName ?? '';
  String get externalName => head?.externalName ?? '';

  int get memberCount => members.length;

  bool get allPaid => members.every((m) => m.isPaid);
  bool get anyPaid => members.any((m) => m.isPaid);
  bool get nonePaid => !anyPaid;

  /// Summary: "6 / 8 Setor"
  String get paymentSummary {
    final paid = members.where((m) => m.isPaid).length;
    return '$paid / $memberCount Setor';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
/// Muzakki list — body-only widget hosted inside ZakatShellScreen.
class MuzakkiListScreen extends StatefulWidget {
  const MuzakkiListScreen({super.key});

  @override
  State<MuzakkiListScreen> createState() => _MuzakkiListScreenState();
}

class _MuzakkiListScreenState extends State<MuzakkiListScreen> {
  static const _green = Color(0xFF066046);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterGroup;
  bool? _filterPaid; // null=all, true=sudah setor, false=belum setor
  bool _filterAmilPending = false;
  bool _isImportingExcel = false;

  /// null = all, 'internal', or 'ext:<Master Eksternal name>'.
  String? _filterOrigin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ZakatProvider>();
      final cfg = context.read<ConfigurationProvider>();
      if (p.muzakkiList.isEmpty && !p.isLoading) p.fetchMuzakki();
      if (p.externals.isEmpty && !p.isLoadingExternals) p.fetchExternals();
      if (cfg.configurations.isEmpty && !cfg.isLoading) {
        cfg.fetchConfigurations(
          module: ConfigurationProvider.moduleZakatFitrah,
          yearId: p.selectedYear?.id,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Build family groups ─────────────────────────────────────────────────
  List<_FamilyGroup> _buildGroups(List<Muzakki> all) {
    // 1. Group by family_id (keep full family members in each card)
    final Map<String, List<Muzakki>> byFamily = {};
    for (final m in all) {
      byFamily.putIfAbsent(m.familyId, () => []).add(m);
    }

    // 2. Sort members within each family:
    //    head of family first, then Suami, Istri, Anak, Others
    for (final members in byFamily.values) {
      members
          .sort((a, b) => a.relationshipOrder.compareTo(b.relationshipOrder));
    }

    // 3. Build groups
    final groups = byFamily.entries
        .map((e) => _FamilyGroup(familyId: e.key, members: e.value))
        .toList();

    // 4. Filter groups by family-level criteria
    final q = _searchQuery.toLowerCase();
    final filteredGroups = groups.where((g) {
      final matchSearch = q.isEmpty ||
          g.familyName.toLowerCase().contains(q) ||
          g.members.any((m) {
            return m.fullName.toLowerCase().contains(q) ||
                m.surname.toLowerCase().contains(q) ||
                m.groupName.toLowerCase().contains(q) ||
                m.externalName.toLowerCase().contains(q);
          });

      final head = g.head;
      final matchOrigin = switch (_filterOrigin) {
        null => true,
        'internal' => head?.isInternal ?? true,
        final o when o.startsWith('ext:') => g.members.any(
            (m) => m.externalName.trim() == o.substring(4),
          ),
        _ => true,
      };

      final matchGroup = _filterGroup == null ||
          g.members.any((m) => m.groupName == _filterGroup);

      final matchPaid =
          _filterPaid == null || (_filterPaid == true ? g.anyPaid : g.nonePaid);

      final matchAmilPending = !_filterAmilPending ||
          g.members.any((m) => m.isPaid && !m.isSerahTerimaAmil);

      return matchSearch &&
          matchOrigin &&
          matchGroup &&
          matchPaid &&
          matchAmilPending;
    }).toList();

    // 5. Sort groups by family name
    filteredGroups.sort((a, b) => a.familyName.compareTo(b.familyName));

    return filteredGroups;
  }

  List<String> _groups(List<Muzakki> all) =>
      all.map((m) => m.groupName).where((g) => g.isNotEmpty).toSet().toList()
        ..sort();

  Future<void> _downloadExcelTemplate() async {
    final excel = ex.Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != 'MuzakkiTemplate') {
      excel.rename(defaultSheet, 'MuzakkiTemplate');
    }

    final sheet = excel['MuzakkiTemplate'];
    final headers = [
      'first_name',
      'last_name',
      'surname',
      'sex',
      'relationship',
      'is_head_of_family',
      'is_internal',
      'address',
      'phone',
      'group_name',
    ];

    for (var col = 0; col < headers.length; col++) {
      sheet
          .cell(ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .value = ex.TextCellValue(headers[col]);
    }

    final sample = [
      'Ahmad',
      'Firmansyah',
      'Firmansyah',
      'M',
      'Suami',
      'true',
      'true',
      'Jl. Contoh No. 1',
      '08123456789',
      'Blok A',
    ];

    for (var col = 0; col < sample.length; col++) {
      sheet
          .cell(ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1))
          .value = ex.TextCellValue(sample[col]);
    }

    final notes = excel['Petunjuk'];
    notes
        .cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .value = ex.TextCellValue('Petunjuk isi template import muzakki');
    notes
        .cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        .value = ex.TextCellValue('1) Kolom wajib: first_name');
    notes
        .cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
        .value = ex.TextCellValue('2) sex isi M atau F');
    notes
        .cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
        .value = ex.TextCellValue(
      '3) is_head_of_family/is_internal isi true/false',
    );
    notes
        .cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4))
        .value = ex.TextCellValue(
      '4) Baris is_head_of_family=true memulai keluarga baru (family_id otomatis).',
    );
    notes
        .cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5))
        .value = ex.TextCellValue(
      '5) Baris berikut (is_head_of_family=false) masuk ke keluarga yang sama.',
    );

    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/template_muzakki.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Template import data muzakki',
      subject: 'Template Muzakki',
    );
  }

  Future<void> _uploadExcelMuzakki() async {
    final provider = context.read<ZakatProvider>();
    final yearId = provider.selectedYear?.id ?? '';

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) return;

    final pickedFile = picked.files.single;
    final bytes = pickedFile.bytes ??
        (pickedFile.path != null
            ? await File(pickedFile.path!).readAsBytes()
            : null);

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File tidak dapat dibaca.')),
      );
      return;
    }

    setState(() {
      _isImportingExcel = true;
    });

    var successCount = 0;
    var failedCount = 0;
    var skippedCount = 0;

    try {
      final excel = ex.Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        throw Exception('Sheet tidak ditemukan.');
      }

      final sheet =
          excel.tables['MuzakkiTemplate'] ?? excel.tables.values.first;
      final rows = sheet.rows;
      if (rows.length < 2) {
        throw Exception('Data kosong. Isi minimal 1 baris data.');
      }

      final headers = rows.first
          .map((cell) => _normalizeHeader(_cellToText(cell)))
          .toList();
      final headerIndex = <String, int>{};
      for (var i = 0; i < headers.length; i++) {
        if (headers[i].isNotEmpty) headerIndex[headers[i]] = i;
      }

      String val(List<ex.Data?> row, String key) {
        final idx = headerIndex[key];
        if (idx == null || idx >= row.length) return '';
        return _cellToText(row[idx]).trim();
      }

      final bulkRows = <Map<String, dynamic>>[];

      // Auto-group rows into families:
      // Every is_head_of_family=true row starts a new family (new UUID).
      // Subsequent is_head_of_family=false rows belong to that same family.
      String currentFamilyId = '';

      for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        final firstName = val(row, 'first_name');
        final lastName = _cleanCell(val(row, 'last_name'));
        final surname = _cleanCell(val(row, 'surname'));
        final sex = _parseSex(val(row, 'sex'));
        final relationship = val(row, 'relationship');
        final isHead = _parseBool(val(row, 'is_head_of_family'));
        final isInternal =
            _parseBool(val(row, 'is_internal'), defaultValue: true);
        final address = _cleanCell(val(row, 'address'));
        final phone = _cleanCell(val(row, 'phone'));
        final groupName = _cleanCell(val(row, 'group_name'));

        final isEmptyRow = [
          firstName,
          lastName,
          surname,
          val(row, 'sex'),
          relationship,
          address,
          phone,
          groupName,
        ].every((v) => v.isEmpty);
        if (isEmptyRow) continue;

        if (firstName.isEmpty) {
          skippedCount++;
          continue;
        }

        // Assign family ID: head starts a new family, members join current one.
        if (isHead || currentFamilyId.isEmpty) {
          currentFamilyId = _generateFamilyId();
        }

        bulkRows.add({
          'first_name': firstName,
          if (lastName.isNotEmpty) 'last_name': lastName,
          if (surname.isNotEmpty) 'surname': surname,
          'sex': sex,
          if (relationship.isNotEmpty) 'relationship': relationship,
          'is_head_of_family': isHead,
          'is_internal': isInternal,
          'family_id': currentFamilyId,
          if (address.isNotEmpty) 'address': address,
          if (phone.isNotEmpty) 'phone': phone,
          if (groupName.isNotEmpty) 'group_name': groupName,
        });
      }

      if (bulkRows.isEmpty) {
        throw Exception('Tidak ada baris valid untuk diimport.');
      }

      final api = ApiService();
      final currentUser = context.read<AuthProvider>().user;
      final byUser = currentUser?.userId ?? currentUser?.id ?? '';
      final response = await api.createMuzakkiBulk(
        yearId: yearId,
        muzakkis: bulkRows,
        createdBy: byUser,
        updatedBy: byUser,
      );

      final result = _extractBulkImportResult(response.data);
      successCount = result.success;
      failedCount = result.failed + skippedCount;

      if (successCount == 0 && failedCount == 0) {
        successCount = bulkRows.length;
      }

      await provider.fetchMuzakki();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import selesai. Berhasil: $successCount, Gagal: $failedCount',
          ),
          backgroundColor: failedCount == 0 ? _green : const Color(0xFFD97706),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Log the actual server response body for easier debugging
      String errMsg = 'Import gagal: $e';
      if (e is DioException && e.response != null) {
        debugPrint('[bulk import] server error body: ${e.response?.data}');
        final body = e.response?.data;
        String? serverDetail;
        if (body is Map<String, dynamic>) {
          serverDetail = body['message']?.toString() ??
              body['error']?.toString() ??
              body['detail']?.toString();
        } else if (body is String && body.isNotEmpty) {
          serverDetail = body;
        }
        if (serverDetail != null) errMsg = 'Import gagal: $serverDetail';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errMsg)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImportingExcel = false;
        });
      }
    }
  }

  String _cellToText(ex.Data? data) => data?.value?.toString() ?? '';

  /// Normalise a string that came from an Excel cell.
  /// Numeric-empty cells (e.g. 0, 0.0) that look blank are returned as ''.
  String _cleanCell(String raw) {
    final t = raw.trim();
    // Excel stores empty numeric cells as 0 / 0.0
    if (t == '0' || t == '0.0') return '';
    return t;
  }

  String _normalizeHeader(String raw) {
    return raw.trim().toLowerCase().replaceAll(' ', '_');
  }

  bool _parseBool(String raw, {bool defaultValue = false}) {
    if (raw.isEmpty) return defaultValue;
    final normalized = raw.trim().toLowerCase();
    if (['1', 'true', 'yes', 'y', 'ya'].contains(normalized)) return true;
    if (['0', 'false', 'no', 'n', 'tidak'].contains(normalized)) return false;
    return defaultValue;
  }

  String _parseSex(String raw) {
    final normalized = raw.trim().toUpperCase();
    if (normalized == 'F' || normalized == 'P') return 'F';
    return 'M';
  }

  _BulkImportResult _extractBulkImportResult(dynamic raw) {
    int readInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

    dynamic source = raw;
    if (raw is Map<String, dynamic> && raw['data'] != null) {
      source = raw['data'];
    }

    if (source is Map<String, dynamic>) {
      final success = readInt(
        source['success_count'] ?? source['success'] ?? source['created'],
      );
      final failed = readInt(
        source['failed_count'] ?? source['failed'] ?? source['error_count'],
      );
      return _BulkImportResult(success: success, failed: failed);
    }

    return const _BulkImportResult(success: 0, failed: 0);
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<ZakatProvider>(
      builder: (context, provider, _) {
        // The internal chip is named after the GROUP set in Configuration.
        final groupLabel = context
                .watch<ConfigurationProvider>()
                .configurations
                .where((c) => c.code == 'GROUP' && c.value.trim().isNotEmpty)
                .map((c) => c.value.trim())
                .firstOrNull ??
            'Internal';

        // Loading
        if (provider.isLoading) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(_green)),
                SizedBox(height: 16),
                Text('Memuat data muzakki…',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          );
        }

        // Error (empty)
        if (provider.errorMessage != null && provider.muzakkiList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 56, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: provider.fetchMuzakki,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final allMuzakki = provider.muzakkiList;
        final groups = _buildGroups(allMuzakki);

        final paidCount = allMuzakki.where((m) => m.isPaid).length;
        final unpaidCount = allMuzakki.length - paidCount;
        final amilPendingCount =
            allMuzakki.where((m) => m.isPaid && !m.isSerahTerimaAmil).length;
        final familyCount = groups.length;

        return RefreshIndicator(
          color: _green,
          onRefresh: provider.fetchMuzakki,
          child: Column(
            children: [
              // ── Header + filters ──────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search + overflow menu
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Cari nama, keluarga, grup…',
                              hintStyle: const TextStyle(
                                  color: Color(0xFFCBD5E1), fontSize: 14),
                              prefixIcon: const Icon(Icons.search,
                                  color: Color(0xFFCBD5E1)),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear,
                                          color: Color(0xFFCBD5E1)),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFFF4F7F6),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'download') _downloadExcelTemplate();
                            if (value == 'upload' && !_isImportingExcel) {
                              _uploadExcelMuzakki();
                            }
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.more_vert_rounded,
                                color: Color(0xFF64748B), size: 20),
                          ),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'download',
                              child: Row(
                                children: [
                                  Icon(Icons.download_rounded,
                                      size: 18, color: Color(0xFF066046)),
                                  SizedBox(width: 10),
                                  Text('Download Template Excel',
                                      style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'upload',
                              enabled: !_isImportingExcel,
                              child: Row(
                                children: [
                                  _isImportingExcel
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF066046),
                                          ),
                                        )
                                      : const Icon(Icons.upload_file_rounded,
                                          size: 18, color: Color(0xFF066046)),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isImportingExcel
                                        ? 'Sedang import...'
                                        : 'Upload Excel',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),

              // ── Stats row ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      _StatCompactItem(
                        value: '$familyCount',
                        label: 'Semua KK',
                        color: _green,
                        isActive: _filterPaid == null &&
                            _filterGroup == null &&
                            _filterOrigin == null &&
                            !_filterAmilPending,
                        onTap: () => setState(() {
                          _filterPaid = null;
                          _filterGroup = null;
                          _filterOrigin = null;
                          _filterAmilPending = false;
                        }),
                      ),
                      _StatCompactItem(
                        value: '$paidCount',
                        label: 'Sudah Setor',
                        color: const Color(0xFF16A34A),
                        isActive: _filterPaid == true,
                        onTap: () => setState(() {
                          _filterPaid = _filterPaid == true ? null : true;
                          _filterGroup = null;
                          _filterAmilPending = false;
                        }),
                      ),
                      _StatCompactItem(
                        value: '$unpaidCount',
                        label: 'Belum Setor',
                        color: const Color(0xFFDC2626),
                        isActive: _filterPaid == false,
                        onTap: () => setState(() {
                          _filterPaid = _filterPaid == false ? null : false;
                          _filterGroup = null;
                          _filterAmilPending = false;
                        }),
                      ),
                      _StatCompactItem(
                        value: '$amilPendingCount',
                        label: 'Belum Akad',
                        color: const Color(0xFFD97706),
                        isActive: _filterAmilPending,
                        onTap: () => setState(() {
                          _filterAmilPending = !_filterAmilPending;
                          _filterPaid = null;
                          _filterGroup = null;
                        }),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Origin filter: internal / eksternal / per Master Eksternal
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final o in <(String?, String)>[
                      (null, 'Semua'),
                      ('internal', groupLabel),
                      for (final e in provider.externals
                          .where((e) => e.isActive && e.name.trim().isNotEmpty))
                        ('ext:${e.name.trim()}', e.name.trim()),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(o.$2),
                          selected: _filterOrigin == o.$1,
                          showCheckmark: false,
                          selectedColor: _green,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _filterOrigin == o.$1
                                ? _green
                                : const Color(0xFFE3EAE6),
                          ),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _filterOrigin == o.$1
                                ? Colors.white
                                : const Color(0xFF0F1F1A),
                          ),
                          onSelected: (_) =>
                              setState(() => _filterOrigin = o.$1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // ── Family list ───────────────────────────────────────────
              Expanded(
                child: groups.isEmpty
                    ? _emptyState(allMuzakki.isEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: groups.length,
                        itemBuilder: (context, i) => _FamilyCard(
                          key: ValueKey(groups[i].familyId),
                          group: groups[i],
                          // A search should show the matching members.
                          initiallyExpanded: _searchQuery.trim().isNotEmpty,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(bool globallyEmpty) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                globallyEmpty ? Icons.people_outline : Icons.search_off,
                size: 64,
                color: const Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 12),
              Text(
                globallyEmpty ? 'Belum ada data muzakki' : 'Tidak ditemukan',
                style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
}

/// Alias for ZakatShellScreen
typedef MuzakkiListBody = MuzakkiListScreen;

// ─────────────────────────────────────────────────────────────────────────────
// Family Card (collapsible)
// ─────────────────────────────────────────────────────────────────────────────
class _FamilyCard extends StatefulWidget {
  const _FamilyCard({
    super.key,
    required this.group,
    this.initiallyExpanded = false,
  });
  final _FamilyGroup group;
  final bool initiallyExpanded;

  @override
  State<_FamilyCard> createState() => _FamilyCardState();
}

class _FamilyCardState extends State<_FamilyCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant _FamilyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  static const _green = Color(0xFF066046);

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final externalSoulsCount = context.select<ZakatProvider, int>(
      (p) => p.getExternalByFamilyId(g.familyId)?.externalTotalSouls ?? 0,
    );

    final paidCount = g.members.where((m) => m.isPaid).length;
    final akadDone = g.members.every((m) => !m.isPaid || m.isSerahTerimaAmil);
    final Widget status = g.nonePaid
        ? const BkStatusPill.idle('Belum bayar')
        : !g.allPaid
            ? BkStatusPill.pending('$paidCount/${g.memberCount} bayar')
            : akadDone
                ? const BkStatusPill.done('Selesai')
                : const BkStatusPill.pending('Belum akad');
    final subtitle = <String>[
      '${g.memberCount} jiwa',
      if (externalSoulsCount > 0) '+$externalSoulsCount ext',
      if (g.groupName.isNotEmpty && g.groupName != g.externalName) g.groupName,
      if (g.externalName.isNotEmpty) g.externalName,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: Bk.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Family header (one compact row; tap to expand) ─────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.familyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Bk.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Bk.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  status,
                  // Quick pay without expanding the card first.
                  if (!_expanded && !g.allPaid && g.head != null) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => context.push(
                        '/zakat-fitrah/transaction',
                        extra: g.head,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Bayar'),
                    ),
                  ],
                  SizedBox(
                    width: 36,
                    height: 44,
                    child: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 22,
                      color: Bk.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Action buttons ─────────────────────────────────────────────
          if (_expanded && g.head != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  // Akad is part of every new transaction; this stays for
                  // older payments and for correcting the amil.
                  if (g.anyPaid) ...[
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.handshake_outlined,
                        label: g.members
                                .any((m) => m.isPaid && !m.isSerahTerimaAmil)
                            ? 'Akad'
                            : 'Ubah Akad',
                        color: _green,
                        bg: const Color(0xFFE8F5F0),
                        onTap: () => _showAkadDialog(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Pay / Edit
                  Expanded(
                    child: _ActionBtn(
                      icon: g.allPaid
                          ? Icons.edit_note_rounded
                          : Icons.payment_rounded,
                      label: g.allPaid ? 'Edit Bayar' : 'Bayar Zakat',
                      color: g.allPaid ? _green : Colors.white,
                      bg: g.allPaid ? const Color(0xFFE8F5F0) : _green,
                      onTap: () => context.push(
                        '/zakat-fitrah/transaction',
                        extra: g.head,
                      ),
                    ),
                  ),
                  // Receipt
                  if (g.anyPaid) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.receipt_long_rounded,
                        label: 'Bukti',
                        color: _green,
                        bg: const Color(0xFFE8F5F0),
                        onTap: () => _sendFamilyReceipt(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // ── Members ───────────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ...g.members.map((m) => _MemberRow(muzakki: m)),
            // Add member button at bottom of expanded card
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            InkWell(
              onTap: () => context.push(
                '/zakat-fitrah/add?family_id=${g.familyId}',
              ),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add_alt_1_outlined,
                        size: 16, color: _green),
                    SizedBox(width: 6),
                    Text(
                      'Tambah Anggota Keluarga',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAkadDialog(BuildContext context) async {
    final g = widget.group;
    final provider = context.read<ZakatProvider>();

    // ── Fetch amil list ──────────────────────────────────────────────────
    List<_Amil> amilList = [];
    bool loadingAmil = true;
    _Amil? selectedAmil;
    String ikrarZakat = '';

    try {
      final api = ApiService();
      final yearId = provider.selectedYear?.id ?? '';
      final results = await Future.wait([
        api.getZakatAmilList(yearId: yearId.isNotEmpty ? yearId : null),
        context
            .read<ConfigurationProvider>()
            .fetchEffectiveValue('IKRAR_ZAKAT', yearId),
      ]);

      final raw = (results[0] as dynamic).data;
      final list = raw is List
          ? raw
          : (raw as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
      amilList = list
          .map((j) => _Amil.fromJson(j as Map<String, dynamic>))
          .where((a) => a.id.isNotEmpty && a.name.isNotEmpty)
          .toList();

      ikrarZakat = (results[1] as String?) ?? '';
      final existing = g.members
          .where((m) => m.isPaid && m.amilName.isNotEmpty)
          .map((m) => m.amilName)
          .firstOrNull;
      if (existing != null) {
        selectedAmil = amilList.firstWhere(
          (a) => a.name == existing,
          orElse: () => _Amil(id: existing, name: existing),
        );
      }
    } catch (e) {
      debugPrint('_showAkadDialog fetchAmil error: $e');
    } finally {
      loadingAmil = false;
    }

    if (!context.mounted) return;

    // ── Show dialog ──────────────────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Akad ke Amil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                    children: [
                      const TextSpan(
                          text: 'Serah terima zakat ke amil untuk keluarga '),
                      TextSpan(
                        text: g.familyName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── Amil selector ─────────────────────────────────────────
                const Text(
                  'Nama Amil *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                if (loadingAmil)
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _green),
                    ),
                  )
                else if (amilList.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: Color(0xFFF59E0B)),
                        SizedBox(width: 8),
                        Text('Tidak ada data amil',
                            style: TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 13)),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () async {
                      final picked = await showModalBottomSheet<_Amil>(
                        context: ctx,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (sheetCtx) => DraggableScrollableSheet(
                          expand: false,
                          initialChildSize: 0.5,
                          maxChildSize: 0.85,
                          builder: (_, sc) => Column(
                            children: [
                              Container(
                                margin:
                                    const EdgeInsets.only(top: 10, bottom: 8),
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                child: Text('Pilih Nama Amil',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.builder(
                                  controller: sc,
                                  itemCount: amilList.length,
                                  itemBuilder: (_, i) {
                                    final a = amilList[i];
                                    final isSel = selectedAmil?.id == a.id;
                                    return ListTile(
                                      leading: CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            const Color(0xFFE8F5F0),
                                        child: Text(
                                          a.name.isNotEmpty
                                              ? a.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              color: _green,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      title: Text(a.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      subtitle: a.groupName.isNotEmpty
                                          ? Text(a.groupName)
                                          : null,
                                      trailing: isSel
                                          ? const Icon(Icons.check_circle,
                                              color: _green)
                                          : null,
                                      selected: isSel,
                                      onTap: () => Navigator.pop(sheetCtx, a),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedAmil = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: selectedAmil != null
                              ? _green
                              : const Color(0xFFE2E8F0),
                          width: selectedAmil != null ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 18,
                            color: selectedAmil != null
                                ? _green
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedAmil?.name ?? 'Pilih Nama Amil...',
                              style: TextStyle(
                                fontSize: 13,
                                color: selectedAmil != null
                                    ? const Color(0xFF1A1A1A)
                                    : const Color(0xFFCBD5E1),
                                fontWeight: selectedAmil != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          const Icon(Icons.expand_more,
                              color: Color(0xFF94A3B8), size: 18),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // ── Action buttons ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: selectedAmil == null
                          ? null
                          : () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _green.withOpacity(0.4),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Akad'),
                    ),
                  ],
                ),
                // ── Ikrar Zakat ───────────────────────────────────────────
                if (ikrarZakat.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Row(
                            children: [
                              Icon(Icons.format_quote_rounded,
                                  size: 16, color: _green),
                              SizedBox(width: 6),
                              Text(
                                'Ikrar Zakat',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFBBF7D0)),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                            child: Text(
                              ikrarZakat,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF166534),
                                height: 1.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && context.mounted && selectedAmil != null) {
      try {
        final api = ApiService();
        await api.patchZakatMuzakkiFamilyAkad(
          g.familyId,
          status: true,
          amilName: selectedAmil!.name,
        );
        if (context.mounted) {
          await provider.fetchMuzakki();
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memproses akad.')),
          );
        }
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Receipt: build PNG → share
  // ────────────────────────────────────────────────────────────────────────

  Future<String> _buildReceiptForFamily(BuildContext context) async {
    final head = widget.group.head;
    if (head == null) return '';
    final provider = context.read<ZakatProvider>();
    final yearId = provider.selectedYear?.id ?? '';
    final yearLabel = provider.selectedYear?.label ?? 'Zakat Fitrah';

    final now = DateTime.now();
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final tanggal = '${now.day} ${months[now.month]} ${now.year}';

    String headName = head.fullName;
    String amilName = head.amilName.isNotEmpty ? head.amilName : '—';
    final List<Map<String, dynamic>> paidMembers = [];

    // ── Read org/location from already-loaded ConfigurationProvider ───
    final cfgs = context.read<ConfigurationProvider>().configurations;
    String cfgVal(String code) => cfgs
        .firstWhere((c) => c.code == code,
            orElse: () => const AppConfiguration(oid: '', module: '', code: ''))
        .value
        .trim();
    final orgName = cfgVal('GROUP');
    final location = cfgVal('LOCATION');
    final locationAddr = cfgVal('LOCATION_ADDR');

    if (head.familyId.isNotEmpty && yearId.isNotEmpty) {
      try {
        final api = ApiService();
        final resp = await api.getFamilyZakatResume(
          head.familyId,
          yearId: yearId,
        );
        final data = resp.data is Map<String, dynamic>
            ? resp.data as Map<String, dynamic>
            : <String, dynamic>{};
        headName = data['head_name'] as String? ?? headName;

        final members = data['members'] as List<dynamic>? ?? [];
        for (final raw in members) {
          final member = raw as Map<String, dynamic>;
          if (member['is_paid'] == true) {
            final rawName = (member['name'] as String?)?.trim() ??
                (member['full_name'] as String?)?.trim() ??
                (member['member_name'] as String?)?.trim() ??
                '';
            final mz = Muzakki.fromJson(member);
            final resolvedName = rawName.isNotEmpty ? rawName : mz.fullName;
            final rawType = member['payment_type'] as String? ?? '';
            final isRice = rawType == 'rice';
            final rawQty =
                (member['quantity'] as num?)?.toDouble() ?? mz.amountSo;
            final rawAmt = () {
              final a = member['amount'];
              if (a is num) return a.toDouble();
              return double.tryParse(a?.toString() ?? '') ?? mz.amountRp;
            }();
            paidMembers.add({
              'name': resolvedName,
              'payment_type': isRice ? 'rice' : 'money',
              'quantity': rawQty,
              'amount': rawAmt,
            });
          }
        }
      } catch (e) {
        debugPrint('_buildReceiptForFamily error: \$e');
      }
    }

    double totalSo = 0;
    double totalRp = 0;
    for (final member in paidMembers) {
      final type = member['payment_type'] as String? ?? '';
      if (type == 'rice') {
        totalSo += (member['quantity'] as num?)?.toDouble() ?? 0;
      } else if (type == 'money') {
        final amt = member['amount'];
        totalRp += amt is num
            ? amt.toDouble()
            : double.tryParse(amt?.toString() ?? '') ?? 0;
      }
    }

    String fmtRp(double v) => v.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]!}.');

    String sejumlah;
    if (totalRp > 0 && totalSo > 0) {
      final soStr = totalSo % 1 == 0
          ? totalSo.toInt().toString()
          : totalSo.toStringAsFixed(2);
      sejumlah = 'Rp. ${fmtRp(totalRp)} dan $soStr So beras.';
    } else if (totalRp > 0) {
      sejumlah = 'Rp. ${fmtRp(totalRp)}.';
    } else if (totalSo > 0) {
      final soStr = totalSo % 1 == 0
          ? totalSo.toInt().toString()
          : totalSo.toStringAsFixed(2);
      sejumlah = '$soStr So beras.';
    } else {
      sejumlah = paidMembers.isEmpty ? '(tidak ada data)' : ' —.';
    }

    final repaintKey = GlobalKey();
    final receiptWidget = RepaintBoundary(
      key: repaintKey,
      child: _ReceiptCard(
        yearLabel: yearLabel,
        headName: headName,
        jiwa: paidMembers.length,
        sejumlah: sejumlah,
        amilName: amilName,
        tanggal: tanggal,
        paidMembers: paidMembers,
        orgName: orgName,
        location: location,
        locationAddr: locationAddr,
      ),
    );

    late OverlayEntry entry;
    final completer = Completer<Uint8List>();

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -5000,
        top: -5000,
        width: 360,
        child: Material(color: Colors.transparent, child: receiptWidget),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      try {
        final boundary = repaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) {
          completer.completeError('No boundary');
          return;
        }
        final img = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        completer.complete(byteData!.buffer.asUint8List());
      } catch (e) {
        completer.completeError(e);
      } finally {
        entry.remove();
      }
    });

    if (context.mounted) {
      Overlay.of(context).insert(entry);
    } else {
      entry.remove();
      return '';
    }

    final bytes = await completer.future;
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/zakat_receipt_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _sendFamilyReceipt(BuildContext context) async {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF066046)),
                SizedBox(height: 12),
                Text('Membuat struk...', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final filePath = await _buildReceiptForFamily(context);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (filePath.isEmpty) return;
      if (!context.mounted) return;
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'image/png')],
        subject: 'Bukti Zakat Fitrah',
        text: 'Bukti Zakat Fitrah',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat struk gambar.')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Member row inside a family card
// ─────────────────────────────────────────────────────────────────────────────
class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.muzakki});
  final Muzakki muzakki;

  /// Builds a styled thermal-receipt PNG image and returns the temp file path.
  Future<String> _buildFamilyReceiptImage(BuildContext context) async {
    final m = muzakki;
    final provider = context.read<ZakatProvider>();
    final yearId = provider.selectedYear?.id ?? '';
    final yearLabel = provider.selectedYear?.label ?? 'Zakat Fitrah';

    final now = DateTime.now();
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    final tanggal = '${now.day} ${months[now.month]} ${now.year}';

    // ── Fetch family resume ───────────────────────────────────────────
    String headName = m.fullName;
    String amilName = m.amilName.isNotEmpty ? m.amilName : '—';
    final List<Map<String, dynamic>> paidMembers = [];

    // ── Read org/location from already-loaded ConfigurationProvider ───
    final cfgs2 = context.read<ConfigurationProvider>().configurations;
    String cfgVal2(String code) => cfgs2
        .firstWhere((c) => c.code == code,
            orElse: () => const AppConfiguration(oid: '', module: '', code: ''))
        .value
        .trim();
    final orgName = cfgVal2('GROUP');
    final location = cfgVal2('LOCATION');
    final locationAddr = cfgVal2('LOCATION_ADDR');

    if (m.familyId.isNotEmpty && yearId.isNotEmpty) {
      try {
        final api = ApiService();
        final resp = await api.getFamilyZakatResume(
          m.familyId,
          yearId: yearId,
        );
        final data = resp.data is Map<String, dynamic>
            ? resp.data as Map<String, dynamic>
            : <String, dynamic>{};
        headName = data['head_name'] as String? ?? headName;

        final members = data['members'] as List<dynamic>? ?? [];
        for (final raw in members) {
          final member = raw as Map<String, dynamic>;
          debugPrint(
              '[receipt] member keys: ${member.keys.toList()}  name=${member['name']}  full_name=${member['full_name']}  first_name=${member['first_name']}');
          if (member['is_paid'] == true) {
            // Name: try common flat-field names first, then fall back to
            // Muzakki.fromJson which combines first_name + last_name.
            final rawName = (member['name'] as String?)?.trim() ??
                (member['full_name'] as String?)?.trim() ??
                (member['member_name'] as String?)?.trim() ??
                '';
            final mz = Muzakki.fromJson(member);
            final resolvedName = rawName.isNotEmpty ? rawName : mz.fullName;

            // Payment figures: the family-resume endpoint returns these as
            // flat fields directly on the member object (not nested inside
            // transaction.payment_breakdown), so read them from raw.
            final rawType = member['payment_type'] as String? ?? '';
            final isRice = rawType == 'rice';
            final rawQty =
                (member['quantity'] as num?)?.toDouble() ?? mz.amountSo;
            final rawAmt = () {
              final a = member['amount'];
              if (a is num) return a.toDouble();
              return double.tryParse(a?.toString() ?? '') ?? mz.amountRp;
            }();

            paidMembers.add({
              'name': resolvedName,
              'payment_type': isRice ? 'rice' : 'money',
              'quantity': rawQty,
              'amount': rawAmt,
            });
          }
        }
      } catch (e) {
        debugPrint('_buildFamilyReceiptText error: $e');
      }
    }

    // ── Aggregate totals ──────────────────────────────────────────────
    double totalSo = 0;
    double totalRp = 0;
    for (final member in paidMembers) {
      final type = member['payment_type'] as String? ?? '';
      if (type == 'rice') {
        totalSo += (member['quantity'] as num?)?.toDouble() ?? 0;
      } else if (type == 'money') {
        final amt = member['amount'];
        totalRp += amt is num
            ? amt.toDouble()
            : double.tryParse(amt?.toString() ?? '') ?? 0;
      }
    }

    // ── Format totals ─────────────────────────────────────────────────
    String fmtRp(double v) => v.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1] ?? ''}.');

    String sejumlah;
    if (totalRp > 0 && totalSo > 0) {
      final soStr = totalSo % 1 == 0
          ? totalSo.toInt().toString()
          : totalSo.toStringAsFixed(2);
      sejumlah = 'Sejumlah Rp. ${fmtRp(totalRp)} dan $soStr So beras.';
    } else if (totalRp > 0) {
      sejumlah = 'Sejumlah Rp. ${fmtRp(totalRp)}.';
    } else if (totalSo > 0) {
      final soStr = totalSo % 1 == 0
          ? totalSo.toInt().toString()
          : totalSo.toStringAsFixed(2);
      sejumlah = 'Sejumlah $soStr So beras.';
    } else {
      sejumlah = paidMembers.isEmpty ? '(tidak ada data)' : 'Sejumlah —.';
    }

    final jiwa = paidMembers.length;

    // ── Render receipt widget → PNG ───────────────────────────────────
    final repaintKey = GlobalKey();
    final receiptWidget = RepaintBoundary(
      key: repaintKey,
      child: _ReceiptCard(
        yearLabel: yearLabel,
        headName: headName,
        jiwa: jiwa,
        sejumlah: sejumlah,
        amilName: amilName,
        tanggal: tanggal,
        paidMembers: paidMembers,
        orgName: orgName,
        location: location,
        locationAddr: locationAddr,
      ),
    );

    // Mount off-screen using OverlayEntry, then capture
    late OverlayEntry entry;
    final overlayCompleter = Completer<Uint8List>();

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -5000,
        top: -5000,
        width: 360,
        child: Material(color: Colors.transparent, child: receiptWidget),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait one extra frame so the widget is laid out
      await Future<void>.delayed(const Duration(milliseconds: 120));
      try {
        final boundary = repaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) {
          overlayCompleter.completeError('No boundary');
          return;
        }
        final img = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        overlayCompleter.complete(byteData!.buffer.asUint8List());
      } catch (e) {
        overlayCompleter.completeError(e);
      } finally {
        entry.remove();
      }
    });

    if (context.mounted) {
      Overlay.of(context).insert(entry);
    } else {
      entry.remove();
      return '';
    }

    final bytes = await overlayCompleter.future;
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/zakat_receipt_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<ZakatProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Muzakki'),
        content: Text(
          'Hapus "${muzakki.fullName}" dari daftar? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await provider.deleteMuzakki(muzakki.id);
    }
  }

  Future<void> _showActions(BuildContext context) async {
    final provider = context.read<ZakatProvider>();
    final m = muzakki;

    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                m.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            const Divider(height: 1),
            // Edit
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined,
                    color: Color(0xFF1D4ED8), size: 18),
              ),
              title: const Text('Edit Data',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            // Set as Family Head (hidden if already KK)
            if (!m.isHeadOfFamily)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.star_outline_rounded,
                      color: Color(0xFFE65100), size: 18),
                ),
                title: const Text('Jadikan Kepala Keluarga',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Gantikan KK saat ini',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                onTap: () => Navigator.pop(ctx, 'set_head'),
              ),
            // Correct a mistaken akad
            if (m.isPaid && m.isSerahTerimaAmil)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.replay_rounded,
                      color: Color(0xFFD97706), size: 18),
                ),
                title: const Text('Koreksi: Tandai Belum Akad',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Untuk memperbaiki salah input akad',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                onTap: () => Navigator.pop(ctx, 'cancel_akad'),
              ),
            // Delete
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Color(0xFFDC2626), size: 18),
              ),
              title: const Text('Hapus',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    switch (action) {
      case 'edit':
        context.push('/zakat-fitrah/add?family_id=${m.familyId}', extra: m);
        break;
      case 'set_head':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Ganti Kepala Keluarga'),
            content: Text(
              'Jadikan "${m.fullName}" sebagai kepala keluarga baru?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ya, Jadikan KK',
                    style: TextStyle(color: Color(0xFFE65100))),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          await provider.setFamilyHead(m.id);
        }
        break;
      case 'delete':
        await _confirmDelete(context);
        break;
      case 'cancel_akad':
        final confirmCancel = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Tandai Belum Akad'),
            content: Text(
              'Ubah status "${m.fullName}" menjadi belum akad? '
              'Gunakan ini hanya untuk memperbaiki kesalahan input.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ya, Ubah',
                    style: TextStyle(color: Color(0xFFD97706))),
              ),
            ],
          ),
        );
        if (confirmCancel == true && context.mounted) {
          try {
            await ApiService().patchZakatMuzakkiAkad(m.id, status: false);
            if (context.mounted) await provider.fetchMuzakki();
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gagal mengubah status akad.')),
              );
            }
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = muzakki;
    final isSerah = m.isSerahTerimaAmil;

    final handoverBg = !m.isPaid
        ? const Color(0xFFFEE2E2)
        : isSerah
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFFF3E0);
    final handoverFg = !m.isPaid
        ? const Color(0xFFDC2626)
        : isSerah
            ? const Color(0xFF16A34A)
            : const Color(0xFFD97706);
    final handoverLabel = !m.isPaid
        ? 'Belum Setor'
        : isSerah
            ? (m.amilName.isNotEmpty ? 'Selesai · ${m.amilName}' : 'Selesai')
            : 'Belum Akad Amil';

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Container(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              // Name + relationship
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.fullName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (m.isHeadOfFamily) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded,
                              size: 13, color: Color(0xFFE65100)),
                        ],
                        if (!m.isInternal) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.public_rounded,
                              size: 13, color: Color(0xFF7E22CE)),
                        ],
                      ],
                    ),
                    if (m.relationship.isNotEmpty)
                      Text(
                        m.relationship,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
              ),

              // Right badges (compact, overflow-safe)
              SizedBox(
                width: 118,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Badge(
                      label: handoverLabel,
                      bg: handoverBg,
                      fg: handoverFg,
                      icon:
                          isSerah ? Icons.verified_rounded : Icons.info_outline,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: m.isPaid
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: m.isPaid
                              ? Text(
                                  m.paymentType == PaymentType.uang
                                      ? '💵'
                                      : '🌾',
                                  style: const TextStyle(fontSize: 12),
                                )
                              : const Text(
                                  '⋯',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact action icon button
// ─────────────────────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Family payment badge
// ─────────────────────────────────────────────────────────────────────────────
class _PaidBadge extends StatelessWidget {
  const _PaidBadge(
      {required this.allPaid, required this.anyPaid, required this.summary});
  final bool allPaid;
  final bool anyPaid;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    if (allPaid) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
      label = '✓ Sudah Setor';
    } else if (anyPaid) {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFD97706);
      label = '~ $summary';
    } else {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = '⋯ Belum Setor';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact stat (top bar)
// ─────────────────────────────────────────────────────────────────────────────
class _StatCompactItem extends StatelessWidget {
  const _StatCompactItem({
    required this.value,
    required this.label,
    required this.color,
    this.isActive = false,
    this.onTap,
  });

  final String value;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.15) : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: color, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.activeColor = const Color(0xFF066046),
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? activeColor : const Color(0xFFF4F7F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info badge
// ─────────────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  const _Badge(
      {required this.label, required this.bg, required this.fg, this.icon});
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Receipt card widget — rendered off-screen then captured as PNG
// ─────────────────────────────────────────────────────────────────────────────
class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.yearLabel,
    required this.headName,
    required this.jiwa,
    required this.sejumlah,
    required this.amilName,
    required this.tanggal,
    required this.paidMembers,
    this.orgName = '',
    this.location = '',
    this.locationAddr = '',
  });

  final String yearLabel;
  final String headName;
  final int jiwa;
  final String sejumlah;
  final String amilName;
  final String tanggal;
  final List<Map<String, dynamic>> paidMembers;
  final String orgName;
  final String location;
  final String locationAddr;

  static const _green = Color(0xFF066046);
  static const _lightGreen = Color(0xFFE8F5F0);
  static const _textDark = Color(0xFF1A1A1A);
  static const _textMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Green header ──────────────────────────────────────────────
          Container(
            color: _green,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo — centered at top
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/icon/img_mbl.jpg',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                // Title
                const Text(
                  'BUKTI ZAKAT FITRAH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  yearLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
                // Org / location block — only shown when non-empty
                if (orgName.isNotEmpty ||
                    location.isNotEmpty ||
                    locationAddr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (orgName.isNotEmpty)
                          Text(
                            orgName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        if (location.isNotEmpty) ...[
                          if (orgName.isNotEmpty) const SizedBox(height: 1),
                          Text(
                            location,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ],
                        if (locationAddr.isNotEmpty)
                          Text(
                            locationAddr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                      ], // end inner Column children
                    ), // end inner Column
                  ), // end Container (semi-transparent box)
                ], // end outer if spread
              ], // end outer Column children
            ), // end outer Column
          ),

          // ── Body ─────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _separator(),
                _row('Diterima dari', headName),
                _row('Jumlah jiwa', '$jiwa jiwa'),
                _row('Sejumlah', sejumlah),
                _row('Diterima oleh', amilName),
                _row('Tanggal', tanggal),
                _separator(),

                // ── Member list ─────────────────────────────────────
                if (paidMembers.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Rincian Anggota:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...paidMembers.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final mem = e.value;
                    final name = mem['name'] as String? ?? '—';
                    final type = mem['payment_type'] as String? ?? '';
                    String detail;
                    if (type == 'rice') {
                      final qty = mem['quantity'];
                      detail = '${qty ?? '—'} So beras';
                    } else {
                      final amt = mem['amount'];
                      final v = amt is num ? amt.toInt() : 0;
                      final formatted = v.toString().replaceAllMapped(
                          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                          (m) => '${m[1]!}.');
                      detail = 'Rp. $formatted';
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text(
                              '$idx.',
                              style: const TextStyle(
                                  fontSize: 11, color: _textMuted),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                  fontSize: 11, color: _textDark),
                            ),
                          ),
                          Text(
                            detail,
                            style:
                                const TextStyle(fontSize: 11, color: _textDark),
                          ),
                        ],
                      ),
                    );
                  }),
                  _separator(),
                ],

                // ── Closing dua ────────────────────────────────────
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'تَقَبَّلَ اللهُ مِنَّا وَمِنْكُمْ\n'
                    'Semoga Allah menerima amal ibadah kita\n'
                    'dan menjadikannya berkah. Aamiin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: _green,
                      height: 1.7,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dashed separator line
  Widget _separator() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (_, constraints) {
            final dashCount = (constraints.maxWidth / 8).floor();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                dashCount,
                (_) => Container(
                  width: 5,
                  height: 1,
                  color: const Color(0xFFCBD5E1),
                ),
              ),
            );
          },
        ),
      );

  /// Two-column label / value row
  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: _textMuted),
              ),
            ),
            const Text(': ', style: TextStyle(fontSize: 12, color: _textMuted)),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
            ),
          ],
        ),
      );
}

class _BulkImportResult {
  const _BulkImportResult({required this.success, required this.failed});

  final int success;
  final int failed;
}

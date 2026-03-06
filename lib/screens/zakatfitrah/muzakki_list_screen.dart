import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/muzakki.dart';
import '../../providers/zakat_provider.dart';
import '../../services/api_service.dart';

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
  String get afiliasi => head?.afiliasi ?? '';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ZakatProvider>();
      if (p.muzakkiList.isEmpty && !p.isLoading) p.fetchMuzakki();
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
                m.groupName.toLowerCase().contains(q);
          });

      final matchGroup = _filterGroup == null ||
          g.members.any((m) => m.groupName == _filterGroup);

      final matchPaid =
          _filterPaid == null || (_filterPaid == true ? g.anyPaid : g.nonePaid);

      final matchAmilPending = !_filterAmilPending ||
          g.members.any((m) => m.isPaid && !m.isSerahTerimaAmil);

      return matchSearch && matchGroup && matchPaid && matchAmilPending;
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
      'family_id',
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
      '',
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
      '4) family_id kosong = keluarga baru, isi family_id = gabung keluarga',
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

      for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        final firstName = val(row, 'first_name');
        final lastName = val(row, 'last_name');
        final surname = val(row, 'surname');
        final sex = _parseSex(val(row, 'sex'));
        final relationship = val(row, 'relationship');
        final isHead = _parseBool(val(row, 'is_head_of_family'));
        final isInternal =
            _parseBool(val(row, 'is_internal'), defaultValue: true);
        final familyId = val(row, 'family_id');
        final address = val(row, 'address');
        final phone = val(row, 'phone');
        final groupName = val(row, 'group_name');

        final isEmptyRow = [
          firstName,
          lastName,
          surname,
          val(row, 'sex'),
          relationship,
          familyId,
          address,
          phone,
          groupName,
        ].every((v) => v.isEmpty);
        if (isEmptyRow) continue;

        if (firstName.isEmpty) {
          skippedCount++;
          continue;
        }

        bulkRows.add({
          'first_name': firstName,
          'last_name': lastName,
          'surname': surname,
          'sex': sex,
          'relationship': relationship,
          'is_head_of_family': isHead,
          'is_internal': isInternal,
          'family_id': familyId,
          'address': address,
          'phone': phone,
          'group_name': groupName,
        });
      }

      if (bulkRows.isEmpty) {
        throw Exception('Tidak ada baris valid untuk diimport.');
      }

      final api = ApiService();
      final response = await api.createMuzakkiBulk(
        yearId: yearId,
        muzakkis: bulkRows,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import gagal: $e')),
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
        final groupNames = _groups(allMuzakki);

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
                    const SizedBox(height: 8),

                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _Chip(
                            label: 'Semua',
                            isActive: _filterPaid == null &&
                                _filterGroup == null &&
                                !_filterAmilPending,
                            onTap: () => setState(() {
                              _filterPaid = null;
                              _filterGroup = null;
                              _filterAmilPending = false;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _Chip(
                            label: '⏳ Belum Setor Zakat ($unpaidCount)',
                            isActive: _filterPaid == false,
                            activeColor: const Color(0xFFDC2626),
                            onTap: () => setState(() {
                              _filterPaid = _filterPaid == false ? null : false;
                              _filterGroup = null;
                              _filterAmilPending = false;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _Chip(
                            label: '✅ Sudah Setor Zakat ($paidCount)',
                            isActive: _filterPaid == true,
                            activeColor: const Color(0xFF16A34A),
                            onTap: () => setState(() {
                              _filterPaid = _filterPaid == true ? null : true;
                              _filterGroup = null;
                              _filterAmilPending = false;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _Chip(
                            label:
                                '🧾 Belum Akad dengan Amil ($amilPendingCount)',
                            isActive: _filterAmilPending,
                            activeColor: const Color(0xFFD97706),
                            onTap: () => setState(() {
                              _filterAmilPending = !_filterAmilPending;
                              _filterPaid = null;
                              _filterGroup = null;
                            }),
                          ),
                          ...groupNames.map((g) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _Chip(
                                  label: g,
                                  isActive: _filterGroup == g,
                                  onTap: () => setState(() {
                                    _filterGroup = _filterGroup == g ? null : g;
                                    _filterPaid = null;
                                    _filterAmilPending = false;
                                  }),
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
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
                        label: 'KK',
                        color: _green,
                      ),
                      _StatCompactItem(
                        value: '$paidCount',
                        label: 'Setor',
                        color: const Color(0xFF16A34A),
                      ),
                      _StatCompactItem(
                        value: '$unpaidCount',
                        label: 'Belum',
                        color: const Color(0xFFDC2626),
                      ),
                      _StatCompactItem(
                        value: '$amilPendingCount',
                        label: 'Belum Akad',
                        color: const Color(0xFFD97706),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Family list ───────────────────────────────────────────
              Expanded(
                child: groups.isEmpty
                    ? _emptyState(allMuzakki.isEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: groups.length,
                        itemBuilder: (context, i) =>
                            _FamilyCard(group: groups[i]),
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
  const _FamilyCard({required this.group});
  final _FamilyGroup group;

  @override
  State<_FamilyCard> createState() => _FamilyCardState();
}

class _FamilyCardState extends State<_FamilyCard> {
  bool _expanded = true;

  static const _green = Color(0xFF066046);

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final externalSoulsCount = context.select<ZakatProvider, int>(
      (p) => p.getExternalByFamilyId(g.familyId)?.externalTotalSouls ?? 0,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: g.allPaid
              ? const Color(0xFFBBF7D0)
              : g.anyPaid
                  ? const Color(0xFFFED7AA)
                  : const Color(0xFFFEE2E2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Family header ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Family info (tappable — expand/collapse)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  g.familyName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 4,
                            runSpacing: 3,
                            children: [
                              _Badge(
                                label: '${g.memberCount} jiwa',
                                bg: const Color(0xFFEFF6FF),
                                fg: const Color(0xFF1D4ED8),
                                icon: Icons.people_alt_outlined,
                              ),
                              if (externalSoulsCount > 0)
                                _Badge(
                                  label: '+$externalSoulsCount ext',
                                  bg: const Color(0xFFF3E8FF),
                                  fg: const Color(0xFF7E22CE),
                                  icon: Icons.group_add_outlined,
                                ),
                              if (g.groupName.isNotEmpty)
                                _Badge(
                                  label: g.groupName,
                                  bg: const Color(0xFFF8FAFC),
                                  fg: const Color(0xFF64748B),
                                  icon: Icons.group_outlined,
                                ),
                              if (g.afiliasi.isNotEmpty)
                                _Badge(
                                  label: g.afiliasi,
                                  bg: const Color(0xFFFAF5FF),
                                  fg: const Color(0xFF9333EA),
                                  icon: Icons.handshake_outlined,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Akad icon button (visible when ≥1 member paid)
                  if (g.anyPaid) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showAkadDialog(context),
                      child: Tooltip(
                        message: 'Akad ke Amil',
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.handshake_outlined,
                            size: 16,
                            color: _green,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Payment badge + expand arrow (tappable)
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _PaidBadge(
                          allPaid: g.allPaid,
                          anyPaid: g.anyPaid,
                          summary: g.paymentSummary,
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

    try {
      final api = ApiService();
      final yearId = provider.selectedYear?.id ?? '';
      final resp = await api.getZakatAmilList(
        yearId: yearId.isNotEmpty ? yearId : null,
      );
      final raw = resp.data;
      final list = raw is List
          ? raw
          : (raw as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
      amilList = list
          .map((j) => _Amil.fromJson(j as Map<String, dynamic>))
          .where((a) => a.id.isNotEmpty && a.name.isNotEmpty)
          .toList();
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
          content: Column(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                              margin: const EdgeInsets.only(top: 10, bottom: 8),
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
                                      backgroundColor: const Color(0xFFE8F5F0),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed:
                  selectedAmil == null ? null : () => Navigator.pop(ctx, true),
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
          debugPrint('[receipt] member keys: ${member.keys.toList()}  name=${member['name']}  full_name=${member['full_name']}  first_name=${member['first_name']}');
          if (member['is_paid'] == true) {
            // Name: try common flat-field names first, then fall back to
            // Muzakki.fromJson which combines first_name + last_name.
            final rawName = (member['name'] as String?)?.trim() ??
                (member['full_name'] as String?)?.trim() ??
                (member['member_name'] as String?)?.trim() ??
                '';
            final mz = Muzakki.fromJson(member);
            final resolvedName =
                rawName.isNotEmpty ? rawName : mz.fullName;

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
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => (m[1] ?? '') + '.');

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
            // Kirim Bukti Zakat (only for paid)
            if (m.isPaid)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: Color(0xFF066046), size: 18),
                ),
                title: const Text('Kirim Bukti Zakat',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Bagikan ke WhatsApp atau lainnya',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                onTap: () => Navigator.pop(ctx, 'receipt'),
              ),
            // Bayar Zakat / Edit Bayar Zakat
            m.isPaid
                ? ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_note_rounded,
                          color: Color(0xFF066046), size: 18),
                    ),
                    title: const Text('Edit Bayar Zakat',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Ubah data transaksi pembayaran',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    onTap: () => Navigator.pop(ctx, 'pay'),
                  )
                : ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.payment_rounded,
                          color: Color(0xFF066046), size: 18),
                    ),
                    title: const Text('Bayar Zakat',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Input transaksi pembayaran',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    onTap: () => Navigator.pop(ctx, 'pay'),
                  ),
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
      case 'pay':
        context.go('/zakat-fitrah/transaction', extra: m);
        break;
      case 'receipt':
        if (!context.mounted) break;
        // Show loading while capturing
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
          final filePath = await _buildFamilyReceiptImage(context);
          if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
          if (filePath.isEmpty) break;
          if (!context.mounted) break;
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
        break;
      case 'delete':
        await _confirmDelete(context);
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
            ? (m.amilName.isNotEmpty ? '✓ ${m.amilName}' : 'Sudah Akad Amil')
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
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
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
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
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
  });

  final String yearLabel;
  final String headName;
  final int jiwa;
  final String sejumlah;
  final String amilName;
  final String tanggal;
  final List<Map<String, dynamic>> paidMembers;

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
            padding:
                const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              children: [
                const Text('☪',
                    style: TextStyle(fontSize: 30, color: Colors.white)),
                const SizedBox(height: 6),
                const Text(
                  'BUKTI ZAKAT FITRAH',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  yearLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
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
                            style: const TextStyle(
                                fontSize: 11, color: _textDark),
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
            const Text(': ',
                style: TextStyle(fontSize: 12, color: _textMuted)),
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

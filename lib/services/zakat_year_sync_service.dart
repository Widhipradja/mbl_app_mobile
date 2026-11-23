import 'dart:math';

import '../models/app_configuration.dart';
import '../models/muzakki.dart';
import '../models/zakat_distribution.dart';
import '../models/zakat_year.dart';
import '../providers/configuration_provider.dart';
import 'api_service.dart';

/// What can be copied from a previous Zakat year into another one.
enum YearSyncItem {
  yearSettings(
      'Konfigurasi Zakat Fitrah', 'Tarif beras, group, titip uang & ikrar'),
  muzakki('Muzakki', 'Keluarga & anggota (status bayar/akad tidak ikut)'),
  mustahiq('Mustahiq', 'Nama, asnaf & jumlah jiwa'),
  asnafBobot('Master Asnaf & Bobot', 'Tipe asnaf beserta bobotnya'),
  amil('Master Amil', 'Daftar amil'),
  distribution('Konfigurasi Distribusi', 'Struktur & persentase distribusi');

  const YearSyncItem(this.label, this.hint);
  final String label;
  final String hint;
}

class YearSyncResult {
  const YearSyncResult({
    required this.created,
    required this.skipped,
    this.failed = 0,
    this.note = '',
  });

  final int created;

  /// Already present in the target year, so left untouched.
  final int skipped;
  final int failed;
  final String note;

  String get summary {
    if (note.isNotEmpty && created == 0 && failed == 0) return note;
    final parts = <String>['$created ditambahkan'];
    if (skipped > 0) parts.add('$skipped sudah ada');
    if (failed > 0) parts.add('$failed gagal');
    return parts.join(' · ');
  }
}

/// Copies per-year master data from one Zakat year to another using the
/// existing endpoints, so no backend change is required. Every copy is
/// additive and idempotent: rows already in the target year are skipped,
/// nothing is overwritten or deleted (except the two year settings).
class ZakatYearSyncService {
  ZakatYearSyncService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  Future<YearSyncResult> run(
    YearSyncItem item, {
    required ZakatYear source,
    required ZakatYear target,
    String createdBy = '',
  }) {
    switch (item) {
      case YearSyncItem.yearSettings:
        return _syncYearSettings(source, target);
      case YearSyncItem.muzakki:
        return _syncMuzakki(source.id, target.id, createdBy);
      case YearSyncItem.mustahiq:
        return _syncMustahiq(source.id, target.id);
      case YearSyncItem.asnafBobot:
        return _syncAsnafBobot(source.id, target.id);
      case YearSyncItem.amil:
        return _syncAmil(source.id, target.id);
      case YearSyncItem.distribution:
        return _syncDistribution(source.id, target.id);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _list(dynamic raw) {
    dynamic source = raw;
    if (raw is Map<String, dynamic> && raw['data'] != null) {
      source = raw['data'];
    }
    if (source is List) {
      return source.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  /// Rows whose `year_id` is present and differs are dropped, in case the
  /// backend ignores the `year_id` filter.
  List<Map<String, dynamic>> _forYear(
      List<Map<String, dynamic>> rows, String yearId) {
    return rows.where((r) {
      final y = r['year_id']?.toString() ?? '';
      return y.isEmpty || y == yearId;
    }).toList();
  }

  String _norm(String s) => s.trim().toLowerCase();

  String _newFamilyId() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  // ── Year settings ────────────────────────────────────────────────────────

  Future<YearSyncResult> _syncYearSettings(
      ZakatYear source, ZakatYear target) async {
    var created = 0;
    var failed = 0;

    // 1. Rice rate + group on the year itself. Dates, label and status stay
    //    as the target year has them.
    final rate = source.riceRatePerSo;
    if (target.riceRatePerSo != rate || target.groupName != source.groupName) {
      try {
        await _api.updateZakatYear(target.id, {
          'hijri_year': target.hijriYear,
          'label': target.label,
          'ramadhan_start':
              target.ramadhanStart.isEmpty ? null : target.ramadhanStart,
          'ramadhan_end':
              target.ramadhanEnd.isEmpty ? null : target.ramadhanEnd,
          'rice_rate_per_so':
              rate % 1 == 0 ? rate.toStringAsFixed(0) : rate.toStringAsFixed(2),
          'group_name': source.groupName,
          'is_active': target.isActive,
        });
        created++;
      } catch (_) {
        failed++;
      }
    }

    // 2. Per-year configuration values (titip uang, ikrar): copy the source
    //    year's own value unless the target year already has one.
    try {
      final rows = await Future.wait([
        _configRows(source.id),
        _configRows(target.id),
      ]);
      final targetHas = rows[1]
          .where((c) => c.yearId == target.id)
          .map((c) => c.code)
          .toSet();
      for (final c in rows[0].where((c) => c.yearId == source.id)) {
        if (!ConfigurationProvider.perYearCodes.contains(c.code)) continue;
        if (targetHas.contains(c.code)) continue;
        try {
          await _api.createConfiguration(
              c.copyWith(oid: '', yearId: target.id).toCreateJson());
          created++;
        } catch (_) {
          failed++;
        }
      }
    } catch (_) {
      failed++;
    }

    if (created == 0 && failed == 0) {
      return const YearSyncResult(
          created: 0, skipped: 0, note: 'Sudah sama dengan tahun sumber');
    }
    return YearSyncResult(created: created, skipped: 0, failed: failed);
  }

  Future<List<AppConfiguration>> _configRows(String yearId) async {
    final resp = await _api.getConfigurationsByModule(
        ConfigurationProvider.moduleZakatFitrah,
        yearId: yearId);
    return _list(resp.data).map(AppConfiguration.fromJson).toList();
  }

  // ── Muzakki ──────────────────────────────────────────────────────────────

  Future<List<Muzakki>> _fetchMuzakki(String yearId) async {
    final resp = await _api.getZakatMuzakkiStatus(yearId, limit: 5000);
    final body = resp.data;
    final raw = body is Map<String, dynamic> ? body['data'] : body;
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Muzakki.fromJson)
        .where((m) => m.yearId.isEmpty || m.yearId == yearId)
        .toList();
  }

  String _personKey(Muzakki m) =>
      '${_norm(m.firstName)}|${_norm(m.lastName)}|${_norm(m.surname)}';

  Future<YearSyncResult> _syncMuzakki(
      String sourceId, String targetId, String createdBy) async {
    final results = await Future.wait([
      _fetchMuzakki(sourceId),
      _fetchMuzakki(targetId),
    ]);
    final source = results[0];
    final existing = results[1].map(_personKey).toSet();

    // Keep families together; the head goes first.
    final families = <String, List<Muzakki>>{};
    for (final m in source) {
      families.putIfAbsent(m.familyId.isEmpty ? m.id : m.familyId, () => []);
      families[m.familyId.isEmpty ? m.id : m.familyId]!.add(m);
    }

    final rows = <Map<String, dynamic>>[];
    var skipped = 0;
    for (final members in families.values) {
      members.sort((a, b) =>
          (b.isHeadOfFamily ? 1 : 0).compareTo(a.isHeadOfFamily ? 1 : 0));
      final fresh = members.where((m) => !existing.contains(_personKey(m)));
      skipped += members.length - fresh.length;
      if (fresh.isEmpty) continue;

      final familyId = _newFamilyId();
      final hasHead = fresh.any((m) => m.isHeadOfFamily);
      var first = true;
      for (final m in fresh) {
        rows.add({
          'first_name': m.firstName,
          if (m.lastName.isNotEmpty) 'last_name': m.lastName,
          if (m.surname.isNotEmpty) 'surname': m.surname,
          'sex': m.sex,
          if (m.relationship.isNotEmpty) 'relationship': m.relationship,
          // A family that lost its head to the skip rule still needs one.
          'is_head_of_family': m.isHeadOfFamily || (!hasHead && first),
          'is_internal': m.isInternal,
          'family_id': familyId,
          if (m.address.isNotEmpty) 'address': m.address,
          if (m.phone.isNotEmpty) 'phone': m.phone,
          if (m.groupName.isNotEmpty) 'group_name': m.groupName,
          // Internal members have no external; the BE rejects one.
          if (!m.isInternal && m.externalId.isNotEmpty)
            'external_id': m.externalId,
        });
        first = false;
      }
    }

    if (rows.isEmpty) {
      return YearSyncResult(
        created: 0,
        skipped: skipped,
        note: source.isEmpty
            ? 'Tahun sumber belum punya muzakki'
            : 'Semua muzakki sudah ada',
      );
    }

    // Chunked so one bad row can't sink a very large request.
    var created = 0;
    var failed = 0;
    for (var i = 0; i < rows.length;) {
      var end = min(i + 100, rows.length);
      // Never split a family across two requests.
      while (end < rows.length &&
          rows[end]['family_id'] == rows[end - 1]['family_id']) {
        end++;
      }
      final chunk = rows.sublist(i, end);
      try {
        await _api.createMuzakkiBulk(
          yearId: targetId,
          muzakkis: chunk,
          createdBy: createdBy,
          updatedBy: createdBy,
        );
        created += chunk.length;
      } catch (_) {
        failed += chunk.length;
      }
      i = end;
    }
    return YearSyncResult(created: created, skipped: skipped, failed: failed);
  }

  // ── Mustahiq ─────────────────────────────────────────────────────────────

  Future<YearSyncResult> _syncMustahiq(String sourceId, String targetId) async {
    final results = await Future.wait([
      _api.getZakatMustahiq(yearId: sourceId),
      _api.getZakatMustahiq(yearId: targetId),
    ]);
    final source = _forYear(_list(results[0].data), sourceId);
    final existing = _forYear(_list(results[1].data), targetId)
        .map((r) =>
            '${_norm(r['name']?.toString() ?? '')}|${_norm(r['asnaf_type']?.toString() ?? '')}')
        .toSet();

    var created = 0, skipped = 0, failed = 0;
    for (final r in source) {
      final name = r['name']?.toString().trim() ?? '';
      final type = r['asnaf_type']?.toString().trim() ?? '';
      if (name.isEmpty || type.isEmpty) continue;
      if (existing.contains('${_norm(name)}|${_norm(type)}')) {
        skipped++;
        continue;
      }
      try {
        await _api.createZakatMustahiq(
          yearId: targetId,
          name: name,
          asnafType: type,
          souls: int.tryParse(r['souls']?.toString() ?? '') ?? 0,
        );
        created++;
      } catch (_) {
        failed++;
      }
    }
    return YearSyncResult(
      created: created,
      skipped: skipped,
      failed: failed,
      note: source.isEmpty ? 'Tahun sumber belum punya mustahiq' : '',
    );
  }

  // ── Asnaf & bobot ────────────────────────────────────────────────────────

  Future<YearSyncResult> _syncAsnafBobot(
      String sourceId, String targetId) async {
    final results = await Future.wait([
      _api.getZakatAsnafBobot(yearId: sourceId),
      _api.getZakatAsnafBobot(yearId: targetId),
    ]);
    final source = _forYear(_list(results[0].data), sourceId);
    final existing = _forYear(_list(results[1].data), targetId)
        .map((r) => _norm(r['asnaf_type']?.toString() ?? ''))
        .toSet();

    var created = 0, skipped = 0, failed = 0;
    for (final r in source) {
      final type = _norm(r['asnaf_type']?.toString() ?? '');
      if (type.isEmpty) continue;
      if (existing.contains(type)) {
        skipped++;
        continue;
      }
      try {
        await _api.createZakatAsnafBobot({
          'year_id': targetId,
          'asnaf_type': type,
          'bobot': double.tryParse(r['bobot']?.toString() ?? '') ?? 1,
          'notes': r['notes']?.toString() ?? '',
        });
        created++;
      } catch (_) {
        failed++;
      }
    }
    return YearSyncResult(
      created: created,
      skipped: skipped,
      failed: failed,
      note: source.isEmpty ? 'Tahun sumber belum punya asnaf & bobot' : '',
    );
  }

  // ── Amil ─────────────────────────────────────────────────────────────────

  Future<YearSyncResult> _syncAmil(String sourceId, String targetId) async {
    final results = await Future.wait([
      _api.getZakatAmilList(yearId: sourceId),
      _api.getZakatAmilList(yearId: targetId),
    ]);
    final source = _forYear(_list(results[0].data), sourceId);
    final existing = _forYear(_list(results[1].data), targetId)
        .map((r) => _norm(r['name']?.toString() ?? ''))
        .toSet();

    var created = 0, skipped = 0, failed = 0;
    for (final r in source) {
      final name = r['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      if (existing.contains(_norm(name))) {
        skipped++;
        continue;
      }
      try {
        await _api.createZakatAmil({
          'year_id': targetId,
          'name': name,
          'group_name': r['group_name']?.toString() ?? '',
          'notes': r['notes']?.toString() ?? '',
          'is_active': r['is_active'] as bool? ?? true,
        });
        created++;
      } catch (_) {
        failed++;
      }
    }
    return YearSyncResult(
      created: created,
      skipped: skipped,
      failed: failed,
      note: source.isEmpty ? 'Tahun sumber belum punya amil' : '',
    );
  }

  // ── Distribution tree ────────────────────────────────────────────────────

  Future<List<ZakatDistribution>> _fetchDistributions(String yearId) async {
    final resp = await _api.getZakatDistributions(yearId: yearId);
    return _forYear(_list(resp.data), yearId)
        .map(ZakatDistribution.fromJson)
        .toList();
  }

  String? _createdId(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      if (inner is Map<String, dynamic>) {
        return (inner['id'] ?? inner['oid'])?.toString();
      }
      return (raw['id'] ?? raw['oid'])?.toString();
    }
    return null;
  }

  Future<YearSyncResult> _syncDistribution(
      String sourceId, String targetId) async {
    final results = await Future.wait([
      _fetchDistributions(sourceId),
      _fetchDistributions(targetId),
    ]);
    final source = results[0];
    final target = results[1];
    if (source.isEmpty) {
      return const YearSyncResult(
          created: 0,
          skipped: 0,
          note: 'Tahun sumber belum punya konfigurasi distribusi');
    }
    // The tree only has meaning as a whole (percentages per level), so merging
    // into a half-filled tree would be guesswork.
    if (target.isNotEmpty) {
      final n = target.fold<int>(0, (s, d) => s + d.flatten().length);
      return YearSyncResult(
        created: 0,
        skipped: n,
        note: 'Tahun ini sudah punya distribusi — tidak ditimpa',
      );
    }

    var created = 0, failed = 0;
    Future<void> copy(ZakatDistribution node, String? parentId) async {
      String? newId;
      try {
        final resp = await _api.createZakatDistribution({
          'year_id': targetId,
          'name': node.name,
          'percentage': node.percentage,
          'notes': node.notes,
          if (parentId != null) 'parent_id': parentId,
        });
        newId = _createdId(resp.data);
        created++;
      } catch (_) {
        failed += node.flatten().length;
        return;
      }
      if (node.children.isEmpty) return;
      if (newId == null || newId.isEmpty) {
        failed += node.children.fold<int>(0, (s, c) => s + c.flatten().length);
        return;
      }
      for (final child in node.children) {
        await copy(child, newId);
      }
    }

    for (final root in source) {
      await copy(root, null);
    }
    return YearSyncResult(created: created, skipped: 0, failed: failed);
  }
}

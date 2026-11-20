import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/muzakki.dart';
import '../../providers/zakat_provider.dart';

/// Laporan tab body — body-only widget, no Scaffold.
/// Shell (ZakatShellScreen) owns the Scaffold + AppBar.
class LaporanBody extends StatefulWidget {
  const LaporanBody({super.key});

  @override
  State<LaporanBody> createState() => _LaporanBodyState();
}

class _LaporanBodyState extends State<LaporanBody> {
      Map<int, TableColumnWidth> getDistColumnWidths(int amilCount) {
        final map = <int, TableColumnWidth>{
          0: const FixedColumnWidth(130),
          1: const FixedColumnWidth(80),
          2: const FixedColumnWidth(80),
        };
        for (var index = 0; index < amilCount; index++) {
          map[3 + index] = const FixedColumnWidth(90);
        }
        map[3 + amilCount] = const FixedColumnWidth(80);
        map[4 + amilCount] = const FixedColumnWidth(110);
        return map;
      }
    bool _showAdjustment = false;
    bool _showFinal = false;

    Widget _distribusiCombinedTable({
      required List<String> amilChildrenLabels,
      required double sbPercent,
      required double asnafPercent,
      required int kalkulasiJumlah,
      required int kalkulasiSb,
      required List<int> kalkulasiAmilChildren,
      required int kalkulasiAsnaf,
      required int kalkulasiTotal,
      required int finalJumlah,
      required int finalSb,
      required List<int> finalAmilChildren,
      required int finalAsnaf,
      required int finalTotal,
      required bool hasManualOverride,
      double? finalJumlahRp,
      double? finalSbRp,
      List<double>? finalAmilChildrenRp,
      double? finalAsnafRp,
      double? finalTotalRp,
    }) {
      final hasFinalCurrency = finalJumlahRp != null &&
          finalSbRp != null &&
          finalAmilChildrenRp != null &&
          finalAsnafRp != null &&
          finalTotalRp != null;

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Distribusi Zakat',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: getDistColumnWidths(amilChildrenLabels.length),
                  border: const TableBorder(
                    left: BorderSide(color: Color(0xFFCBD5E1)),
                    right: BorderSide(color: Color(0xFFCBD5E1)),
                    bottom: BorderSide(color: Color(0xFFCBD5E1)),
                    horizontalInside: BorderSide(color: Color(0xFFCBD5E1)),
                    verticalInside: BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  children: [
                    _distSubHeaderRow(
                      sbPercent: sbPercent,
                      amilChildren: amilChildrenLabels,
                      asnafPercent: asnafPercent,
                    ),
                    _distDataRow(
                      label: 'Rekapitulasi Kalkulasi',
                      jumlah: kalkulasiJumlah,
                      sb: kalkulasiSb,
                      amilChildren: kalkulasiAmilChildren,
                      asnaf: kalkulasiAsnaf,
                      total: kalkulasiTotal,
                    ),
                    // _distSectionLabelRow(
                    //   label: hasManualOverride
                    //       ? 'Final Distribution (Adjustment Manual)'
                    //       : 'Final Distribution (Mengikuti Kalkulasi)',
                    //   colCount: amilChildrenLabels.length,
                    // ),
                    _distDataRow(
                      label: 'Final Distribution',
                      jumlah: finalJumlah,
                      sb: finalSb,
                      amilChildren: finalAmilChildren,
                      asnaf: finalAsnaf,
                      total: finalTotal,
                      isTotal: true,
                    ),
                    if (hasFinalCurrency)
                      _distCurrencyRow(
                        label: 'Konversi Rupiah (Final)',
                        jumlah: finalJumlahRp,
                        sb: finalSbRp,
                        amilChildren: finalAmilChildrenRp,
                        asnaf: finalAsnafRp,
                        total: finalTotalRp,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _distribusiTable({
      required String title,
      required int jumlah,
      required int sb,
      required List<int> amilChildren,
      required int asnaf,
      required int total,
      required double sbPercent,
      required List<String> amilChildrenLabels,
      required double asnafPercent,
      bool showAdjustment = false,
      bool isFinal = false,
      double? jumlahRp,
      double? sbRp,
      List<double>? amilChildrenRp,
      double? asnafRp,
      double? totalRp,
    }) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  if (showAdjustment || isFinal)
                    IconButton(
                      icon: Icon(
                        (showAdjustment && !_showAdjustment) || (isFinal && !_showFinal)
                            ? Icons.expand_more
                            : Icons.expand_less,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () {
                        setState(() {
                          if (showAdjustment) _showAdjustment = !_showAdjustment;
                          if (isFinal) _showFinal = !_showFinal;
                        });
                      },
                    ),
                ],
              ),
              if (!showAdjustment || _showAdjustment)
                if (!isFinal || _showFinal)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Table(
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      columnWidths: getDistColumnWidths(amilChildrenLabels.length),
                      border: const TableBorder(
                        left: BorderSide(color: Color(0xFFCBD5E1)),
                        right: BorderSide(color: Color(0xFFCBD5E1)),
                        bottom: BorderSide(color: Color(0xFFCBD5E1)),
                        horizontalInside: BorderSide(color: Color(0xFFCBD5E1)),
                        verticalInside: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      children: [
                        _distSubHeaderRow(
                          sbPercent: sbPercent,
                          amilChildren: amilChildrenLabels,
                          asnafPercent: asnafPercent,
                        ),
                        _distDataRow(
                          label: title,
                          jumlah: jumlah,
                          sb: sb,
                          amilChildren: amilChildren,
                          asnaf: asnaf,
                          total: total,
                          isTotal: isFinal,
                        ),
                        if (jumlahRp != null && sbRp != null && amilChildrenRp != null && asnafRp != null && totalRp != null)
                          _distCurrencyRow(
                            label: 'Konversi Rupiah',
                            jumlah: jumlahRp,
                            sb: sbRp,
                            amilChildren: amilChildrenRp,
                            asnaf: asnafRp,
                            total: totalRp,
                          ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      );
    }
  final ApiService _api = ApiService();

  static const _green = Color(0xFF066046);

  double _jatahSb = 40;
  double _jatahAmil = 15;
  double _jatahAsnaf = 45;
  final double _titipUang = 45000;
  List<_AmilChildConfig> _amilChildren = const [];
  String? _sbDistributionId;
  List<String> _asnafDistributionIds = const [];
  List<String> _asnafDistributionLabels = const [];
  Map<String, double> _adjByDistributionId = {};
  final TextEditingController _notesController = TextEditingController();
  bool _isLoadingConfig = false;
  bool _isLoadingMustahiqRecap = false;
  bool _isLoadingVerificationRecap = false;
  String? _configError;
  String? _mustahiqRecapError;
  String? _verificationRecapError;
  String _lastRecapYearId = '';
  String _lastConfigYearId = '';
  String _lastVerificationRecapYearId = '';

  List<_MustahiqRecapRow> _mustahiqRecapRows = const [];
  List<Map<String, dynamic>> _asnafBobotRows = const [];
  _VerificationRecapData? _verificationRecapData;

  // Amil KPI state
  bool _isLoadingAmilKpi = false;
  String? _amilKpiError;
  _AmilKpiData? _amilKpiData;

  // Closing / history state
  bool _isSaving = false;
  String? _saveError;
  bool _isLoadingHistory = false;
  Map<String, dynamic>? _existingHistory;
  String _lastHistoryYearId = '';

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDistributionConfig();
      _loadAdjustments();
    });
  }

  Future<void> _loadHistory(String yearId) async {
    if (yearId.isEmpty) return;
    setState(() {
      _isLoadingHistory = true;
      _existingHistory = null;
    });
    try {
      final response = await _api.getZakatHistoryByYearId(yearId);
      final raw = response.data;
      final data = raw is Map<String, dynamic>
          ? (raw['data'] is Map<String, dynamic> ? raw['data'] as Map<String, dynamic> : raw)
          : null;
      if (!mounted) return;
      setState(() => _existingHistory = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _existingHistory = null);
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Map<String, dynamic> _buildFinalPayload({
    required String yearId,
    required String yearLabel,
    required int wajibZakat,
    required int sbBase,
    required List<int> amilBase,
    required int asnafBase,
    required int totalBase,
    required int adjSbVal,
    required List<int> adjAmilChildrenVal,
    required int adjAsnafVal,
    required int adjustmentTotal,
    required int finalSb,
    required List<int> finalAmilChildren,
    required int finalAsnaf,
    required int finalTotal,
    required int finalJumlah,
    required List<_AmilChildConfig> amilChildren,
  }) {
    String amilCode(_AmilChildConfig c) =>
        'JATAH_AMIL_${c.label.replaceAll(' ', '_')}';
    String finalizedAtUtc() =>
        DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(DateTime.now().toUtc());

    return {
      'year_id': yearId,
      'year_label': yearLabel,
      'module': 'ZAKATFITRAH',
      'notes': _notesController.text.trim(),
      'money_nominal': _titipUang.toStringAsFixed(0),
      'config': {
        'titip_uang': _titipUang.toStringAsFixed(0),
        'jatah_sb': _jatahSb,
        'jatah_amil': _jatahAmil,
        'jatah_asnaf': _jatahAsnaf,
        'amil_children': List.generate(
          amilChildren.length,
          (i) => {
            'code': amilCode(amilChildren[i]),
            'label': amilChildren[i].label,
            'percent': amilChildren[i].percent,
          },
        ),
        'asnaf_bobot': List.generate(
          _asnafBobotRows.length,
          (i) => {
            'year_id': (_asnafBobotRows[i]['year_id']?.toString().isNotEmpty ?? false)
                ? _asnafBobotRows[i]['year_id']?.toString()
                : yearId,
            'asnaf_type': _normalizeAsnafType(
                _asnafBobotRows[i]['asnaf_type']?.toString() ?? ''),
            'bobot': _parseDouble(_asnafBobotRows[i]['bobot'], fallback: 0).round(),
          },
        ),
      },
      'base': {
        'wajib_zakat': wajibZakat,
        'sb': sbBase,
        'amil_children': List.generate(
          amilChildren.length,
          (i) => {
            'code': amilCode(amilChildren[i]),
            'label': amilChildren[i].label,
            'value': i < amilBase.length ? amilBase[i] : 0,
          },
        ),
        'asnaf': asnafBase,
        'total': totalBase,
      },
      'adjustment': {
        'jumlah': adjustmentTotal,
        'sb': adjSbVal,
        'amil_children': List.generate(
          amilChildren.length,
          (i) => {
            'code': amilCode(amilChildren[i]),
            'label': amilChildren[i].label,
            'value': i < adjAmilChildrenVal.length ? adjAmilChildrenVal[i] : 0,
          },
        ),
        'asnaf': adjAsnafVal,
        'total': adjustmentTotal,
      },
      'result': {
        'jumlah': finalJumlah,
        'sb': finalSb,
        'amil_children': List.generate(
          amilChildren.length,
          (i) => {
            'code': amilCode(amilChildren[i]),
            'label': amilChildren[i].label,
            'value': i < finalAmilChildren.length ? finalAmilChildren[i] : 0,
          },
        ),
        'asnaf': finalAsnaf,
        'total': finalTotal,
      },
      'finalized_at': finalizedAtUtc(),
    };
  }

  Future<void> _loadDistributionConfig([String? yearId]) async {
    setState(() {
      _isLoadingConfig = true;
      _configError = null;
    });

    try {
      final response = await _api.getZakatDistributions(
        yearId: (yearId != null && yearId.isNotEmpty) ? yearId : null,
      );
      final roots = _extractList(response.data);

      double sb = 40;
      double amil = 15;
      double asnaf = 45;
      final List<_AmilChildConfig> amilChildren = [];

      // ── Map tree nodes to report buckets ──────────────────────────────
      // · Node with children  → Amil bucket; its children → amil sub-groups.
      // · Name matches "sb" or "sabilillah" (case-insensitive) → SB bucket.
      // · Everything else    → Asnaf bucket (summed).
      double asnafAccumulator = 0;
      bool asnafFound = false;

      String? sbId;
      final asnafIds = <String>[];
      final asnafLabels = <String>[];

      for (final raw in roots) {
        final id = raw['id']?.toString() ?? '';
        final name = (raw['name']?.toString() ?? '').toLowerCase();
        final pct = double.tryParse(raw['percentage']?.toString() ?? '') ?? 0.0;
        final rawChildren = raw['children'];
        final hasChildren = rawChildren is List && (rawChildren).isNotEmpty;

        if (hasChildren) {
          // Amil
          amil = pct;
          for (final child in rawChildren) {
            if (child is! Map<String, dynamic>) continue;
            final childId = child['id']?.toString() ?? '';
            final childName = (child['name']?.toString() ?? '').trim();
            final childPct =
                double.tryParse(child['percentage']?.toString() ?? '') ?? 0.0;
            if (childName.isNotEmpty) {
              amilChildren.add(_AmilChildConfig(
                  id: childId, label: childName, percent: childPct));
            }
          }
        } else if (name.contains('sb') || name.contains('sabilillah')) {
          sb = pct;
          sbId = id.isNotEmpty ? id : null;
        } else {
          asnafAccumulator += pct;
          asnafFound = true;
          if (id.isNotEmpty) {
            asnafIds.add(id);
            asnafLabels.add(raw['name']?.toString() ?? id);
          }
        }
      }

      if (asnafFound) asnaf = asnafAccumulator;

      if (!mounted) return;
      setState(() {
        _jatahSb = sb;
        _jatahAmil = amil;
        _jatahAsnaf = asnaf;
        _amilChildren = amilChildren;
        _sbDistributionId = sbId;
        _asnafDistributionIds = asnafIds;
        _asnafDistributionLabels = asnafLabels;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _configError = 'Sebagian konfigurasi laporan gagal dimuat.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingConfig = false;
        });
      }
    }
  }

  Future<void> _loadMustahiqRecap(String yearId) async {
    if (yearId.isEmpty) return;

    setState(() {
      _isLoadingMustahiqRecap = true;
      _mustahiqRecapError = null;
    });

    try {
      final results = await Future.wait([
        _api.getZakatMustahiq(yearId: yearId),
        _api.getZakatAsnafBobot(yearId: yearId),
      ]);

      final mustahiqRaw = _extractList(results.first.data);
      final asnafRaw = _extractList(results.last.data);

      final bobotByType = <String, double>{};
      for (final item in asnafRaw) {
        final type = _normalizeAsnafType(item['asnaf_type']?.toString() ?? '');
        if (type.isEmpty) continue;
        bobotByType[type] = _parseDouble(item['bobot'], fallback: 1);
      }

      final rows = <_MustahiqRecapRow>[];
      for (final item in mustahiqRaw) {
        final type = _normalizeAsnafType(item['asnaf_type']?.toString() ?? '');
        final name = (item['name']?.toString() ?? '').trim();
        final souls = _parseInt(item['souls'], fallback: 0);
        if (type.isEmpty || name.isEmpty || souls <= 0) continue;

        final bobot = bobotByType[type] ?? 1;
        rows.add(
          _MustahiqRecapRow(
            asnafType: type,
            name: name,
            souls: souls,
            totalJatahSo: bobot * souls,
          ),
        );
      }

      rows.sort((a, b) {
        final byType = a.asnafLabel.compareTo(b.asnafLabel);
        if (byType != 0) return byType;
        return a.name.compareTo(b.name);
      });

      if (!mounted) return;
      setState(() {
        _mustahiqRecapRows = rows;
        _asnafBobotRows = asnafRaw;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mustahiqRecapError = 'Rekap mustahiq gagal dimuat.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMustahiqRecap = false;
        });
      }
    }
  }

  Future<void> _loadVerificationRecap(String yearId) async {
    if (yearId.isEmpty) return;

    setState(() {
      _isLoadingVerificationRecap = true;
      _verificationRecapError = null;
    });

    try {
      final response =
          await _api.getZakatMuzakkiVerificationRecap(yearId: yearId);
      final parsed = _parseVerificationRecap(response.data);
      if (!mounted) return;
      setState(() {
        _verificationRecapData = parsed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verificationRecapError = 'Rekap verifikasi muzakki gagal dimuat.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVerificationRecap = false;
        });
      }
    }
  }

  _VerificationRecapData _parseVerificationRecap(dynamic raw) {
    final top = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    final payload = top['data'] is Map<String, dynamic>
        ? top['data'] as Map<String, dynamic>
        : top;

    List<_VerificationMemberRow> parseMembers(dynamic source,
        {required bool verified}) {
      if (source is! List) return const [];
      final rows = <_VerificationMemberRow>[];
      for (final item in source.whereType<Map<String, dynamic>>()) {
        rows.add(
          _VerificationMemberRow(
            id: item['id']?.toString() ?? '',
            fullName: (item['full_name']?.toString() ??
                    item['name']?.toString() ??
                    '-')
                .trim(),
            familyId: item['family_id']?.toString() ?? '',
            relationship: item['relationship']?.toString() ?? '',
            isHeadOfFamily: item['is_head_of_family'] as bool? ?? false,
            isInternal: item['is_internal'] as bool? ?? true,
            externalGroup: item['external_group']?.toString() ?? '',
            afiliasi: item['afiliasi']?.toString() ?? '',
            isVerified: verified,
          ),
        );
      }
      return rows;
    }

    final verifiedMembers = parseMembers(payload['verified'], verified: true);
    final unverifiedMembers =
        parseMembers(payload['unverified'], verified: false);

    final verified = _parseInt(
      payload['verified_count'] ?? payload['verified_total'],
      fallback: verifiedMembers.length,
    );
    final unverified = _parseInt(
      payload['unverified_count'] ?? payload['unverified_total'],
      fallback: unverifiedMembers.length,
    );
    final total = _parseInt(
      payload['total_muzakki'] ?? payload['total'],
      fallback: verified + unverified,
    );
    final percent = total > 0 ? ((verified / total) * 100).toDouble() : 0.0;

    return _VerificationRecapData(
      yearId: payload['year_id']?.toString() ?? '',
      total: total,
      verified: verified,
      unverified: unverified,
      verifiedPercent: percent,
      verifiedMembers: verifiedMembers,
      unverifiedMembers: unverifiedMembers,
    );
  }

  List<int> _splitAmilCount(int amilTotal, List<_AmilChildConfig> children) {
    if (children.isEmpty) return [amilTotal];

    final totalPercent = children.fold<double>(0, (sum, c) => sum + c.percent);
    if (totalPercent <= 0) {
      return List<int>.generate(
        children.length,
        (index) => index == 0 ? amilTotal : 0,
      );
    }

    final counts = <int>[];
    var allocated = 0;
    for (var index = 0; index < children.length; index++) {
      if (index == children.length - 1) {
        counts.add(amilTotal - allocated);
      } else {
        final value =
            (amilTotal * (children[index].percent / totalPercent)).round();
        counts.add(value);
        allocated += value;
      }
    }
    return counts;
  }

  List<double> _splitAmilAmount(
      List<int> amilCounts, List<_AmilChildConfig> children) {
    if (children.isEmpty) {
      return [amilCounts.isNotEmpty ? amilCounts.first * _titipUang : 0];
    }
    return List<double>.generate(
      children.length,
      (index) =>
          (index < amilCounts.length ? amilCounts[index] : 0) * _titipUang,
    );
  }

  int _toIntOrZero(String value) => int.tryParse(value.trim()) ?? 0;

  /// e.g. 45000 → "Rp 45.000"
  String _fmtRp(double amount) {
    final fmt = NumberFormat('#,##0', 'id_ID');
    return 'Rp ${fmt.format(amount.round())}';
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    dynamic source = raw;
    if (raw is Map<String, dynamic> && raw['data'] != null) {
      source = raw['data'];
    }

    if (source is List) {
      return source.whereType<Map<String, dynamic>>().toList();
    }

    if (source is Map<String, dynamic>) {
      return [source];
    }

    return const [];
  }

  int _parseInt(dynamic raw, {required int fallback}) {
    final value = int.tryParse(raw?.toString() ?? '');
    return value ?? fallback;
  }

  double _parseDouble(dynamic raw, {required double fallback}) {
    final value = double.tryParse(raw?.toString() ?? '');
    return value ?? fallback;
  }

  String _normalizeAsnafType(String input) => input.trim().toLowerCase();

  Future<void> _loadAmilKpi(String yearId) async {
    if (yearId.isEmpty) return;
    setState(() {
      _isLoadingAmilKpi = true;
      _amilKpiError = null;
    });
    try {
      final response = await _api.getZakatAmilKpi(yearId: yearId);
      final raw = response.data;
      final data = raw is Map<String, dynamic> ? raw['data'] : null;
      if (data == null || data is! Map<String, dynamic>) {
        if (!mounted) return;
        setState(() => _amilKpiData = null);
        return;
      }
      final amilsRaw = data['amils'];
      final amils = (amilsRaw is List)
          ? amilsRaw
              .whereType<Map<String, dynamic>>()
              .map((a) => _AmilKpiEntry(
                    amilName: a['amil_name']?.toString() ?? '',
                    recordedCount:
                        int.tryParse(a['recorded_count']?.toString() ?? '') ??
                            0,
                    serahTerimaCount: int.tryParse(
                            a['serah_terima_count']?.toString() ?? '') ??
                        0,
                    totalSouls:
                        int.tryParse(a['total_souls']?.toString() ?? '') ?? 0,
                    totalRiceQty: double.tryParse(
                            a['total_rice_qty']?.toString() ?? '') ??
                        0,
                    totalMoney:
                        double.tryParse(a['total_money']?.toString() ?? '') ??
                            0,
                  ))
              .toList()
          : <_AmilKpiEntry>[];

      if (!mounted) return;
      setState(() {
        _amilKpiData = _AmilKpiData(
          yearLabel: data['year_label']?.toString() ?? '',
          groupName: data['group_name']?.toString() ?? '',
          amils: amils,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _amilKpiError = 'Gagal memuat data KPI Amil.');
    } finally {
      if (mounted) setState(() => _isLoadingAmilKpi = false);
    }
  }

  /// Fetches saved adjustments from the API keyed by distribution_id.
  Future<void> _loadAdjustments([String? yearId]) async {
    setState(() => _isLoadingConfig = true);
    try {
      final response = await _api.getZakatAdjustments(
        yearId: (yearId != null && yearId.isNotEmpty) ? yearId : null,
      );
      final rows = _extractList(response.data);
      final map = <String, double>{};
      for (final row in rows) {
        final distId = row['distribution_id']?.toString() ?? '';
        final amount =
            double.tryParse(row['adjusted_amount']?.toString() ?? '') ?? 0.0;
        if (distId.isNotEmpty) map[distId] = amount;
      }
      if (!mounted) return;
      setState(() => _adjByDistributionId = map);
    } catch (_) {
      // Adjustments are optional — fail silently.
    } finally {
      if (mounted) setState(() => _isLoadingConfig = false);
    }
  }

  Future<void> _showAdjustmentDialog(
    List<_AmilChildConfig> amilChildren,
    String yearId, {
    required int baseSb,
    required List<int> baseAmilChildren,
    required int baseAsnaf,
  }) async {
    // Build a controller map: distributionId → TextEditingController
    final ctrls = <String, TextEditingController>{};

    if (_sbDistributionId != null) {
      ctrls[_sbDistributionId!] = TextEditingController(
        text: (_adjByDistributionId[_sbDistributionId] ?? 0).toStringAsFixed(0),
      );
    }
    for (final child in amilChildren) {
      if (child.id.isNotEmpty) {
        ctrls[child.id] = TextEditingController(
          text: (_adjByDistributionId[child.id] ?? 0).toStringAsFixed(0),
        );
      }
    }
    for (var i = 0; i < _asnafDistributionIds.length; i++) {
      final id = _asnafDistributionIds[i];
      ctrls[id] = TextEditingController(
        text: (_adjByDistributionId[id] ?? 0).toStringAsFixed(0),
      );
    }

    // Capture values into a plain Map when the user confirms, so we don't
    // rely on controllers being alive after the dialog's exit animation starts.
    final saved = await showDialog<Map<String, double>>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Adjustment Laporan'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_sbDistributionId != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: ctrls[_sbDistributionId],
                        keyboardType:
                            const TextInputType.numberWithOptions(signed: true),
                        decoration: InputDecoration(
                          labelText: 'Adjustment SB',
                          helperText:
                              'Base: $baseSb jiwa → ${_fmtRp(baseSb * _titipUang)}',
                          helperStyle: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ...amilChildren
                      .where((c) => c.id.isNotEmpty)
                      .toList()
                      .asMap()
                      .entries
                      .map(
                    (entry) {
                      final idx = entry.key;
                      final c = entry.value;
                      final base = idx < baseAmilChildren.length
                          ? baseAmilChildren[idx]
                          : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: ctrls[c.id],
                          keyboardType: const TextInputType.numberWithOptions(
                              signed: true),
                          decoration: InputDecoration(
                            labelText: 'Adjustment Amil ${c.label}',
                            helperText:
                                'Base: $base jiwa → ${_fmtRp(base * _titipUang)}',
                            helperStyle: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ),
                      );
                    },
                  ),
                  ...List.generate(
                    _asnafDistributionIds.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: ctrls[_asnafDistributionIds[i]],
                        keyboardType:
                            const TextInputType.numberWithOptions(signed: true),
                        decoration: InputDecoration(
                          labelText:
                              'Adjustment ${_asnafDistributionLabels[i]}',
                          helperText:
                              'Base: $baseAsnaf jiwa → ${_fmtRp(baseAsnaf * _titipUang)}',
                          helperStyle: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                // Capture values inside the dialog before it starts closing,
                // so the controllers can be safely disposed afterwards.
                final values = {
                  for (final e in ctrls.entries)
                    e.key: double.tryParse(e.value.text.trim()) ?? 0.0,
                };
                Navigator.pop(ctx, values);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    // Do NOT dispose controllers here. showDialog's Future resolves when
    // Navigator.pop is called, but the dialog's exit animation is still
    // running at that point — TextField widgets are still alive and linked
    // to the controllers. Disposing early triggers _dependents.isEmpty.
    // These are short-lived local variables with no native resources; they
    // will be GC'd once the animation completes and the dialog is unmounted.

    if (saved != null && mounted) {
      // Update local state immediately for responsive UI
      final updated = Map<String, double>.from(_adjByDistributionId)
        ..addAll(saved);
      setState(() => _adjByDistributionId = updated);

      // Persist each slot to the API
      for (final entry in saved.entries) {
        try {
          await _api.createZakatAdjustment({
            if (yearId.isNotEmpty) 'year_id': yearId,
            'distribution_id': entry.key,
            'adjusted_amount': entry.value.toStringAsFixed(2),
          });
        } catch (_) {
          // Continue persisting remaining slots even if one fails.
        }
      }
    }
  }

  Map<String, dynamic> _buildSavePayload({
    required String yearId,
    required String yearLabel,
    required int wajibZakat,
    required int sbBase,
    required List<int> amilBase,
    required int asnafBase,
    required int totalBase,
    required int adjustmentTotal,
    required int totalAdjusted,
    required List<_AmilChildConfig> amilChildren,
    required int adjSb,
    required List<int> adjAmilChildren,
    required int adjAsnaf,
  }) {
    return {
      'year_id': yearId,
      'year_label': yearLabel,
      'module': 'ZAKATFITRAH',
      'notes': _notesController.text.trim(),
      'config': {
        'titip_uang': _titipUang,
        'jatah_sb': _jatahSb,
        'jatah_amil': _jatahAmil,
        'jatah_asnaf': _jatahAsnaf,
        'jatah_amil_children': List.generate(
          amilChildren.length,
          (index) => {
            'code':
                'JATAH_AMIL_${amilChildren[index].label.replaceAll(' ', '_')}',
            'label': amilChildren[index].label,
            'percent': amilChildren[index].percent,
          },
        ),
      },
      'base': {
        'wajib_zakat': wajibZakat,
        'sb': sbBase,
        'amil_children': List.generate(
          amilChildren.length,
          (index) => {
            'label': amilChildren[index].label,
            'value': index < amilBase.length ? amilBase[index] : 0,
          },
        ),
        'asnaf': asnafBase,
        'total': totalBase,
      },
      'adjustment': {
        'jumlah': adjustmentTotal,
        'sb': adjSb,
        'amil_children': List.generate(
          amilChildren.length,
          (index) => {
            'label': amilChildren[index].label,
            'value':
                index < adjAmilChildren.length ? adjAmilChildren[index] : 0,
          },
        ),
        'asnaf': adjAsnaf,
      },
      'result': {
        'jumlah': totalAdjusted,
        'sb': sbBase + adjSb,
        'amil_children': List.generate(
          amilChildren.length,
          (index) => {
            'label': amilChildren[index].label,
            'value': (index < amilBase.length ? amilBase[index] : 0) +
                (index < adjAmilChildren.length ? adjAmilChildren[index] : 0),
          },
        ),
        'asnaf': asnafBase + adjAsnaf,
        'total': totalAdjusted,
      },
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ZakatProvider>(
      builder: (context, provider, _) {
        if (provider.reportSummary == null &&
            !provider.isLoadingReportSummary &&
            provider.reportSummaryError == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.read<ZakatProvider>().fetchLaporanSummary();
            }
          });
        }

        final apiSummary = provider.reportSummary;

        final berasList = provider.muzakkiList
            .where((m) => m.paymentType == PaymentType.beras)
            .toList();
        final uangList = provider.muzakkiList
            .where((m) => m.paymentType == PaymentType.uang)
            .toList();

        final totalSoRegistered = berasList.fold(0.0, (s, m) => s + m.amountSo);
        final totalRpRegistered = uangList.fold(0.0, (s, m) => s + m.amountRp);

        final internalMuzakkiCount =
            provider.muzakkiList.where((m) => m.isInternal).length;
        final externalMuzakkiCount =
            provider.muzakkiList.where((m) => !m.isInternal).length;

        final externalFamilies = provider.externalByFamily.values;
        final externalSoulsCount = externalFamilies.fold<int>(
            0, (sum, e) => sum + e.externalTotalSouls);
        final externalRiceSoulsNonRegistered = externalFamilies
            .fold<int>(0, (sum, e) => sum + e.externalTotalRiceSouls)
            .toDouble();
        final externalMoneySoulsNonRegistered = externalFamilies.fold<int>(
            0, (sum, e) => sum + e.externalTotalMoneySouls);
        final externalRegisteredRiceSouls = provider.muzakkiList
            .where((m) => !m.isInternal && m.paymentType == PaymentType.beras)
            .fold<int>(
                0,
                (sum, m) =>
                    sum + (m.numberOfPeople > 0 ? m.numberOfPeople : 1));
        final externalRegisteredMoneySouls = provider.muzakkiList
            .where((m) => !m.isInternal && m.paymentType == PaymentType.uang)
            .fold<int>(
                0,
                (sum, m) =>
                    sum + (m.numberOfPeople > 0 ? m.numberOfPeople : 1));
        final externalRiceSoulsGroup = externalRegisteredRiceSouls +
            externalRiceSoulsNonRegistered.toInt();
        final externalMoneySoulsGroup =
            externalRegisteredMoneySouls + externalMoneySoulsNonRegistered;
        final externalAmount = externalFamilies.fold<double>(
          0,
          (sum, e) => sum + _parseAmount(e.externalTotalAmount),
        );

        final fallbackTotalSo =
            totalSoRegistered + externalRiceSoulsNonRegistered;
        final fallbackTotalRp = totalRpRegistered + externalAmount;

        final summaryTotals = apiSummary?.summary;
        final paymentSummary = apiSummary?.paymentSummary;

        final yearLabel = apiSummary?.yearLabel.isNotEmpty == true
            ? apiSummary!.yearLabel
            : provider.selectedYear?.label ?? 'Zakat Fitrah';
        final selectedYearId = provider.selectedYear?.id ?? '';

        if (selectedYearId.isNotEmpty && selectedYearId != _lastRecapYearId) {
          _lastRecapYearId = selectedYearId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _loadMustahiqRecap(selectedYearId);
          });
        }

        if (selectedYearId.isNotEmpty && selectedYearId != _lastConfigYearId) {
          _lastConfigYearId = selectedYearId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _loadDistributionConfig(selectedYearId);
            _loadAdjustments(selectedYearId);
            _loadAmilKpi(selectedYearId);
          });
        }

        if (selectedYearId.isNotEmpty &&
            selectedYearId != _lastVerificationRecapYearId) {
          _lastVerificationRecapYearId = selectedYearId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _loadVerificationRecap(selectedYearId);
          });
        }

        if (selectedYearId.isNotEmpty &&
            selectedYearId != _lastHistoryYearId) {
          _lastHistoryYearId = selectedYearId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _loadHistory(selectedYearId);
          });
        }

        final totalMuzakki =
            summaryTotals?.totalMuzakki ?? provider.totalMuzakki;
        final totalJiwaOverall = summaryTotals?.totalSoulsOverall ??
            provider.totalJiwa + externalSoulsCount;
        final internalCount =
            summaryTotals?.totalInternalMuzakki ?? internalMuzakkiCount;
        final externalMuzakkiOnlyCount =
            summaryTotals?.totalExternalMuzakki ?? externalMuzakkiCount;
        final externalSoulsOverall =
            summaryTotals?.totalExternalSouls ?? externalSoulsCount;
        final totalExternal = externalMuzakkiOnlyCount + externalSoulsOverall;
        final totalWajibZakat = internalCount + totalExternal;

        final totalSo = paymentSummary?.rice.totalSo ?? fallbackTotalSo;

        final totalRp = paymentSummary?.money.totalAmount ?? fallbackTotalRp;

        final sbPercent = _jatahSb / 100;
        final amilPercent = _jatahAmil / 100;
        final amilChildren = _amilChildren.isNotEmpty
            ? _amilChildren
            : [
                _AmilChildConfig(id: '', label: 'AMIL', percent: _jatahAmil),
              ];

        final sbCount = (totalWajibZakat * sbPercent).round();
        final amilTotalCount = (totalWajibZakat * amilPercent).round();
        final amilChildCounts = _splitAmilCount(amilTotalCount, amilChildren);
        final asnafCount = totalWajibZakat - sbCount - amilTotalCount;
        final totalPembagian = sbCount + amilTotalCount + asnafCount;

        // Manual adjustment now acts as an override (replacement),
        // not an additive delta against formula-based distribution.
        final sbRawOverride = (_sbDistributionId != null &&
                _adjByDistributionId.containsKey(_sbDistributionId))
            ? _adjByDistributionId[_sbDistributionId]!.round()
            : null;
        final sbOverride =
            (sbRawOverride != null && sbRawOverride > 0) ? sbRawOverride : null;
        final amilOverride = amilChildren
            .map((c) {
              if (c.id.isEmpty || !_adjByDistributionId.containsKey(c.id)) {
                return null;
              }
              final value = _adjByDistributionId[c.id]!.round();
              return value > 0 ? value : null;
            })
            .toList();
        final asnafOverrideValues = _asnafDistributionIds
            .where((id) => _adjByDistributionId.containsKey(id))
            .map((id) => _adjByDistributionId[id]!.round())
            .where((value) => value > 0)
            .toList();
        final asnafOverride = asnafOverrideValues.isNotEmpty
            ? asnafOverrideValues.fold<int>(0, (s, v) => s + v)
            : null;

        final hasManualOverride = sbOverride != null ||
            amilOverride.any((value) => value != null) ||
            asnafOverride != null;

        final adjustedSb = sbOverride ?? sbCount;
        final adjustedAmilChildren = List<int>.generate(
          amilChildren.length,
          (index) => amilOverride[index] ?? amilChildCounts[index],
        );
        final adjustedAsnaf = asnafOverride ?? asnafCount;
        final adjustmentTotal = adjustedSb +
            adjustedAmilChildren.fold<int>(0, (sum, v) => sum + v) +
            adjustedAsnaf;
        final adjustedTotal = adjustmentTotal;
        final adjustedJumlah = adjustedTotal;

        final adjSb = adjustedSb;
        final adjAmilChildren = adjustedAmilChildren;
        final adjAsnaf = adjustedAsnaf;

        final distColumnWidths = <int, TableColumnWidth>{
          0: const FixedColumnWidth(130),
          1: const FixedColumnWidth(80),
          2: const FixedColumnWidth(80),
        };
        for (var index = 0; index < amilChildren.length; index++) {
          distColumnWidths[3 + index] = const FixedColumnWidth(90);
        }
        distColumnWidths[3 + amilChildren.length] = const FixedColumnWidth(80);
        distColumnWidths[4 + amilChildren.length] = const FixedColumnWidth(110);
        Future<void> refreshLaporan() async {
          final yr = selectedYearId.isNotEmpty ? selectedYearId : null;
          await Future.wait<void>([
            provider.fetchMuzakki(),
            provider.fetchLaporanSummary(),
            if (selectedYearId.isNotEmpty) _loadMustahiqRecap(selectedYearId),
            if (selectedYearId.isNotEmpty) _loadAmilKpi(selectedYearId),
            if (selectedYearId.isNotEmpty)
              _loadVerificationRecap(selectedYearId),
            if (selectedYearId.isNotEmpty) _loadHistory(selectedYearId),
            _loadDistributionConfig(yr),
            _loadAdjustments(yr),
          ]);
        }

        return RefreshIndicator(
          color: _green,
          onRefresh: refreshLaporan,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section header ──────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rekapitulasi $yearLabel',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh laporan',
                      onPressed:
                          (provider.isLoadingReportSummary || _isLoadingConfig)
                              ? null
                              : refreshLaporan,
                      icon:
                          (provider.isLoadingReportSummary || _isLoadingConfig)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _green,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded,
                                  color: Color(0xFF066046)),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAdjustmentDialog(
                        amilChildren,
                        selectedYearId,
                        baseSb: sbCount,
                        baseAmilChildren: amilChildCounts,
                        baseAsnaf: asnafCount,
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Adjustment'),
                      style: TextButton.styleFrom(foregroundColor: _green),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Total $totalMuzakki muzakki · $totalJiwaOverall jiwa',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                // --- Rekapitulasi + Final in one table ---
                _distribusiCombinedTable(
                  amilChildrenLabels: _amilChildren.map((a) => a.label).toList(),
                  sbPercent: _jatahSb,
                  asnafPercent: _jatahAsnaf,
                  kalkulasiJumlah: totalWajibZakat,
                  kalkulasiSb: sbCount,
                  kalkulasiAmilChildren: amilChildCounts,
                  kalkulasiAsnaf: asnafCount,
                  kalkulasiTotal: totalPembagian,
                  finalJumlah: adjustedJumlah,
                  finalSb: adjustedSb,
                  finalAmilChildren: adjustedAmilChildren,
                  finalAsnaf: adjustedAsnaf,
                  finalTotal: adjustedTotal,
                  hasManualOverride: hasManualOverride,
                  finalJumlahRp: adjustedJumlah * _titipUang,
                  finalSbRp: adjustedSb * _titipUang,
                  finalAmilChildrenRp: adjustedAmilChildren
                      .map((value) => value * _titipUang)
                      .toList(),
                  finalAsnafRp: adjustedAsnaf * _titipUang,
                  finalTotalRp: adjustedTotal * _titipUang,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Notes Laporan',
                    hintText: 'Catatan untuk snapshot laporan tahun ini',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── History / Closing status banner ───────────────────────
                if (_isLoadingHistory)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(),
                  )
                else if (_existingHistory != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tahun ini sudah di-closing',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              if (_existingHistory!['finalized_at'] != null)
                                Text(
                                  'Tanggal: ${_existingHistory!['finalized_at']}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF166534)),
                                ),
                              if ((_existingHistory!['notes'] ?? '').toString().isNotEmpty)
                                Text(
                                  'Notes: ${_existingHistory!['notes']}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF166534)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // ── Error banner ──────────────────────────────────────────
                if (_saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _saveError!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFDC2626)),
                    ),
                  ),

                // ── Closing button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isSaving || selectedYearId.isEmpty)
                        ? null
                        : () async {
                            // Build payload ahead of confirmation dialog
                            final payload = _buildFinalPayload(
                              yearId: selectedYearId,
                              yearLabel: yearLabel,
                              wajibZakat: totalWajibZakat,
                              sbBase: sbCount,
                              amilBase: amilChildCounts,
                              asnafBase: asnafCount,
                              totalBase: totalPembagian,
                              adjSbVal: adjSb,
                              adjAmilChildrenVal: adjAmilChildren,
                              adjAsnafVal: adjAsnaf,
                              adjustmentTotal: adjustmentTotal,
                              finalSb: adjustedSb,
                              finalAmilChildren: adjustedAmilChildren,
                              finalAsnaf: adjustedAsnaf,
                              finalTotal: adjustedTotal,
                              finalJumlah: adjustedJumlah,
                              amilChildren: amilChildren,
                            );

                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Closing Tahun Zakat'),
                                content: Text(
                                  'Anda akan finalisasi laporan untuk "$yearLabel".\n\n'
                                  'Total wajib zakat: $totalWajibZakat jiwa\n'
                                  'Distribusi akhir: $adjustedTotal jiwa\n'
                                  'SB: $adjustedSb · Asnaf: $adjustedAsnaf\n\n'
                                  'Lanjutkan?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Batal'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('Ya, Closing'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true) return;
                            if (!context.mounted) return;

                            setState(() {
                              _isSaving = true;
                              _saveError = null;
                            });

                            try {
                              await _api.createZakatHistory(payload);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Laporan "$yearLabel" berhasil di-closing.'),
                                  backgroundColor: _green,
                                ),
                              );
                              // Reload history to show the banner
                              await _loadHistory(selectedYearId);
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _saveError =
                                  'Gagal menyimpan laporan: ${e.toString()}');
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                              }
                            }
                          },
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(Icons.lock_rounded),
                    label: Text(
                        _isSaving ? 'Menyimpan...' : 'Closing Tahun Zakat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _existingHistory != null ? Colors.grey : _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                _buildMustahiqRecapCard(),

                // ── Total Jatah So Mustahiq ────────────────────────────────
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final jatahAsnafSo = adjustedAsnaf.toDouble();
                  final totalKebutuhanSo = _mustahiqRecapRows.fold(
                    0.0,
                    (sum, r) => sum + r.totalJatahSo,
                  );
                  final selisih = jatahAsnafSo - totalKebutuhanSo;
                  final isSurplus = selisih >= 0;
                  final selisihColor = isSurplus
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626);
                  final selisihLabel = isSurplus ? 'Surplus' : 'Defisit';

                  String fmtSo(double v) =>
                      '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(2)} so';

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Jatah So Mustahiq (Asnaf)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _soSummaryItem(
                              label: 'Jatah Asnaf',
                              value: fmtSo(jatahAsnafSo),
                              sub: '$adjustedAsnaf jiwa × 1 so',
                              color: _green,
                            ),
                            _soSummaryItem(
                              label: 'Kebutuhan Mustahiq',
                              value: fmtSo(totalKebutuhanSo),
                              sub: '${_mustahiqRecapRows.length} mustahiq',
                              color: const Color(0xFF1D4ED8),
                            ),
                            _soSummaryItem(
                              label: selisihLabel,
                              value: fmtSo(selisih.abs()),
                              sub: isSurplus ? 'So tersisa' : 'Kurang so',
                              color: selisihColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 10),
                Text(
                  'Konversi 1 So: ${_formatRupiahFull(_titipUang)} · Total Bayar: ${_formatRupiahFull(totalRp)} · Total So: ${totalSo.toStringAsFixed(2)}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),

                if (_configError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _configError!,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                  ),
                ],

                if (provider.reportSummaryError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    provider.reportSummaryError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Afiliasi Breakdown (from API) ─────────────────────────
                if (apiSummary != null)
                  Builder(builder: (ctx) {
                    final rows = apiSummary.internalByAfiliasi;

                    const val = TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A));
                    const totalStyle =
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

                    TableRow apiRow(
                      String label,
                      int muzakkiCount,
                      int rice,
                      int money, {
                      bool isTotal = false,
                      bool isExternal = false,
                    }) {
                      final ts = isTotal ? totalStyle : val;
                      final labelColor = isExternal
                          ? const Color(0xFF7E22CE)
                          : isTotal
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFF9333EA);
                      return TableRow(
                        decoration: BoxDecoration(
                            color: isTotal
                                ? const Color(0xFFF0FDF4)
                                : isExternal
                                    ? const Color(0xFFF5F3FF)
                                    : Colors.transparent),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 6),
                            child: Text(label,
                                style: isTotal
                                    ? totalStyle
                                    : TextStyle(
                                        fontSize: 12, color: labelColor)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('$muzakkiCount',
                                textAlign: TextAlign.center, style: ts),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('$rice',
                                textAlign: TextAlign.center, style: ts),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('$money',
                                textAlign: TextAlign.center, style: ts),
                          ),
                        ],
                      );
                    }

                    // Totals for footer row
                    final totalMuzakki =
                        rows.fold<int>(0, (s, r) => s + r.totalMuzakki) +
                            externalRiceSoulsGroup +
                            externalMoneySoulsGroup;
                    final totalRice =
                        rows.fold<int>(0, (s, r) => s + r.riceSouls) +
                            externalRiceSoulsGroup;
                    final totalMoney =
                        rows.fold<int>(0, (s, r) => s + r.moneySouls) +
                            externalMoneySoulsGroup;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rincian per Group',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A)),
                          ),
                          const SizedBox(height: 10),
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(1),
                              3: FlexColumnWidth(1),
                            },
                            border: TableBorder.all(
                                color: const Color(0xFFE2E8F0), width: 0.8),
                            children: [
                              // Header
                              const TableRow(
                                decoration:
                                    BoxDecoration(color: Color(0xFFF8FAFC)),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 6),
                                    child: Text('Group',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF64748B))),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text('Muzakki',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF64748B))),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text('Beras (jiwa)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF64748B))),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text('Uang (jiwa)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF64748B))),
                                  ),
                                ],
                              ),
                              // internal_by_afiliasi rows
                              ...rows.map((r) => apiRow(
                                    r.afiliasi.isNotEmpty
                                        ? r.afiliasi
                                        : 'Tanpa Afiliasi',
                                    r.totalMuzakki,
                                    r.riceSouls,
                                    r.moneySouls,
                                  )),
                              // external_breakdown as last data row
                              apiRow(
                                'Eksternal',
                                externalRiceSoulsGroup +
                                    externalMoneySoulsGroup,
                                externalRiceSoulsGroup,
                                externalMoneySoulsGroup,
                                isExternal: true,
                              ),
                              // Grand total
                              apiRow(
                                  'Total', totalMuzakki, totalRice, totalMoney,
                                  isTotal: true),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 28),

                // ── Amil KPI ────────────────────────────────────────
                _buildAmilKpiCard(),

                const SizedBox(height: 16),

                // ── Rekap Verifikasi Muzakki ───────────────────────
                _buildVerificationRecapCard(),

                const SizedBox(height: 16),

                // ── Footer note ──────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFB2DFDB)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Color(0xFF066046)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Data bersumber dari API dan disinkronisasi saat refresh.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF065f46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _distMergedHeaderStrip(int amilChildLength) {
    final amilWidth = 90.0 * amilChildLength;
    return Row(
      children: [
        _mergedHeaderCell('Komponen', width: 130, align: TextAlign.left),
        _mergedHeaderCell('Jumlah', width: 80),
        _mergedHeaderCell('Asnaf', width: 80),
        _mergedHeaderCell('Amil', width: amilWidth),
        _mergedHeaderCell('SB', width: 80),
        _mergedHeaderCell('Total', width: 110),
      ],
    );
  }

  Widget _mergedHeaderCell(String text,
      {required double width, TextAlign align = TextAlign.center}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  TableRow _distSubHeaderRow({
    required double sbPercent,
    required List<String> amilChildren,
    required double asnafPercent,
  }) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Color(0xFF334155),
    );
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
      children: [
        _cell('Komponen', style: style, align: TextAlign.left),
        _cell('Jumlah', style: style),
        _cell('Asnaf\n${asnafPercent.toStringAsFixed(0)}%', style: style),
        ...amilChildren.map((label) => _cell(label, style: style)),
        _cell('SB\n${sbPercent.toStringAsFixed(0)}%', style: style),
        _cell('Total', style: style),
      ],
    );
  }

  TableRow _distDataRow({
    required String label,
    required int jumlah,
    required int sb,
    required List<int> amilChildren,
    required int asnaf,
    required int total,
    bool isTotal = false,
    bool signed = false,
    Color? backgroundColor,
  }) {
    String fmt(int v) => signed && v > 0 ? '+$v' : '$v';
    final style = TextStyle(
      fontSize: 12,
      fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
      color: const Color(0xFF1A1A1A),
    );
    final bg = backgroundColor ?? (isTotal ? const Color(0xFFDCFCE7) : Colors.white);
    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        _cell(label, style: style, align: TextAlign.left),
        _cell(fmt(jumlah), style: style),
        _cell(fmt(asnaf), style: style),
        ...amilChildren.map((v) => _cell(fmt(v), style: style)),
        _cell(fmt(sb), style: style),
        _cell(fmt(total), style: style),
      ],
    );
  }

  TableRow _distSectionLabelRow({
    required String label,
    required int colCount,
  }) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Color(0xFF475569),
    );
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
      children: [
        _cell(label, style: style, align: TextAlign.left),
        ...List.generate(4 + colCount, (_) => _cell('', style: style)),
      ],
    );
  }

  TableRow _distCurrencyRow({
    required String label,
    required double jumlah,
    required double sb,
    required List<double> amilChildren,
    required double asnaf,
    required double total,
  }) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Color(0xFF475569),
    );
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFF0FDF4)),
      children: [
        _cell(label, style: style, align: TextAlign.left),
        _cell(_fmtRp(jumlah), style: style),
        _cell(_fmtRp(asnaf), style: style),
        ...amilChildren.map((v) => _cell(_fmtRp(v), style: style)),
        _cell(_fmtRp(sb), style: style),
        _cell(_fmtRp(total), style: style),
      ],
    );
  }

  Widget _cell(String text,
      {required TextStyle style, TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: style,
      ),
    );
  }

  static String _formatRupiahFull(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static double _parseAmount(String value) {
    return double.tryParse(value) ?? 0;
  }

  Widget _soSummaryItem({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMustahiqRecapCard() {
    final totalSouls =
        _mustahiqRecapRows.fold<int>(0, (sum, item) => sum + item.souls);
    final totalJatahSo = _mustahiqRecapRows.fold<double>(
      0,
      (sum, item) => sum + item.totalJatahSo,
    );

    const hdrStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF64748B),
    );
    const ts = TextStyle(fontSize: 12, color: Color(0xFF1A1A1A));
    const totalStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rekap Mustahiq',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoadingMustahiqRecap)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_mustahiqRecapRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada data mustahiq.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FixedColumnWidth(32),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(2),
                3: FixedColumnWidth(44),
                4: FixedColumnWidth(72),
              },
              border:
                  TableBorder.all(color: const Color(0xFFE2E8F0), width: 0.8),
              children: [
                // Header
                const TableRow(
                  decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text('No', style: hdrStyle),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      child: Text('Nama', style: hdrStyle),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Asnaf',
                          textAlign: TextAlign.center, style: hdrStyle),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Jiwa',
                          textAlign: TextAlign.center, style: hdrStyle),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Jatah So',
                          textAlign: TextAlign.center, style: hdrStyle),
                    ),
                  ],
                ),
                // Data rows
                ..._mustahiqRecapRows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                        child: Text('${index + 1}', style: ts),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 6),
                        child: Text(item.name, style: ts),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(item.asnafLabel,
                            textAlign: TextAlign.center, style: ts),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('${item.souls}',
                            textAlign: TextAlign.center, style: ts),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(item.totalJatahSo.toStringAsFixed(2),
                            textAlign: TextAlign.center, style: ts),
                      ),
                    ],
                  );
                }),
                // Total row
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                  children: [
                    const SizedBox.shrink(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: Text('Total', style: totalStyle),
                    ),
                    const SizedBox.shrink(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('$totalSouls',
                          textAlign: TextAlign.center, style: totalStyle),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(totalJatahSo.toStringAsFixed(2),
                          textAlign: TextAlign.center, style: totalStyle),
                    ),
                  ],
                ),
              ],
            ),
          if (_mustahiqRecapError != null) ...[
            const SizedBox(height: 6),
            Text(
              _mustahiqRecapError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmilKpiCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'KPI Amil',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              if (_isLoadingAmilKpi)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _green,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_amilKpiData != null && _amilKpiData!.groupName.isNotEmpty)
            Text(
              _amilKpiData!.groupName,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          const SizedBox(height: 10),
          if (_isLoadingAmilKpi && _amilKpiData == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: _green),
              ),
            )
          else if (_amilKpiError != null)
            Text(
              _amilKpiError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            )
          else if (_amilKpiData == null || _amilKpiData!.amils.isEmpty)
            const Text(
              'Belum ada data KPI Amil.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FixedColumnWidth(130),
                  1: FixedColumnWidth(72),
                  2: FixedColumnWidth(72),
                  3: FixedColumnWidth(72),
                  4: FixedColumnWidth(72),
                  5: FixedColumnWidth(110),
                },
                border: TableBorder.all(
                  color: const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
                children: [
                  // Header row
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                    children: [
                      'Amil',
                      'Dicatat',
                      'Serah\nTerima',
                      'Jiwa',
                      'So',
                      'Total Uang',
                    ]
                        .map(
                          (h) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            child: Text(
                              h,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  // Data rows
                  ..._amilKpiData!.amils.map((a) {
                    const cellStyle = TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A1A),
                    );
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          child: Text(a.amilName, style: cellStyle),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '${a.recordedCount}',
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '${a.serahTerimaCount}',
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '${a.totalSouls}',
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            a.totalRiceQty % 1 == 0
                                ? '${a.totalRiceQty.toInt()}'
                                : a.totalRiceQty.toStringAsFixed(2),
                            textAlign: TextAlign.center,
                            style: cellStyle,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          child: Text(
                            _formatRupiahFull(a.totalMoney),
                            textAlign: TextAlign.right,
                            style: cellStyle,
                          ),
                        ),
                      ],
                    );
                  }),
                  // Totals row
                  if (_amilKpiData!.amils.length > 1)
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF0FDF4)),
                      children: [
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          child: Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        ...(() {
                          final totRec = _amilKpiData!.amils
                              .fold(0, (s, a) => s + a.recordedCount);
                          final totSt = _amilKpiData!.amils
                              .fold(0, (s, a) => s + a.serahTerimaCount);
                          final totSouls = _amilKpiData!.amils
                              .fold(0, (s, a) => s + a.totalSouls);
                          final totRice = _amilKpiData!.amils
                              .fold(0.0, (s, a) => s + a.totalRiceQty);
                          final totMoney = _amilKpiData!.amils
                              .fold(0.0, (s, a) => s + a.totalMoney);
                          const ts = TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          );
                          return [totRec, totSt, totSouls]
                              .map(
                                (v) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                    '$v',
                                    textAlign: TextAlign.center,
                                    style: ts,
                                  ),
                                ),
                              )
                              .toList()
                            ..add(Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                totRice % 1 == 0
                                    ? '${totRice.toInt()}'
                                    : totRice.toStringAsFixed(2),
                                textAlign: TextAlign.center,
                                style: ts,
                              ),
                            ))
                            ..add(Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              child: Text(
                                _formatRupiahFull(totMoney),
                                textAlign: TextAlign.right,
                                style: ts,
                              ),
                            ));
                        })(),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationRecapCard() {
    final recap = _verificationRecapData;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Rekap Verifikasi Muzakki',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              if (_isLoadingVerificationRecap)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _green,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingVerificationRecap && recap == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(color: _green),
              ),
            )
          else if (_verificationRecapError != null)
            Text(
              _verificationRecapError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            )
          else if (recap == null || recap.total <= 0)
            const Text(
              'Belum ada data verifikasi muzakki.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            )
          else ...[
            Row(
              children: [
                _soSummaryItem(
                  label: 'Total',
                  value: '${recap.total}',
                  sub: 'Muzakki',
                  color: const Color(0xFF1D4ED8),
                ),
                _soSummaryItem(
                  label: 'Terverifikasi',
                  value: '${recap.verified}',
                  sub: '${recap.verifiedPercent.toStringAsFixed(1)}%',
                  color: const Color(0xFF16A34A),
                ),
                _soSummaryItem(
                  label: 'Belum Verifikasi',
                  value: '${recap.unverified}',
                  sub:
                      '${(100 - recap.verifiedPercent).clamp(0, 100).toStringAsFixed(1)}%',
                  color: const Color(0xFFD97706),
                ),
              ],
            ),
            if (recap.verifiedMembers.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildVerificationMemberTable(
                title: 'Daftar Terverifikasi',
                members: recap.verifiedMembers,
                accentColor: const Color(0xFF16A34A),
              ),
            ],
            if (recap.unverifiedMembers.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildVerificationMemberTable(
                title: 'Daftar Belum Verifikasi',
                members: recap.unverifiedMembers,
                accentColor: const Color(0xFFD97706),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationMemberTable({
    required String title,
    required List<_VerificationMemberRow> members,
    required Color accentColor,
  }) {
    final byFamily = <String, List<_VerificationMemberRow>>{};
    for (final m in members) {
      final key = m.familyId.isNotEmpty ? m.familyId : m.id;
      byFamily.putIfAbsent(key, () => <_VerificationMemberRow>[]).add(m);
    }

    final families = byFamily.entries.map((entry) {
      final items = [...entry.value]..sort((a, b) {
          if (a.isHeadOfFamily != b.isHeadOfFamily) {
            return a.isHeadOfFamily ? -1 : 1;
          }
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        });

      final head = items.firstWhere(
        (m) => m.isHeadOfFamily,
        orElse: () => items.first,
      );
      final afiliasi = items
          .map((m) => m.afiliasi.trim())
          .firstWhere((v) => v.isNotEmpty, orElse: () => '')
          .trim();

      return _VerificationFamilyGroup(
        familyId: entry.key,
        headName: head.fullName,
        isInternal: head.isInternal,
        externalGroup: head.externalGroup,
        afiliasi: afiliasi,
        memberCount: items.length,
      );
    }).toList()
      ..sort(
        (a, b) => a.headName.toLowerCase().compareTo(b.headName.toLowerCase()),
      );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${families.length} KK / ${members.length} anggota)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FixedColumnWidth(34),
                1: FixedColumnWidth(170),
                2: FixedColumnWidth(60),
                3: FixedColumnWidth(160),
              },
              border: TableBorder.all(
                color: const Color(0xFFE2E8F0),
                width: 0.8,
              ),
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'No',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Text(
                        'Kepala Keluarga',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Anggota',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Group Name',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                ...families.asMap().entries.map((entry) {
                  final i = entry.key;
                  final family = entry.value;
                  final groupName = family.afiliasi.isNotEmpty
                      ? family.afiliasi
                      : (family.isInternal
                          ? 'Internal'
                          : (family.externalGroup.isNotEmpty
                              ? family.externalGroup
                              : 'Eksternal'));
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${i + 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        child: Text(
                          family.headName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${family.memberCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          groupName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmilChildConfig {
  const _AmilChildConfig({
    required this.id,
    required this.label,
    required this.percent,
  });

  final String id;
  final String label;
  final double percent;
}

class _MustahiqRecapRow {
  const _MustahiqRecapRow({
    required this.asnafType,
    required this.name,
    required this.souls,
    required this.totalJatahSo,
  });

  final String asnafType;
  final String name;
  final int souls;
  final double totalJatahSo;

  String get asnafLabel {
    return asnafType
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

// ───────────────────────────────────────────────────────────────────────────────
class _AmilKpiData {
  const _AmilKpiData({
    required this.yearLabel,
    required this.groupName,
    required this.amils,
  });

  final String yearLabel;
  final String groupName;
  final List<_AmilKpiEntry> amils;
}

class _AmilKpiEntry {
  const _AmilKpiEntry({
    required this.amilName,
    required this.recordedCount,
    required this.serahTerimaCount,
    required this.totalSouls,
    required this.totalRiceQty,
    required this.totalMoney,
  });

  final String amilName;
  final int recordedCount;
  final int serahTerimaCount;
  final int totalSouls;
  final double totalRiceQty;
  final double totalMoney;
}

class _VerificationRecapData {
  const _VerificationRecapData({
    required this.yearId,
    required this.total,
    required this.verified,
    required this.unverified,
    required this.verifiedPercent,
    required this.verifiedMembers,
    required this.unverifiedMembers,
  });

  final String yearId;
  final int total;
  final int verified;
  final int unverified;
  final double verifiedPercent;
  final List<_VerificationMemberRow> verifiedMembers;
  final List<_VerificationMemberRow> unverifiedMembers;
}

class _VerificationMemberRow {
  const _VerificationMemberRow({
    required this.id,
    required this.fullName,
    required this.familyId,
    required this.relationship,
    required this.isHeadOfFamily,
    required this.isInternal,
    required this.externalGroup,
    required this.afiliasi,
    required this.isVerified,
  });

  final String id;
  final String fullName;
  final String familyId;
  final String relationship;
  final bool isHeadOfFamily;
  final bool isInternal;
  final String externalGroup;
  final String afiliasi;
  final bool isVerified;
}

class _VerificationFamilyGroup {
  const _VerificationFamilyGroup({
    required this.familyId,
    required this.headName,
    required this.isInternal,
    required this.externalGroup,
    required this.afiliasi,
    required this.memberCount,
  });

  final String familyId;
  final String headName;
  final bool isInternal;
  final String externalGroup;
  final String afiliasi;
  final int memberCount;
}

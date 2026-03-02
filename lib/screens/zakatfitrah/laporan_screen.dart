import 'dart:convert';

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
  final ApiService _api = ApiService();

  static const _green = Color(0xFF066046);

  double _jatahSb = 40;
  double _jatahAmil = 15;
  double _jatahAsnaf = 45;
  double _titipUang = 45000;
  List<_AmilChildConfig> _amilChildren = const [];
  int _adjSb = 0;
  int _adjAsnaf = 0;
  List<int> _adjAmilChildren = const [];
  final TextEditingController _notesController = TextEditingController();
  bool _isLoadingConfig = false;
  bool _isLoadingMustahiqRecap = false;
  String? _configError;
  String? _mustahiqRecapError;
  String _lastRecapYearId = '';

  List<_MustahiqRecapRow> _mustahiqRecapRows = const [];

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
    });
  }

  Future<void> _loadDistributionConfig() async {
    setState(() {
      _isLoadingConfig = true;
      _configError = null;
    });

    try {
      final response = await _api.getConfigurationsByModule('ZAKATFITRAH');
      final map = _configMap(response.data);

      final sb = _parseConfigDouble(map['JATAH_SB'], fallback: 40);
      final amil = _parseConfigDouble(map['JATAH_AMIL'], fallback: 15);
      final asnaf = _parseConfigDouble(map['JATAH_ASNAF'], fallback: 45);
      final titipUang = _parseConfigDouble(map['TITIP_UANG'], fallback: 45000);

      final amilChildren = map.entries
          .where((e) => e.key.startsWith('JATAH_AMIL_'))
          .map((e) {
            final label = e.key
                .substring('JATAH_AMIL_'.length)
                .split('_')
                .where((part) => part.trim().isNotEmpty)
                .join(' ');
            return _AmilChildConfig(
              label: label.isEmpty ? 'AMIL' : label,
              percent: _parseConfigDouble(e.value, fallback: 0),
            );
          })
          .where((e) => e.percent > 0)
          .toList();

      if (!mounted) return;
      setState(() {
        _jatahSb = sb;
        _jatahAmil = amil;
        _jatahAsnaf = asnaf;
        _titipUang = titipUang;
        _amilChildren = amilChildren;
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

  Map<String, String> _configMap(dynamic raw) {
    dynamic source = raw;
    if (raw is Map<String, dynamic> && raw['data'] != null) {
      source = raw['data'];
    }
    if (source is! List) return <String, String>{};

    final map = <String, String>{};
    for (final item in source) {
      if (item is! Map<String, dynamic>) continue;
      final code = (item['code'] as String? ?? '').trim();
      if (code.isEmpty) continue;
      map[code] = (item['value']?.toString() ?? '').trim();
    }
    return map;
  }

  double _parseConfigDouble(String? raw, {required double fallback}) {
    if (raw == null || raw.isEmpty) return fallback;
    final parsed = double.tryParse(raw.trim());
    if (parsed == null || parsed.isNaN) return fallback;
    return parsed;
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

  void _syncAdjustmentChildren(int childLength) {
    if (_adjAmilChildren.length == childLength) return;
    final next = List<int>.filled(childLength, 0);
    for (var index = 0; index < childLength; index++) {
      if (index < _adjAmilChildren.length) {
        next[index] = _adjAmilChildren[index];
      }
    }
    _adjAmilChildren = next;
  }

  int _toIntOrZero(String value) => int.tryParse(value.trim()) ?? 0;

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

  Future<void> _showAdjustmentDialog(
      List<_AmilChildConfig> amilChildren) async {
    final sbCtrl = TextEditingController(text: _adjSb.toString());
    final asnafCtrl = TextEditingController(text: _adjAsnaf.toString());
    final amilCtrls = List<TextEditingController>.generate(
      amilChildren.length,
      (index) => TextEditingController(
          text: (_adjAmilChildren.length > index ? _adjAmilChildren[index] : 0)
              .toString()),
    );

    final saved = await showDialog<bool>(
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
                  TextField(
                    controller: sbCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Adjustment SB'),
                  ),
                  ...List.generate(amilChildren.length, (index) {
                    return TextField(
                      controller: amilCtrls[index],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            'Adjustment Amil ${amilChildren[index].label}',
                      ),
                    );
                  }),
                  TextField(
                    controller: asnafCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Adjustment Asnaf'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (saved == true && mounted) {
      setState(() {
        _adjSb = _toIntOrZero(sbCtrl.text);
        _adjAsnaf = _toIntOrZero(asnafCtrl.text);
        _adjAmilChildren = amilCtrls
            .map((controller) => _toIntOrZero(controller.text))
            .toList();
      });
    }

    sbCtrl.dispose();
    asnafCtrl.dispose();
    for (final controller in amilCtrls) {
      controller.dispose();
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
  }) {
    final amilAdjustments = List<int>.generate(
      amilChildren.length,
      (index) => index < _adjAmilChildren.length ? _adjAmilChildren[index] : 0,
    );

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
        'sb': _adjSb,
        'amil_children': List.generate(
          amilChildren.length,
          (index) => {
            'label': amilChildren[index].label,
            'value': amilAdjustments[index],
          },
        ),
        'asnaf': _adjAsnaf,
      },
      'result': {
        'jumlah': totalAdjusted,
        'sb': sbBase + _adjSb,
        'amil_children': List.generate(
          amilChildren.length,
          (index) => {
            'label': amilChildren[index].label,
            'value': (index < amilBase.length ? amilBase[index] : 0) +
                amilAdjustments[index],
          },
        ),
        'asnaf': asnafBase + _adjAsnaf,
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
        final externalRiceSouls = externalFamilies
            .fold<int>(0, (sum, e) => sum + e.externalTotalRiceSouls)
            .toDouble();
        final externalAmount = externalFamilies.fold<double>(
          0,
          (sum, e) => sum + _parseAmount(e.externalTotalAmount),
        );

        final fallbackTotalSo = totalSoRegistered + externalRiceSouls;
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
                _AmilChildConfig(label: 'AMIL', percent: _jatahAmil),
              ];
        _syncAdjustmentChildren(amilChildren.length);

        final sbCount = (totalWajibZakat * sbPercent).round();
        final amilTotalCount = (totalWajibZakat * amilPercent).round();
        final amilChildCounts = _splitAmilCount(amilTotalCount, amilChildren);
        final asnafCount = totalWajibZakat - sbCount - amilTotalCount;
        final totalPembagian = sbCount + amilTotalCount + asnafCount;

        final wajibZakatAmount = totalWajibZakat * _titipUang;
        final sbAmount = sbCount * _titipUang;
        final amilChildAmounts =
            _splitAmilAmount(amilChildCounts, amilChildren);
        final asnafAmount = asnafCount * _titipUang;
        final amilTotalAmount =
            amilChildAmounts.fold<double>(0, (sum, amount) => sum + amount);
        final totalPembagianAmount = sbAmount + amilTotalAmount + asnafAmount;

        final adjustedSb = sbCount + _adjSb;
        final adjustedAmilChildren = List<int>.generate(
          amilChildren.length,
          (index) => amilChildCounts[index] + _adjAmilChildren[index],
        );
        final adjustedAsnaf = asnafCount + _adjAsnaf;
        final adjustmentTotal = _adjSb +
            _adjAmilChildren.fold<int>(0, (sum, v) => sum + v) +
            _adjAsnaf;
        final adjustedTotal = adjustedSb +
            adjustedAmilChildren.fold<int>(0, (sum, v) => sum + v) +
            adjustedAsnaf;
        final adjustedJumlah = totalWajibZakat + adjustmentTotal;

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
          await Future.wait<void>([
            provider.fetchMuzakki(),
            provider.fetchLaporanSummary(),
            if (selectedYearId.isNotEmpty) _loadMustahiqRecap(selectedYearId),
          ]);
          await _loadDistributionConfig();
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
                      onPressed: () => _showAdjustmentDialog(amilChildren),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _distMergedHeaderStrip(amilChildren.length),
                            Table(
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              columnWidths: distColumnWidths,
                              border: const TableBorder(
                                left: BorderSide(color: Color(0xFFCBD5E1)),
                                right: BorderSide(color: Color(0xFFCBD5E1)),
                                bottom: BorderSide(color: Color(0xFFCBD5E1)),
                                horizontalInside:
                                    BorderSide(color: Color(0xFFCBD5E1)),
                                verticalInside:
                                    BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              children: [
                                _distSubHeaderRow(
                                  sbPercent: _jatahSb,
                                  amilChildren: amilChildren,
                                  asnafPercent: _jatahAsnaf,
                                ),
                                _distDataRow(
                                  label: 'Wajib Zakat',
                                  jumlah: totalWajibZakat,
                                  sb: sbCount,
                                  amilChildren: amilChildCounts,
                                  asnaf: asnafCount,
                                  total: totalPembagian,
                                ),
                                _distDataRow(
                                  label: 'Adjustment',
                                  jumlah: adjustmentTotal,
                                  sb: _adjSb,
                                  amilChildren: _adjAmilChildren,
                                  asnaf: _adjAsnaf,
                                  total: adjustmentTotal,
                                ),
                                _distCurrencyRow(
                                  label: 'Konversi Rupiah',
                                  jumlah: wajibZakatAmount,
                                  sb: sbAmount,
                                  amilChildren: amilChildAmounts,
                                  asnaf: asnafAmount,
                                  total: totalPembagianAmount,
                                ),
                                _distDataRow(
                                  label: 'Total Pembagian',
                                  jumlah: adjustedJumlah,
                                  sb: adjustedSb,
                                  amilChildren: adjustedAmilChildren,
                                  asnaf: adjustedAsnaf,
                                  total: adjustedTotal,
                                  isTotal: true,
                                ),
                              ],
                            ),
                          ],
                        ),
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
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final payload = _buildSavePayload(
                              yearId: provider.selectedYear?.id ?? '',
                              yearLabel: yearLabel,
                              wajibZakat: totalWajibZakat,
                              sbBase: sbCount,
                              amilBase: amilChildCounts,
                              asnafBase: asnafCount,
                              totalBase: totalPembagian,
                              adjustmentTotal: adjustmentTotal,
                              totalAdjusted: adjustedTotal,
                              amilChildren: amilChildren,
                            );

                            final payloadText =
                                const JsonEncoder.withIndent('  ')
                                    .convert(payload);
                            await Clipboard.setData(
                                ClipboardData(text: payloadText));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Payload laporan disalin. Endpoint API bisa dibuat berdasarkan payload ini.'),
                              ),
                            );

                            if (!context.mounted) return;
                            await showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Payload Simpan Laporan'),
                                content: SizedBox(
                                  width: 520,
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      payloadText,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Tutup'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('Simpan Laporan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _buildMustahiqRecapCard(),

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

                const SizedBox(height: 28),

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
    required List<_AmilChildConfig> amilChildren,
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
        _cell('', style: style, align: TextAlign.left),
        _cell('', style: style),
        _cell('${asnafPercent.toStringAsFixed(0)}%', style: style),
        ...amilChildren.map(
          (c) => _cell('${c.label} ${c.percent.toStringAsFixed(0)}%',
              style: style),
        ),
        _cell('${sbPercent.toStringAsFixed(0)}%', style: style),
        _cell(
          '${(sbPercent + amilChildren.fold<double>(0, (s, c) => s + c.percent) + asnafPercent).toStringAsFixed(0)}%',
          style: style,
        ),
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
  }) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
      color: const Color(0xFF1A1A1A),
    );
    return TableRow(
      decoration: BoxDecoration(
        color: isTotal ? const Color(0xFFE2E8F0) : Colors.white,
      ),
      children: [
        _cell(label, style: style, align: TextAlign.left),
        _cell('$jumlah', style: style),
        _cell('$asnaf', style: style),
        ...amilChildren.map((v) => _cell('$v', style: style)),
        _cell('$sb', style: style),
        _cell('$total', style: style),
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
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A1A1A),
    );
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFFFF7ED)),
      children: [
        _cell(label, style: style, align: TextAlign.left),
        _cell(_formatRupiahFull(jumlah), style: style),
        _cell(_formatRupiahFull(asnaf), style: style),
        ...amilChildren.map((v) => _cell(_formatRupiahFull(v), style: style)),
        _cell(_formatRupiahFull(sb), style: style),
        _cell(_formatRupiahFull(total), style: style),
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

  Widget _buildMustahiqRecapCard() {
    final totalSouls =
        _mustahiqRecapRows.fold<int>(0, (sum, item) => sum + item.souls);
    final totalJatahSo = _mustahiqRecapRows.fold<double>(
      0,
      (sum, item) => sum + item.totalJatahSo,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 8),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 42,
                columns: const [
                  DataColumn(label: Text('Asnaf Type')),
                  DataColumn(label: Text('Nama')),
                  DataColumn(numeric: true, label: Text('Jiwa')),
                  DataColumn(numeric: true, label: Text('Total Jatah So')),
                ],
                rows: [
                  ..._mustahiqRecapRows.map(
                    (item) => DataRow(
                      cells: [
                        DataCell(Text(item.asnafLabel)),
                        DataCell(Text(item.name)),
                        DataCell(Text('${item.souls}')),
                        DataCell(Text(item.totalJatahSo.toStringAsFixed(2))),
                      ],
                    ),
                  ),
                  DataRow(
                    color: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                    cells: [
                      const DataCell(
                        Text(
                          'TOTAL',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const DataCell(SizedBox.shrink()),
                      DataCell(
                        Text(
                          '$totalSouls',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(
                        Text(
                          totalJatahSo.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
}

class _AmilChildConfig {
  const _AmilChildConfig({required this.label, required this.percent});

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

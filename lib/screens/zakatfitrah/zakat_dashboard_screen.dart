import '../../config/baraka_tokens.dart';
import '../../utils/external_breakdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/zakat_transaction.dart';
import '../../models/muzakki.dart';
import '../../providers/configuration_provider.dart';
import '../../providers/zakat_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ZakatBerandaBody — body-only widget for the Beranda tab.
// Shell (ZakatShellScreen) owns the Scaffold + AppBar.
// ─────────────────────────────────────────────────────────────────────────────
class ZakatBerandaBody extends StatefulWidget {
  const ZakatBerandaBody({super.key});

  @override
  State<ZakatBerandaBody> createState() => _ZakatBerandaBodyState();
}

class _ZakatBerandaBodyState extends State<ZakatBerandaBody> {
  bool _showAllRecent = false;
  static const _green = Color(0xFF066046);

  double _parseAmount(String raw) {
    return double.tryParse(raw) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<ZakatProvider>();
      final cfg = context.read<ConfigurationProvider>();

      // Every request below is per year: wait until a year is selected, even
      // when the shell is already loading the years.
      await p.ensureYears();
      if (!mounted) return;

      if (p.muzakkiList.isEmpty && !p.isLoading) {
        await p.fetchMuzakki();
      }

      if (p.externals.isEmpty && !p.isLoadingExternals) {
        p.fetchExternals();
      }

      if (cfg.configurations.isEmpty && !cfg.isLoading) {
        cfg.fetchConfigurations(
          module: ConfigurationProvider.moduleZakatFitrah,
          yearId: p.selectedYear?.id,
        );
      }

      if (p.recentTransactions.isEmpty && !p.isLoadingRecent) {
        await p.fetchRecentTransactions();
      }

      if (p.reportSummary == null && !p.isLoadingReportSummary) {
        await p.fetchLaporanSummary();
      }

      if (p.mustahiqAsnafSummary.isEmpty && !p.isLoadingMustahiqAsnafSummary) {
        await p.fetchMustahiqAsnafSummary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ZakatProvider>(
      builder: (context, provider, _) {
        final summary = provider.reportSummary;
        final externalFamilies = provider.externalByFamily.values;
        final externalSouls = externalFamilies.fold<int>(
            0, (sum, e) => sum + e.externalTotalSouls);
        final externalRiceSoulsNonRegistered = externalFamilies.fold<int>(
            0, (sum, e) => sum + e.externalTotalRiceSouls);
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

        final externalRiceSouls =
            externalRegisteredRiceSouls + externalRiceSoulsNonRegistered;
        final externalMoneySouls =
            externalRegisteredMoneySouls + externalMoneySoulsNonRegistered;
        final externalAmount = externalFamilies.fold<double>(
          0,
          (sum, e) => sum + _parseAmount(e.externalTotalAmount),
        );
        final moneyRatePerSoul = (provider.selectedYear?.riceRatePerSo ?? 0) > 0
            ? provider.selectedYear!.riceRatePerSo
            : 45000.0;

        final internalRiceSouls = provider.muzakkiList
            .where((m) => m.isInternal && m.paymentType == PaymentType.beras)
            .fold<int>(
                0,
                (sum, m) =>
                    sum + (m.numberOfPeople > 0 ? m.numberOfPeople : 1));
        final internalMoneySouls = provider.muzakkiList
            .where((m) => m.isInternal && m.paymentType == PaymentType.uang)
            .fold<int>(
                0,
                (sum, m) =>
                    sum + (m.numberOfPeople > 0 ? m.numberOfPeople : 1));
        final internalRiceSo = provider.muzakkiList
            .where((m) => m.isInternal && m.paymentType == PaymentType.beras)
            .fold<double>(
              0,
              (sum, m) =>
                  sum +
                  (m.amountSo > 0
                      ? m.amountSo
                      : (m.numberOfPeople > 0 ? m.numberOfPeople : 1)
                          .toDouble()),
            );
        final externalRiceSoRegistered = provider.muzakkiList
            .where((m) => !m.isInternal && m.paymentType == PaymentType.beras)
            .fold<double>(
              0,
              (sum, m) =>
                  sum +
                  (m.amountSo > 0
                      ? m.amountSo
                      : (m.numberOfPeople > 0 ? m.numberOfPeople : 1)
                          .toDouble()),
            );
        final internalMoneyAmount = provider.muzakkiList
            .where((m) => m.isInternal && m.paymentType == PaymentType.uang)
            .fold<double>(
              0,
              (sum, m) =>
                  sum +
                  (m.amountRp > 0
                      ? m.amountRp
                      : (m.numberOfPeople > 0 ? m.numberOfPeople : 1) *
                          moneyRatePerSoul),
            );
        final externalRegisteredMoneyAmount = provider.muzakkiList
            .where((m) => !m.isInternal && m.paymentType == PaymentType.uang)
            .fold<double>(
              0,
              (sum, m) =>
                  sum +
                  (m.amountRp > 0
                      ? m.amountRp
                      : (m.numberOfPeople > 0 ? m.numberOfPeople : 1) *
                          moneyRatePerSoul),
            );

        final totalSoulsOverall = summary?.summary.totalSoulsOverall ??
            provider.totalJiwa + externalSouls;
        final totalInternal =
            summary?.summary.totalInternalMuzakki ?? provider.totalMuzakki;
        final externalRegistered = summary?.summary.totalExternalMuzakki ??
            provider.muzakkiList.where((m) => !m.isInternal).length;
        final externalNonRegistered =
            summary?.summary.totalExternalSouls ?? externalSouls;
        final totalExternal = externalRegistered + externalNonRegistered;
        final totalMuzakkiOverall = totalInternal + totalExternal;
        final totalRegisteredMuzakki = provider.muzakkiList.length;
        final paidRegisteredMuzakki =
            provider.muzakkiList.where((m) => m.isPaid).length;
        final collectedPercent = totalRegisteredMuzakki > 0
            ? (paidRegisteredMuzakki / totalRegisteredMuzakki) * 100
            : 0.0;
        final collectedProgress = totalRegisteredMuzakki > 0
            ? (paidRegisteredMuzakki / totalRegisteredMuzakki)
                .clamp(0.0, 1.0)
                .toDouble()
            : 0.0;

        final moneySouls = internalMoneySouls + externalMoneySouls;

        final externalRiceSo = externalRiceSoRegistered +
            externalRiceSoulsNonRegistered.toDouble();
        final totalSo = internalRiceSo + externalRiceSo;
        final externalMoneyAmount = externalAmount > 0
            ? externalAmount
            : externalMoneySoulsNonRegistered * moneyRatePerSoul;
        final externalMoneyAmountTotal =
            externalRegisteredMoneyAmount + externalMoneyAmount;
        final totalRp = internalMoneyAmount + externalMoneyAmountTotal;

        // The internal row is named after the GROUP value set in Configuration.
        final groupLabel = context
                .watch<ConfigurationProvider>()
                .configurations
                .where((c) => c.code == 'GROUP' && c.value.trim().isNotEmpty)
                .map((c) => c.value.trim())
                .firstOrNull ??
            externalInternalLabel;

        // "Rincian per Grup": one row per Master Eksternal.
        final breakdown = buildExternalBreakdown(
          muzakkiList: provider.muzakkiList,
          externalFamilies: externalFamilies,
          masters: provider.externals,
          moneyRatePerSoul: moneyRatePerSoul,
          internalLabel: groupLabel,
        );
        final namedExternals =
            breakdown.where((r) => r.kind == ExternalRowKind.external).toList();
        final breakdownMoneySouls =
            breakdown.fold<int>(0, (s, r) => s + r.moneySouls);
        final breakdownRiceSouls =
            breakdown.fold<int>(0, (s, r) => s + r.riceSouls);
        final breakdownMoneyAmount =
            breakdown.fold<double>(0, (s, r) => s + r.moneyAmount);

        final perGroupRows = <TableRow>[
          _groupTableHeaderRow(),
        ];
        final asnafRows = provider.mustahiqAsnafSummary;

        for (final r in breakdown) {
          perGroupRows.add(
            _groupTableDataRow(
              group: r.label,
              subtitle: '${r.people} orang · ${r.paidSouls} jiwa',
              titipUang: '${_formatRupiah(r.moneyAmount)} (${r.moneySouls})',
              titipBeras: '${r.riceSouls}',
            ),
          );
        }

        perGroupRows.add(
          _groupTableDataRow(
            group: 'Total',
            subtitle:
                '${breakdown.fold<int>(0, (s, r) => s + r.people)} orang · ${breakdownRiceSouls + breakdownMoneySouls} jiwa',
            titipUang:
                '${_formatRupiah(breakdownMoneyAmount)} ($breakdownMoneySouls)',
            titipBeras: '$breakdownRiceSouls',
            isTotal: true,
          ),
        );

        return RefreshIndicator(
          color: _green,
          onRefresh: () async {
            await Future.wait([
              provider.fetchMuzakki(),
              provider.fetchLaporanSummary(),
              provider.fetchRecentTransactions(),
              provider.fetchMustahiqAsnafSummary(),
              provider.fetchExternals(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary Cards ──
                _SummaryCard(
                  title: 'Total Muzakki',
                  value: totalMuzakkiOverall.toString(),
                  unit: 'Orang',
                  icon: Icons.people_outline,
                  secondaryValue: '$totalSoulsOverall Jiwa',
                  fullWidth: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Beras',
                        value: totalSo.toStringAsFixed(2),
                        unit: 'So',
                        icon: Icons.rice_bowl_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Uang',
                        value: _formatRupiah(totalRp),
                        unit: '',
                        icon: Icons.payments_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          const Icon(
                            Icons.task_alt_rounded,
                            size: 16,
                            color: _green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sudah Mengumpulkan: $paidRegisteredMuzakki / $totalRegisteredMuzakki (${collectedPercent.toStringAsFixed(1)}%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: collectedProgress,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation(_green),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Ringkasan Laporan (merge dari tab Laporan) ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ringkasan Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (provider.isLoadingReportSummary)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_green),
                        ),
                      )
                    else
                      IconButton(
                        onPressed: () async {
                          await Future.wait([
                            provider.fetchLaporanSummary(),
                            provider.fetchMustahiqAsnafSummary(),
                          ]);
                        },
                        tooltip: 'Refresh ringkasan',
                        icon: const Icon(Icons.refresh_rounded,
                            color: Color(0xFF066046)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Internal',
                          value: totalInternal.toString(),
                          unit: 'Orang',
                          icon: Icons.groups_rounded,
                          secondaryValue: '$totalSoulsOverall Jiwa',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'External',
                          value: totalExternal.toString(),
                          unit: 'Orang',
                          icon: Icons.group_add_outlined,
                          secondaryValue: '$totalExternal Jiwa',
                          details: [
                            for (final r in namedExternals)
                              '- ${r.label} ${r.people} orang',
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.8),
                      1: FlexColumnWidth(1.2),
                    },
                    children: [
                      _tableRow('Titip Beras',
                          '${internalRiceSouls + externalRiceSouls} jiwa'),
                      _tableRow(
                          'Total Beras', '${totalSo.toStringAsFixed(2)} So'),
                      _tableRow('Titip Uang', '$moneySouls jiwa'),
                      _tableRow('Total Uang', _formatRupiah(totalRp)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rincian Asnaf',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (provider.isLoadingMustahiqAsnafSummary)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(_green),
                              ),
                            ),
                          ),
                        )
                      else if (provider.mustahiqAsnafSummaryError != null)
                        Text(
                          provider.mustahiqAsnafSummaryError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB45309),
                          ),
                        )
                      else if (asnafRows.isEmpty)
                        const Text(
                          'Belum ada data rincian asnaf.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        )
                      else
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.4),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                          },
                          children: [
                            _asnafTableHeaderRow(),
                            ...asnafRows.map(
                              (item) => _asnafTableDataRow(
                                asnaf: _formatAsnafType(item.asnafType),
                                souls: '${item.totalSouls}',
                                count: '${item.count}',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Rincian per Grup',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _exportGroupToWhatsApp(
                              context,
                              totalSoulsOverall: totalSoulsOverall,
                              totalSo: totalSo,
                              moneySouls: moneySouls,
                              totalRp: totalRp,
                              rows: breakdown,
                            ),
                            icon: const Icon(Icons.ios_share_rounded, size: 16),
                            label: const Text('Export'),
                            style: TextButton.styleFrom(
                              foregroundColor: _green,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.4),
                          1: FlexColumnWidth(1.3),
                          2: FlexColumnWidth(1.3),
                        },
                        children: perGroupRows,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // // ── Add Muzakki Button ──
                // SizedBox(
                //   width: double.infinity,
                //   height: 52,
                //   child: ElevatedButton.icon(
                //     onPressed: () => context.go('/zakat-fitrah/add'),
                //     icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                //     label: const Text(
                //       'Tambah Muzakki',
                //       style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                //     ),
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: _green,
                //       foregroundColor: Colors.white,
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(12),
                //       ),
                //       elevation: 3,
                //       shadowColor: _green.withOpacity(0.35),
                //     ),
                //   ),
                // ),
                const SizedBox(height: 28),

                // ── Transaksi Terbaru ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Transaksi Terbaru',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (provider.isLoadingRecent)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_green),
                        ),
                      )
                    else if (provider.recentTransactions.isNotEmpty)
                      Text(
                        '${provider.recentTransactions.length} terakhir',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (provider.recentError != null &&
                    provider.recentTransactions.isEmpty)
                  _buildTransactionError(provider)
                else if (provider.recentTransactions.isEmpty &&
                    !provider.isLoadingRecent)
                  _buildEmptyTransactions()
                else
                  _buildRecentList(provider.recentTransactions),
                const SizedBox(height: 24),
              ],
            ),
          ), // SingleChildScrollView
        ); // RefreshIndicator
      },
    );
  }

  String _formatAsnafType(String value) {
    if (value.trim().isEmpty) return '-';

    return value
        .trim()
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  /// Compact list: one card, one row per transaction, 5 rows until expanded.
  Widget _buildRecentList(List<ZakatTransaction> all) {
    const collapsedCount = 5;
    final canExpand = all.length > collapsedCount;
    final rows =
        _showAllRecent || !canExpand ? all : all.sublist(0, collapsedCount);

    return Container(
      decoration: Bk.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Bk.line),
            _TransactionTile(trx: rows[i]),
          ],
          if (canExpand) ...[
            const Divider(height: 1, color: Bk.line),
            InkWell(
              onTap: () => setState(() => _showAllRecent = !_showAllRecent),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    _showAllRecent
                        ? 'Tampilkan lebih sedikit'
                        : 'Lihat semua (${all.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Bk.brand,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFCBD5E1)),
          SizedBox(height: 10),
          Text(
            'Belum ada transaksi',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionError(ZakatProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              provider.recentError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ),
          TextButton(
            onPressed: provider.fetchRecentTransactions,
            child: const Text('Coba lagi',
                style: TextStyle(fontSize: 12, color: Color(0xFF066046))),
          ),
        ],
      ),
    );
  }

  String _formatRupiah(double amount) {
    if (amount == 0) return 'Rp 0';
    if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(3)} jt';
    }
    if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)} rb';
    }
    return 'Rp ${amount.toStringAsFixed(0)}';
  }

  TableRow _tableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }

  TableRow _groupTableHeaderRow() {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF64748B),
    );

    return const TableRow(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Kelompok', style: headerStyle),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Titip Uang',
            textAlign: TextAlign.right,
            style: headerStyle,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Beras',
            textAlign: TextAlign.right,
            style: headerStyle,
          ),
        ),
      ],
    );
  }

  TableRow _asnafTableHeaderRow() {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF64748B),
    );

    return const TableRow(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Asnaf', style: headerStyle),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Jiwa', textAlign: TextAlign.right, style: headerStyle),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Mustahiq',
            textAlign: TextAlign.right,
            style: headerStyle,
          ),
        ),
      ],
    );
  }

  TableRow _asnafTableDataRow({
    required String asnaf,
    required String souls,
    required String count,
  }) {
    const valueStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A1A1A),
    );
    const labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFF334155),
    );

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(asnaf, style: labelStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            souls,
            textAlign: TextAlign.right,
            style: valueStyle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            count,
            textAlign: TextAlign.right,
            style: valueStyle,
          ),
        ),
      ],
    );
  }

  TableRow _groupTableDataRow({
    required String group,
    String? subtitle,
    required String titipUang,
    required String titipBeras,
    bool isTotal = false,
  }) {
    final valueStyle = TextStyle(
      fontSize: 11,
      fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
      color: const Color(0xFF1A1A1A),
    );
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
      color: const Color(0xFF334155),
    );

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: subtitle == null
              ? Text(group, style: labelStyle)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group, style: labelStyle),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            titipUang,
            textAlign: TextAlign.right,
            style: valueStyle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            titipBeras,
            textAlign: TextAlign.right,
            style: valueStyle,
          ),
        ),
      ],
    );
  }

  Future<void> _exportGroupToWhatsApp(
    BuildContext context, {
    required int totalSoulsOverall,
    required double totalSo,
    required int moneySouls,
    required double totalRp,
    required List<ExternalBreakdownRow> rows,
  }) async {
    final buffer = StringBuffer()
      ..writeln('*Ringkasan Pembayaran Zakat Fitrah*')
      ..writeln('')
      ..writeln('Total Jiwa: $totalSoulsOverall')
      ..writeln('Total Beras: ${totalSo.toStringAsFixed(2)} So')
      ..writeln('Titip Uang: $moneySouls jiwa')
      ..writeln('Total Uang: ${_formatRupiah(totalRp)}')
      ..writeln('')
      ..writeln('*Rincian per Grup*');

    for (final r in rows) {
      buffer.writeln(
        '- ${r.label} (${r.people} orang · ${r.paidSouls} jiwa): Beras ${r.riceSouls} • Uang ${_formatRupiah(r.moneyAmount)} (${r.moneySouls})',
      );
    }

    final message = buffer.toString();

    try {
      final uri = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(message)}',
      );
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && context.mounted) {
        await Clipboard.setData(ClipboardData(text: message));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka WhatsApp. Teks export disalin.'),
          ),
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'WhatsApp belum siap di runtime ini. Teks export disalin, lalu lakukan full restart aplikasi.',
          ),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transaction tile — shows a recent payment entry
// ─────────────────────────────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.trx});
  final ZakatTransaction trx;

  @override
  Widget build(BuildContext context) {
    final t = trx;
    final detail = <String>[
      if (t.totalSouls > 0)
        t.externalSouls > 0
            ? '${t.totalSouls} jiwa (+${t.externalSouls} ext)'
            : '${t.totalSouls} jiwa',
      if (t.amilName.isNotEmpty) t.amilName,
      if (t.groupName.isNotEmpty) t.groupName,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Bk.text,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Bk.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          t.isPaid
              ? const BkStatusPill.done('Lunas')
              : const BkStatusPill.pending('Belum'),
        ],
      ),
    );
  }
}

/// Zakat Fitrah module dashboard screen.
/// Design based on Stitch "Dashboard Muzakki (Bahasa Indonesia)"
/// Project: 319654584051873746 | Screen: 2e1226aefae347818c72003bf925e312
class ZakatDashboardScreen extends StatelessWidget {
  const ZakatDashboardScreen({super.key});

  static const _green = Color(0xFF066046);
  static const _bgColor = Color(0xFFF4F7F6);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => context.go('/dashboard'),
          ),
          title: const Text(
            'Zakat Fitrah 1447H',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_outlined,
                  color: Color(0xFF1A1A1A)),
              tooltip: 'Notifikasi',
            ),
          ],
        ),
        body: Consumer<ZakatProvider>(
          builder: (context, provider, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Summary Cards ──
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Muzakki',
                          value: provider.totalMuzakki.toString(),
                          unit: 'KK',
                          icon: Icons.people_outline,
                          secondaryValue: '${provider.totalJiwa} Jiwa',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Beras',
                          value: provider.totalRiceKg.toStringAsFixed(1),
                          unit: 'Kg',
                          icon: Icons.rice_bowl_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    title: 'Total Uang',
                    value: _formatRupiah(provider.totalMoneyRp),
                    unit: '',
                    icon: Icons.payments_outlined,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 24),

                  // ── Add Muzakki Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/zakat-fitrah/add'),
                      icon:
                          const Icon(Icons.person_add_alt_1_outlined, size: 20),
                      label: const Text(
                        'Tambah Muzakki',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        shadowColor: _green.withOpacity(0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Recent Muzakki ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daftar Muzakki Terbaru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (provider.muzakkiList.isNotEmpty)
                        Text(
                          '${provider.muzakkiList.length} data',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (provider.muzakkiList.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.muzakkiList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final m = provider.muzakkiList[index];
                        return _MuzakkiTile(
                          muzakki: m,
                          onDelete: () => _confirmDelete(context, provider, m),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.people_outline, size: 56, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text(
            'Belum ada data muzakki',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tap "Tambah Muzakki" untuk mulai mencatat',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ZakatProvider provider,
    Muzakki muzakki,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Muzakki'),
        content: Text('Hapus data "${muzakki.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      provider.deleteMuzakki(muzakki.id);
    }
  }

  String _formatRupiah(double amount) {
    if (amount == 0) return 'Rp 0';
    if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)} jt';
    }
    if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)} rb';
    }
    return 'Rp ${amount.toStringAsFixed(0)}';
  }
}

// ─────────────────────────────────────────────
// Summary Card Widget
// ─────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.secondaryValue,
    this.details = const [],
    this.fullWidth = false,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final String? secondaryValue;

  /// Optional lines under the value, e.g. "- PPM 12 orang".
  final List<String> details;
  final bool fullWidth;

  static const _green = Color(0xFF066046);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: fullWidth
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _green, size: 22),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: _green, size: 18),
                    ),
                    if (secondaryValue != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              secondaryValue!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _green,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final line in details)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// Muzakki List Tile Widget
// ─────────────────────────────────────────────
class _MuzakkiTile extends StatelessWidget {
  const _MuzakkiTile({
    required this.muzakki,
    required this.onDelete,
  });

  final Muzakki muzakki;
  final VoidCallback onDelete;

  static const _green = Color(0xFF066046);

  @override
  Widget build(BuildContext context) {
    final isBeras = muzakki.paymentType == PaymentType.beras;
    final paymentText = isBeras
        ? '${muzakki.amountSo} So Beras'
        : 'Rp ${muzakki.amountRp.toStringAsFixed(0)}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8F5F0),
          child: Text(
            muzakki.initials,
            style: const TextStyle(
              color: _green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          muzakki.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${muzakki.numberOfPeople} jiwa — $paymentText',
              style: const TextStyle(fontSize: 12),
            ),
            if (muzakki.address.isNotEmpty)
              Text(
                muzakki.address,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    isBeras ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isBeras ? '🌾 Beras' : '💵 Uang',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isBeras ? const Color(0xFFE65100) : _green,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Color(0xFFE57373)),
              onPressed: onDelete,
              tooltip: 'Hapus',
            ),
          ],
        ),
      ),
    );
  }
}

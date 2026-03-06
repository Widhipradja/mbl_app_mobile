import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/zakat_transaction.dart';
import '../../models/muzakki.dart';
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
  static const _green = Color(0xFF066046);

  double _parseAmount(String raw) {
    return double.tryParse(raw) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<ZakatProvider>();

      if (p.years.isEmpty && !p.isLoadingYears) {
        await p.fetchYears();
      }

      if (p.muzakkiList.isEmpty && !p.isLoading) {
        await p.fetchMuzakki();
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

        final internalSoulsGroup = internalRiceSouls + internalMoneySouls;
        final externalSoulsGroup = externalRiceSouls + externalMoneySouls;

        final internalGroupRows = <Map<String, dynamic>>[];
        if (summary != null && summary.internalByAfiliasi.isNotEmpty) {
          for (final group in summary.internalByAfiliasi) {
            internalGroupRows.add({
              'name':
                  group.afiliasi.isNotEmpty ? group.afiliasi : 'Tanpa Group',
              'souls': group.totalSouls,
              'riceSouls': group.riceSouls,
              'moneySouls': group.moneySouls,
              'moneyAmount': group.totalAmount,
            });
          }
        } else {
          final fallback = <String, Map<String, num>>{};
          for (final m in provider.muzakkiList) {
            if (!m.isInternal || !m.isPaid) continue;

            final name = m.groupName.trim().isNotEmpty
                ? m.groupName.trim()
                : 'Tanpa Group';
            final bucket = fallback.putIfAbsent(
              name,
              () => {
                'riceSouls': 0,
                'moneySouls': 0,
                'moneyAmount': 0.0,
              },
            );

            final souls = m.numberOfPeople > 0 ? m.numberOfPeople : 1;
            if (m.paymentType == PaymentType.beras) {
              bucket['riceSouls'] = (bucket['riceSouls'] as int) + souls;
            } else if (m.paymentType == PaymentType.uang) {
              bucket['moneySouls'] = (bucket['moneySouls'] as int) + souls;
              bucket['moneyAmount'] = (bucket['moneyAmount'] as double) +
                  (m.amountRp > 0 ? m.amountRp : souls * moneyRatePerSoul);
            }
          }

          final entries = fallback.entries.toList()
            ..sort(
                (a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
          for (final entry in entries) {
            final rice = entry.value['riceSouls'] as int;
            final money = entry.value['moneySouls'] as int;
            final amount = entry.value['moneyAmount'] as double;
            internalGroupRows.add({
              'name': entry.key,
              'souls': rice + money,
              'riceSouls': rice,
              'moneySouls': money,
              'moneyAmount': amount,
            });
          }
        }

        final perGroupRows = <TableRow>[
          _groupTableHeaderRow(),
        ];
        final asnafRows = provider.mustahiqAsnafSummary;

        for (final row in internalGroupRows) {
          final riceSouls = (row['riceSouls'] as num).toInt();
          final moneySouls = (row['moneySouls'] as num).toInt();
          final moneyAmount = (row['moneyAmount'] as num).toDouble();

          perGroupRows.add(
            _groupTableDataRow(
              group: '${row['name']}',
              titipUang: '${_formatRupiah(moneyAmount)} ($moneySouls)',
              titipBeras: '$riceSouls',
            ),
          );
        }

        perGroupRows.add(
          _groupTableDataRow(
            group: 'External',
            titipUang:
                '${_formatRupiah(externalMoneyAmountTotal)} ($externalMoneySouls)',
            titipBeras: '$externalRiceSouls',
          ),
        );

        perGroupRows.add(
          _groupTableDataRow(
            group: 'Total',
            titipUang: '${_formatRupiah(totalRp)} ($moneySouls)',
            titipBeras: '${internalRiceSouls + externalRiceSouls}',
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
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                        value: totalMuzakkiOverall.toString(),
                        unit: 'Orang',
                        icon: Icons.people_outline,
                        secondaryValue: '$totalSoulsOverall Jiwa',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Beras',
                        value: totalSo.toStringAsFixed(2),
                        unit: 'So',
                        icon: Icons.rice_bowl_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  title: 'Total Uang',
                  value: _formatRupiah(totalRp),
                  unit: '',
                  icon: Icons.payments_outlined,
                  fullWidth: true,
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
                Row(
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
                      ),
                    ),
                  ],
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
                            'Rincian per Group',
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
                              internalGroupRows: internalGroupRows,
                              internalSoulsGroup: internalSoulsGroup,
                              internalRiceSo: internalRiceSo,
                              internalMoneyAmount: internalMoneyAmount,
                              externalSoulsGroup: externalSoulsGroup,
                              externalRiceSo: externalRiceSo,
                              externalRiceSouls: externalRiceSouls,
                              externalMoneySouls: externalMoneySouls,
                              externalMoneyAmountTotal:
                                  externalMoneyAmountTotal,
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
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.recentTransactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _TransactionTile(
                          trx: provider.recentTransactions[index]);
                    },
                  ),
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
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)} jt';
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
          child: Text('Group', style: headerStyle),
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
          child: Text(group, style: labelStyle),
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
    required List<Map<String, dynamic>> internalGroupRows,
    required int internalSoulsGroup,
    required double internalRiceSo,
    required double internalMoneyAmount,
    required int externalSoulsGroup,
    required double externalRiceSo,
    required int externalRiceSouls,
    required int externalMoneySouls,
    required double externalMoneyAmountTotal,
  }) async {
    final buffer = StringBuffer()
      ..writeln('*Ringkasan Pembayaran Zakat Fitrah*')
      ..writeln('')
      ..writeln('Total Jiwa: $totalSoulsOverall')
      ..writeln('Total Beras: ${totalSo.toStringAsFixed(2)} So')
      ..writeln('Titip Uang: $moneySouls jiwa')
      ..writeln('Total Uang: ${_formatRupiah(totalRp)}')
      ..writeln('')
      ..writeln('*Rincian per Group*');

    for (final row in internalGroupRows) {
      buffer.writeln(
        '- ${row['name']}: Beras ${row['riceSouls']} • Uang ${_formatRupiah((row['moneyAmount'] as num).toDouble())} (${row['moneySouls']})',
      );
    }

    buffer.writeln(
      '- External: Beras $externalRiceSouls • Uang ${_formatRupiah(externalMoneyAmountTotal)} ($externalMoneySouls)',
    );
    buffer
      ..writeln('')
      ..writeln('*Total per Kategori*')
      ..writeln(
        '- Internal Total: $internalSoulsGroup jiwa • ${internalRiceSo.toStringAsFixed(2)} So • ${_formatRupiah(internalMoneyAmount)}',
      )
      ..writeln(
        '- External Total: $externalSoulsGroup jiwa • ${externalRiceSo.toStringAsFixed(2)} So • ${_formatRupiah(externalMoneyAmountTotal)}',
      );

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

  static const _green = Color(0xFF066046);

  @override
  Widget build(BuildContext context) {
    final t = trx;
    final isMale = t.isMale;
    final soulsText = t.externalSouls > 0
        ? '${t.totalSouls} jiwa (+${t.externalSouls} external)'
        : '${t.totalSouls} jiwa';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: t.isPaid ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor:
                isMale ? const Color(0xFFE8F5F0) : const Color(0xFFFCE4EC),
            child: Text(
              t.initials,
              style: TextStyle(
                color: isMale ? _green : const Color(0xFFC2185B),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + detail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (t.groupName.isNotEmpty) ...[
                      Text(
                        t.groupName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const Text(' · ',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFFCBD5E1))),
                    ],
                    Text(
                      t.relationship.isNotEmpty
                          ? t.relationship
                          : (isMale ? 'L' : 'P'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                if (t.totalSouls > 0 || t.amilName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    t.amilName.isNotEmpty
                        ? '$soulsText · Amil: ${t.amilName}'
                        : soulsText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Payment badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:
                  t.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              t.isPaid ? '✓ Lunas' : '⋯ Belum',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: t.isPaid
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ),
          ),
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
    return Scaffold(
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
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                    label: const Text(
                      'Tambah Muzakki',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
    this.fullWidth = false,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final String? secondaryValue;
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: _green, size: 18),
                    ),
                    if (secondaryValue != null)
                      Container(
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
                          style: const TextStyle(
                            color: _green,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
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

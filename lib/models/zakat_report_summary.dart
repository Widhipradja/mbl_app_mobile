double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  return null;
}

class ReportSummaryTotals {
  final int totalMuzakki;
  final int totalRegisteredSouls;
  final int totalInternalMuzakki;
  final int totalExternalMuzakki;
  final int totalExternalSouls;
  final int totalSoulsOverall;

  const ReportSummaryTotals({
    required this.totalMuzakki,
    required this.totalRegisteredSouls,
    required this.totalInternalMuzakki,
    required this.totalExternalMuzakki,
    required this.totalExternalSouls,
    required this.totalSoulsOverall,
  });

  factory ReportSummaryTotals.fromJson(Map<String, dynamic> json) {
    final totalMuzakki = _toInt(json['total_muzakki']);
    final totalRegisteredSouls = _toInt(json['total_registered_souls']);
    final totalInternalMuzakki = _toInt(json['total_internal_muzakki']);
    final totalExternalMuzakki = _toInt(json['total_external_muzakki']);
    final totalExternalSouls = _toInt(json['total_external_souls']);
    final totalSoulsOverall = _toInt(json['total_souls_overall']);

    return ReportSummaryTotals(
      totalMuzakki: totalMuzakki,
      totalRegisteredSouls: totalRegisteredSouls,
      totalInternalMuzakki: totalInternalMuzakki,
      totalExternalMuzakki: totalExternalMuzakki,
      totalExternalSouls: totalExternalSouls,
      totalSoulsOverall: totalSoulsOverall > 0
          ? totalSoulsOverall
          : totalRegisteredSouls + totalExternalSouls,
    );
  }
}

class PaymentLineSummary {
  final int registeredCount;
  final int externalSouls;
  final int totalSouls;
  final double totalSo;
  final double totalAmount;

  const PaymentLineSummary({
    required this.registeredCount,
    required this.externalSouls,
    required this.totalSouls,
    required this.totalSo,
    required this.totalAmount,
  });

  factory PaymentLineSummary.fromJson(Map<String, dynamic> json) {
    final registeredCount = _toInt(json['registered_count']);
    final externalSouls = _toInt(json['external_souls']);
    final totalSouls = _toInt(json['total_souls']);

    return PaymentLineSummary(
      registeredCount: registeredCount,
      externalSouls: externalSouls,
      totalSouls: totalSouls > 0 ? totalSouls : registeredCount + externalSouls,
      totalSo: _toDouble(json['total_so']),
      totalAmount: _toDouble(json['total_amount']),
    );
  }
}

class PaymentSummary {
  final PaymentLineSummary rice;
  final PaymentLineSummary money;

  const PaymentSummary({required this.rice, required this.money});

  factory PaymentSummary.fromJson(Map<String, dynamic> json) => PaymentSummary(
        rice: PaymentLineSummary.fromJson(
            json['rice'] as Map<String, dynamic>? ?? {}),
        money: PaymentLineSummary.fromJson(
            json['money'] as Map<String, dynamic>? ?? {}),
      );
}

class ExternalBreakdownSummary {
  final int riceSouls;
  final int moneySouls;
  final double totalAmount;

  const ExternalBreakdownSummary({
    required this.riceSouls,
    required this.moneySouls,
    required this.totalAmount,
  });

  factory ExternalBreakdownSummary.fromJson(Map<String, dynamic> json) =>
      ExternalBreakdownSummary(
        riceSouls: _toInt(json['rice_souls']),
        moneySouls: _toInt(json['money_souls']),
        totalAmount: _toDouble(json['total_amount']),
      );
}

class InternalByGroupSummary {
  final String groupName;
  final int riceSouls;
  final int moneySouls;
  final int totalSouls;
  final double totalAmount;

  const InternalByGroupSummary({
    required this.groupName,
    required this.riceSouls,
    required this.moneySouls,
    required this.totalSouls,
    required this.totalAmount,
  });

  factory InternalByGroupSummary.fromJson(Map<String, dynamic> json) {
    final riceSouls = _toInt(json['rice_souls']);
    final moneySouls = _toInt(json['money_souls']);
    final totalSouls = _toInt(json['total_souls']);

    return InternalByGroupSummary(
      groupName: (json['group_name'] as String?)?.trim().isNotEmpty == true
          ? (json['group_name'] as String).trim()
          : 'Tanpa Group',
      riceSouls: riceSouls,
      moneySouls: moneySouls,
      totalSouls: totalSouls > 0 ? totalSouls : riceSouls + moneySouls,
      totalAmount: _toDouble(json['total_amount']),
    );
  }
}

class ZakatReportSummary {
  final String yearId;
  final int year;
  final String yearLabel;
  final ReportSummaryTotals summary;
  final PaymentSummary paymentSummary;
  final ExternalBreakdownSummary? internalBreakdown;
  final ExternalBreakdownSummary? externalBreakdown;
  final List<InternalByGroupSummary> internalByGroup;
  final DateTime? updatedAt;

  const ZakatReportSummary({
    required this.yearId,
    required this.year,
    required this.yearLabel,
    required this.summary,
    required this.paymentSummary,
    this.internalBreakdown,
    this.externalBreakdown,
    this.internalByGroup = const [],
    this.updatedAt,
  });

  factory ZakatReportSummary.fromJson(Map<String, dynamic> json) {
    final summary = ReportSummaryTotals.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {});

    return ZakatReportSummary(
      yearId: json['year_id'] as String? ?? '',
      year: _toInt(json['year']),
      yearLabel: json['year_label'] as String? ?? '',
      summary: summary,
      paymentSummary:
          PaymentSummary.fromJson(_asMap(json['payment_summary']) ?? {}),
      internalBreakdown: _asMap(json['internal_breakdown']) != null
          ? ExternalBreakdownSummary.fromJson(
              _asMap(json['internal_breakdown'])!,
            )
          : null,
      externalBreakdown: _asMap(json['external_breakdown']) != null
          ? ExternalBreakdownSummary.fromJson(
              _asMap(json['external_breakdown'])!,
            )
          : null,
      internalByGroup: (json['internal_by_group'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(InternalByGroupSummary.fromJson)
          .toList(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

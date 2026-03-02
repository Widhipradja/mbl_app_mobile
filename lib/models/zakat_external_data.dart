class ExternalSoul {
  final String id;
  final String transactionId;
  final String representativeMuzakkiId;
  final String familyId;
  final String yearId;
  final String paymentType;
  final int souls;
  final String amount;
  final String notes;
  final DateTime createdAt;
  final String createdBy;

  const ExternalSoul({
    required this.id,
    required this.transactionId,
    required this.representativeMuzakkiId,
    required this.familyId,
    required this.yearId,
    required this.paymentType,
    required this.souls,
    required this.amount,
    required this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  factory ExternalSoul.fromJson(Map<String, dynamic> json) => ExternalSoul(
        id: json['id'] as String? ?? '',
        transactionId: json['transaction_id'] as String? ?? '',
        representativeMuzakkiId:
            json['representative_muzakki_id'] as String? ?? '',
        familyId: json['family_id'] as String? ?? '',
        yearId: json['year_id'] as String? ?? '',
        paymentType: json['payment_type'] as String? ?? '',
        souls: (json['souls'] as num?)?.toInt() ?? 0,
        amount: json['amount']?.toString() ?? '0',
        notes: json['notes'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        createdBy: json['created_by'] as String? ?? '',
      );
}

class FamilyExternalData {
  final String familyId;
  final List<ExternalSoul> externalSouls;
  final int externalTotalSouls;
  final int externalTotalRiceSouls;
  final int externalTotalMoneySouls;
  final String externalTotalAmount;

  const FamilyExternalData({
    required this.familyId,
    required this.externalSouls,
    required this.externalTotalSouls,
    required this.externalTotalRiceSouls,
    required this.externalTotalMoneySouls,
    required this.externalTotalAmount,
  });

  bool get hasExternalSouls => externalTotalSouls > 0;

  factory FamilyExternalData.fromJson(Map<String, dynamic> json) {
    final soulsRaw = json['external_souls'] as List<dynamic>? ?? [];
    return FamilyExternalData(
      familyId: json['family_id'] as String? ?? '',
      externalSouls: soulsRaw
          .map((j) => ExternalSoul.fromJson(j as Map<String, dynamic>))
          .toList(),
      externalTotalSouls: (json['external_total_souls'] as num?)?.toInt() ?? 0,
      externalTotalRiceSouls:
          (json['external_total_rice_souls'] as num?)?.toInt() ?? 0,
      externalTotalMoneySouls:
          (json['external_total_money_souls'] as num?)?.toInt() ?? 0,
      externalTotalAmount: json['external_total_amount']?.toString() ?? '0',
    );
  }
}

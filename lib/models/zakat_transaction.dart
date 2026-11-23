import 'zakat_year.dart';

/// A recent zakat payment transaction from
/// `GET /api/zakat-fitrah/transaction/recent`
class ZakatTransaction {
  final String id;
  final String muzakkiId;
  final String memberId;
  final String familyId;
  final String yearId;
  final ZakatYear? zakatYear;

  final String muzakkiName;
  final String firstName;
  final String lastName;
  final String surname;
  final String sex;
  final String relationship;
  final bool isHeadOfFamily;
  final bool isInternal;
  final String address;
  final String groupName;
  final String yearLabel;
  final int hijriYear;
  final DateTime createdAt;

  /// Payment status
  final bool isPaid;

  /// Payment type: "beras" | "uang" etc. (optional, may be null if not paid)
  final String? paymentType;
  final int quantity;
  final int totalSouls;
  final int externalSouls;
  final String amilName;
  final double amountSo;
  final double amountRp;

  ZakatTransaction({
    required this.id,
    required this.muzakkiId,
    required this.memberId,
    required this.familyId,
    required this.yearId,
    this.zakatYear,
    this.muzakkiName = '',
    required this.firstName,
    this.lastName = '',
    this.surname = '',
    this.sex = 'M',
    this.relationship = '',
    this.isHeadOfFamily = false,
    this.isInternal = true,
    this.address = '',
    this.groupName = '',
    this.yearLabel = '',
    this.hijriYear = 0,
    required this.createdAt,
    this.isPaid = false,
    this.paymentType,
    this.quantity = 0,
    this.totalSouls = 0,
    this.externalSouls = 0,
    this.amilName = '',
    this.amountSo = 0,
    this.amountRp = 0,
  });

  String get fullName {
    if (muzakkiName.isNotEmpty) return muzakkiName;
    final parts = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    return parts.isNotEmpty ? parts : firstName;
  }

  String get initials =>
      firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

  bool get isMale => sex == 'M';

  bool get isBeras {
    final type = paymentType?.toLowerCase() ?? '';
    return type.contains('beras') || type.contains('rice') || amountSo > 0;
  }

  factory ZakatTransaction.fromJson(Map<String, dynamic> json) {
    final paymentType = json['payment_type'] as String?;
    final quantity = (json['quantity'] as num?)?.toInt() ?? 0;
    final totalSouls = (json['total_souls'] as num?)?.toInt() ?? 0;
    final amountFromString =
        double.tryParse(json['amount']?.toString() ?? '0') ?? 0;
    final amountRp =
        (json['amount_rp'] as num?)?.toDouble() ?? amountFromString;
    final isPaid = (json['is_paid'] as bool?) ??
        ((paymentType?.isNotEmpty ?? false) ||
            quantity > 0 ||
            totalSouls > 0 ||
            amountRp > 0);

    return ZakatTransaction(
      id: json['id'] as String? ?? '',
      muzakkiId:
          json['muzakki_id'] as String? ?? json['member_id'] as String? ?? '',
      memberId:
          json['member_id'] as String? ?? json['muzakki_id'] as String? ?? '',
      familyId: json['family_id'] as String? ?? '',
      yearId: json['year_id'] as String? ?? '',
      zakatYear: json['zakat_year'] != null
          ? ZakatYear.fromJson(json['zakat_year'] as Map<String, dynamic>)
          : null,
      muzakkiName: json['muzakki_name'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      surname: json['surname'] as String? ?? '',
      sex: json['sex'] as String? ?? 'M',
      relationship: json['relationship'] as String? ?? '',
      isHeadOfFamily: json['is_head_of_family'] as bool? ?? false,
      isInternal: json['is_internal'] as bool? ?? true,
      address: json['address'] as String? ?? '',
      groupName: json['group_name'] as String? ?? '',
      yearLabel: json['year_label'] as String? ?? '',
      hijriYear: (json['hijri_year'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isPaid: isPaid,
      paymentType: paymentType,
      quantity: quantity,
      totalSouls: totalSouls,
      externalSouls: (json['external_souls'] as num?)?.toInt() ?? 0,
      amilName: json['amil_name'] as String? ?? '',
      amountSo: (json['amount_so'] as num?)?.toDouble() ??
          ((paymentType == 'rice' || paymentType == 'beras')
              ? quantity.toDouble()
              : 0),
      amountRp: amountRp,
    );
  }
}

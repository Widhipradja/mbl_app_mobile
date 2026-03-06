import 'zakat_year.dart';

enum PaymentType { beras, uang }

/// Muzakki model matching the
/// `GET /api/zakat-fitrah/years/{yearId}/muzakki/status` response.
class Muzakki {
  final String id;
  final String memberId;
  final String familyId;
  final String yearId;
  final ZakatYear? zakatYear;

  final String firstName;
  final String lastName;
  final String surname;

  /// "M" = Laki-laki, "F" = Perempuan
  final String sex;

  /// e.g. "Suami", "Istri", "Anak"
  final String relationship;

  /// True if this member is the head of the family (KK)
  final bool isHeadOfFamily;

  final String address;
  final String phone;
  final String groupName;
  final String afiliasi;
  final DateTime createdAt;
  final bool isInternal;

  /// Payment status
  final bool isPaid;

  /// Receiver amil name from transaction data.
  final String amilName;

  /// True when the muzakki's zakat has been formally handed over (akad) to amil.
  /// Driven by the `is_akad_done` flag on the muzakki record.
  final bool isAkadDone;

  // ── Optional zakat fields (future API) ───────────────────────────────────
  final PaymentType? paymentType;
  final double amountSo;
  final double amountRp;
  final int numberOfPeople;

  Muzakki({
    required this.id,
    required this.memberId,
    required this.familyId,
    this.yearId = '',
    this.zakatYear,
    required this.firstName,
    this.lastName = '',
    this.surname = '',
    this.sex = 'M',
    this.relationship = '',
    this.isHeadOfFamily = false,
    this.address = '',
    this.phone = '',
    this.groupName = '',
    this.afiliasi = '',
    DateTime? createdAt,
    this.isInternal = true,
    this.isPaid = false,
    this.amilName = '',
    this.isAkadDone = false,
    this.paymentType,
    this.amountSo = 0,
    this.amountRp = 0,
    this.numberOfPeople = 1,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Full display name: "Abdul Aziz".
  String get fullName {
    final parts = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    return parts.isNotEmpty ? parts : firstName;
  }

  /// Uppercase initial for avatar.
  String get initials =>
      firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

  bool get isMale => sex == 'M';

  /// True when the muzakki's zakat has been formally handed over (akad) to amil.
  /// Driven by the `is_akad_done` flag on the muzakki record.
  bool get isSerahTerimaAmil => isAkadDone;

  /// Sort order within a family: head first, then Suami=0, Istri=1, Anak=2, Other=3
  int get relationshipOrder {
    if (isHeadOfFamily) return -1; // always first
    switch (relationship.toLowerCase()) {
      case 'suami':
        return 0;
      case 'istri':
        return 1;
      case 'anak':
        return 2;
      default:
        return 3;
    }
  }

  factory Muzakki.fromJson(Map<String, dynamic> json) => Muzakki(
        id: json['id'] as String? ?? '',
        memberId: json['member_id'] as String? ?? '',
        familyId: json['family_id'] as String? ?? '',
        yearId: json['year_id'] as String? ?? '',
        zakatYear: json['zakat_year'] != null
            ? ZakatYear.fromJson(json['zakat_year'] as Map<String, dynamic>)
            : null,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        surname: json['surname'] as String? ?? '',
        sex: json['sex'] as String? ?? 'M',
        relationship: json['relationship'] as String? ?? '',
        isHeadOfFamily: json['is_head_of_family'] as bool? ?? false,
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        groupName: json['group_name'] as String? ?? '',
        afiliasi: json['afiliasi'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        isInternal: json['is_internal'] as bool? ?? true,
        isPaid: json['is_paid'] as bool? ?? false,
        isAkadDone: json['is_akad_done'] as bool? ?? false,
        amilName: () {
          final tx = json['transaction'] as Map<String, dynamic>?;
          return tx?['amil_name'] as String? ??
              json['amil_name'] as String? ??
              '';
        }(),
        paymentType: () {
          final tx = json['transaction'] as Map<String, dynamic>?;
          final transactionType = tx?['payment_type'] as String?;
          if (transactionType == 'money') return PaymentType.uang;
          if (transactionType == 'rice') return PaymentType.beras;

          final zakatType = json['zakat_type'] as String?;
          if (zakatType == 'uang' || zakatType == 'money') {
            return PaymentType.uang;
          }
          if (zakatType == 'beras' || zakatType == 'rice') {
            return PaymentType.beras;
          }
          return null;
        }(),
        amountSo: () {
          final tx = json['transaction'] as Map<String, dynamic>?;
          final breakdown =
              tx?['payment_breakdown'] as List<dynamic>? ?? const [];
          for (final entry in breakdown) {
            final e = entry as Map<String, dynamic>;
            if (e['type'] == 'rice') {
              final q = e['quantity'];
              return (q as num?)?.toDouble() ?? 0.0;
            }
          }
          return (json['amount_so'] as num?)?.toDouble() ?? 0.0;
        }(),
        amountRp: () {
          final tx = json['transaction'] as Map<String, dynamic>?;
          final breakdown =
              tx?['payment_breakdown'] as List<dynamic>? ?? const [];
          for (final entry in breakdown) {
            final e = entry as Map<String, dynamic>;
            if (e['type'] == 'money') {
              final a = e['amount'];
              if (a is num) return a.toDouble();
              if (a is String) return double.tryParse(a) ?? 0.0;
              return 0.0;
            }
          }
          return (json['amount_rp'] as num?)?.toDouble() ?? 0.0;
        }(),
        numberOfPeople: json['jiwa_count'] as int? ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'member_id': memberId,
        'family_id': familyId,
        'year_id': yearId,
        'first_name': firstName,
        'last_name': lastName,
        'surname': surname,
        'sex': sex,
        'relationship': relationship,
        'is_head_of_family': isHeadOfFamily,
        'address': address,
        'phone': phone,
        'group_name': groupName,
        'afiliasi': afiliasi,
        'created_at': createdAt.toIso8601String(),
        'is_internal': isInternal,
        'is_paid': isPaid,
        'is_akad_done': isAkadDone,
        'amil_name': amilName,
        if (paymentType != null) 'zakat_type': paymentType!.name,
        'amount_so': amountSo,
        'amount_rp': amountRp,
        'jiwa_count': numberOfPeople,
      };
}

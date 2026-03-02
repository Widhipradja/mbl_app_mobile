/// Model matching the `/api/zakat-fitrah/years` response.
class ZakatYear {
  final String id;
  final int hijriYear;
  final String label;

  /// Rice equivalent rate in IDR per Sha' (1 Sha' ≈ 2.5 kg)
  final double riceRatePerSo;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ZakatYear({
    required this.id,
    required this.hijriYear,
    required this.label,
    required this.riceRatePerSo,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ZakatYear.fromJson(Map<String, dynamic> json) => ZakatYear(
        id: json['id'] as String? ?? '',
        hijriYear: json['hijri_year'] as int? ?? 0,
        label: json['label'] as String? ?? '',
        riceRatePerSo:
            double.tryParse(json['rice_rate_per_so']?.toString() ?? '0') ?? 0,
        isActive: json['is_active'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hijri_year': hijriYear,
        'label': label,
        'rice_rate_per_so': riceRatePerSo.toString(),
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  String toString() => label;
}

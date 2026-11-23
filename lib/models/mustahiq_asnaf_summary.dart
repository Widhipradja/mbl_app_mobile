class MustahiqAsnafSummary {
  const MustahiqAsnafSummary({
    required this.asnafType,
    required this.totalSouls,
    required this.count,
  });

  final String asnafType;
  final int totalSouls;
  final int count;

  factory MustahiqAsnafSummary.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return MustahiqAsnafSummary(
      asnafType: (json['asnaf_type'] as String? ?? '').trim(),
      totalSouls: toInt(json['total_souls']),
      count: toInt(json['count']),
    );
  }
}

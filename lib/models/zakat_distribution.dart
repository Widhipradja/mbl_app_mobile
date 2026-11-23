import 'zakat_year.dart';

/// Model matching the `GET /api/zakat-fitrah/distributions` response.
class ZakatDistribution {
  final String id;
  final String? yearId;
  final ZakatYear? zakatYear;
  final String? parentId;
  final String name;
  final double percentage;
  final String notes;
  final List<ZakatDistribution> children;

  const ZakatDistribution({
    required this.id,
    this.yearId,
    this.zakatYear,
    this.parentId,
    required this.name,
    required this.percentage,
    required this.notes,
    this.children = const [],
  });

  factory ZakatDistribution.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    final List<ZakatDistribution> childList = (rawChildren is List)
        ? rawChildren
            .whereType<Map<String, dynamic>>()
            .map(ZakatDistribution.fromJson)
            .toList()
        : const [];

    final rawYear = json['zakat_year'];
    final ZakatYear? year = (rawYear is Map<String, dynamic>)
        ? ZakatYear.fromJson(rawYear)
        : null;

    return ZakatDistribution(
      id: json['id']?.toString() ?? '',
      yearId: json['year_id']?.toString(),
      zakatYear: year,
      parentId: json['parent_id']?.toString(),
      name: json['name']?.toString() ?? '',
      percentage:
          double.tryParse(json['percentage']?.toString() ?? '0') ?? 0.0,
      notes: json['notes']?.toString() ?? '',
      children: childList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (yearId != null) 'year_id': yearId,
        if (parentId != null) 'parent_id': parentId,
        'name': name,
        'percentage': percentage,
        'notes': notes,
      };

  /// Returns a flat list of all descendants (including self).
  List<ZakatDistribution> flatten() {
    final result = <ZakatDistribution>[this];
    for (final child in children) {
      result.addAll(child.flatten());
    }
    return result;
  }
}

/// Master data for an external party (organisation / group), managed in
/// Config → Master Eksternal. Global, not per year.
///
/// Matches `/api/zakat-fitrah/externals`.
class ExternalMaster {
  final String id;
  final String name;
  final String notes;
  final bool isActive;

  const ExternalMaster({
    required this.id,
    required this.name,
    this.notes = '',
    this.isActive = true,
  });

  factory ExternalMaster.fromJson(Map<String, dynamic> json) => ExternalMaster(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );
}

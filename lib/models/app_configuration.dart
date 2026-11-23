class AppConfiguration {
  final String oid;
  final String module;
  final String code;

  /// Empty = applies to every year; otherwise only to that Zakat year.
  final String yearId;
  final String description;
  final String value;
  final String dataType;
  final bool isActive;

  const AppConfiguration({
    required this.oid,
    required this.module,
    required this.code,
    this.yearId = '',
    this.description = '',
    this.value = '',
    this.dataType = 'string',
    this.isActive = true,
  });

  factory AppConfiguration.fromJson(Map<String, dynamic> json) {
    return AppConfiguration(
      oid: json['oid'] as String? ?? json['id'] as String? ?? '',
      module: json['module'] as String? ?? 'general',
      code: json['code'] as String? ?? '',
      yearId: json['year_id']?.toString() ?? '',
      description: json['description'] as String? ?? '',
      value: json['value']?.toString() ?? '',
      dataType: json['data_type'] as String? ?? 'string',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'module': module,
        'code': code,
        if (yearId.isNotEmpty) 'year_id': yearId,
        'description': description,
        'value': value,
        'data_type': dataType,
        'is_active': isActive,
      };

  Map<String, dynamic> toUpdateJson() => {
        'module': module,
        'code': code,
        if (yearId.isNotEmpty) 'year_id': yearId,
        'description': description,
        'value': value,
        'data_type': dataType,
        'is_active': isActive,
      };

  bool get isGlobal => yearId.isEmpty;

  AppConfiguration copyWith({
    String? oid,
    String? module,
    String? code,
    String? yearId,
    String? description,
    String? value,
    String? dataType,
    bool? isActive,
  }) {
    return AppConfiguration(
      oid: oid ?? this.oid,
      module: module ?? this.module,
      code: code ?? this.code,
      yearId: yearId ?? this.yearId,
      description: description ?? this.description,
      value: value ?? this.value,
      dataType: dataType ?? this.dataType,
      isActive: isActive ?? this.isActive,
    );
  }
}

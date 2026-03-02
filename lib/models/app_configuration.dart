class AppConfiguration {
  final String oid;
  final String module;
  final String code;
  final String description;
  final String value;
  final String dataType;
  final bool isActive;

  const AppConfiguration({
    required this.oid,
    required this.module,
    required this.code,
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
      description: json['description'] as String? ?? '',
      value: json['value']?.toString() ?? '',
      dataType: json['data_type'] as String? ?? 'string',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'module': module,
        'code': code,
        'description': description,
        'value': value,
        'data_type': dataType,
        'is_active': isActive,
      };

  Map<String, dynamic> toUpdateJson() => {
        'module': module,
        'code': code,
        'description': description,
        'value': value,
        'data_type': dataType,
        'is_active': isActive,
      };

  AppConfiguration copyWith({
    String? oid,
    String? module,
    String? code,
    String? description,
    String? value,
    String? dataType,
    bool? isActive,
  }) {
    return AppConfiguration(
      oid: oid ?? this.oid,
      module: module ?? this.module,
      code: code ?? this.code,
      description: description ?? this.description,
      value: value ?? this.value,
      dataType: dataType ?? this.dataType,
      isActive: isActive ?? this.isActive,
    );
  }
}

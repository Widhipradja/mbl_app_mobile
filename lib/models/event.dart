class Event {
  final String? id;
  final String name;
  final DateTime dateTime;
  final String location;
  final String category;
  final String? remark;
  final String status;
  final DateTime? createdAt;

  Event({
    this.id,
    required this.name,
    required this.dateTime,
    this.location = '',
    this.category = 'UMUM',
    this.remark,
    this.status = 'Scheduled',
    this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    final dateString =
        json['date_time'] ?? json['event_date_time'] ?? json['event_date'];

    return Event(
      id: json['id']?.toString(),
      name: json['name'] ?? json['event_name'] ?? '',
      dateTime: (dateString != null && dateString.toString().isNotEmpty)
          ? DateTime.parse(dateString)
          : DateTime.now(),
      location: json['location'] ?? '',
      category: json['category'] ?? 'UMUM',
      remark: json['remark'],
      status: json['status'] ?? 'Scheduled',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'event_name': name,
      'event_date': dateTime.toIso8601String(),
      'location': location,
      'category': category,
      if (remark != null) 'remark': remark,
      'status': status,
    };
  }

  Event copyWith({
    String? id,
    String? name,
    DateTime? dateTime,
    String? location,
    String? category,
    String? remark,
    String? status,
    DateTime? createdAt,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      category: category ?? this.category,
      remark: remark ?? this.remark,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

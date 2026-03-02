import 'package:flutter/material.dart';

class Event {
  final String? id;
  final String name;
  final DateTime dateTime;
  final String location;
  final String category;
  final String? remark;
  final String status;
  final DateTime? createdAt;
  final String? groupName;
  final List<String>? ageGroups;
  final String? level;
  final TimeOfDay? timeFrom;
  final TimeOfDay? timeTo;

  Event({
    this.id,
    required this.name,
    required this.dateTime,
    this.location = '',
    this.category = 'UMUM',
    this.remark,
    this.status = 'Scheduled',
    this.createdAt,
    this.groupName,
    this.ageGroups,
    this.level,
    this.timeFrom,
    this.timeTo,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    final dateString =
        json['date_time'] ?? json['event_date_time'] ?? json['event_date'];

    TimeOfDay? parseTime(String? s) {
      if (s == null || s.isEmpty) return null;
      final parts = s.split(':');
      if (parts.length < 2) return null;
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

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
      groupName: json['group_name'],
      ageGroups: json['age_groups'] != null
          ? (json['age_groups'] is List
              ? List<String>.from(json['age_groups'] as List)
              : (json['age_groups'] as String)
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList())
          : null,
      level: json['level']?.toString(),
      timeFrom: parseTime(json['event_time_from']?.toString()),
      timeTo: parseTime(json['event_time_to']?.toString()),
    );
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'event_name': name,
      'event_date': dateTime.toIso8601String(),
      if (timeFrom != null) 'event_time_from': _fmt(timeFrom!),
      if (timeTo != null) 'event_time_to': _fmt(timeTo!),
      'location': location,
      'category': category,
      if (remark != null) 'remark': remark,
      'status': status,
      if (groupName != null) 'group_name': groupName,
      if (ageGroups != null && ageGroups!.isNotEmpty) 'age_groups': ageGroups,
      if (level != null && level!.isNotEmpty) 'level': level,
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
    String? groupName,
    List<String>? ageGroups,
    String? level,
    TimeOfDay? timeFrom,
    TimeOfDay? timeTo,
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
      groupName: groupName ?? this.groupName,
      ageGroups: ageGroups ?? this.ageGroups,
      level: level ?? this.level,
      timeFrom: timeFrom ?? this.timeFrom,
      timeTo: timeTo ?? this.timeTo,
    );
  }
}

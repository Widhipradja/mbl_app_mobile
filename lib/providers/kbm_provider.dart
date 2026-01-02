import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class KbmProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _kbmConfigs = [];
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> get kbmConfigs => List.unmodifiable(_kbmConfigs);

  /// Attempts to persist the KBM config to the backend as an Event.
  /// Returns true if the operation succeeded and the local list was updated.
  Future<bool> addKbmConfig(Map<String, dynamic> config) async {
    try {
      // Map KBM payload to event payload expected by the API
      final Map<String, dynamic> eventPayload = {
        'event_name':
            '${config['className'] ?? ''} - ${config['subject'] ?? ''}',
        'event_date':
            _combineDateAndTime(
              config['date'],
              config['startTime'],
            )?.toIso8601String() ??
            config['date'],
        'location': config['location'] ?? '',
        'category': config['subject'] ?? 'KBM',
        if ((config['notes'] ?? '').toString().isNotEmpty)
          'remark': config['notes'],
      };

      final response = await _apiService.createEvent(eventPayload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // If API returns created resource, merge ID and timestamps if available
        final returned = response.data is Map
            ? Map<String, dynamic>.from(response.data)
            : {};
        final stored = Map<String, dynamic>.from(config);
        if (returned['id'] != null) stored['id'] = returned['id'].toString();
        _kbmConfigs.add(stored);
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error persisting KBM config: $e');
      return false;
    }
  }

  void clearAll() {
    _kbmConfigs.clear();
    notifyListeners();
  }

  DateTime? _combineDateAndTime(dynamic dateValue, dynamic timeValue) {
    try {
      if (dateValue == null) return null;
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return null;
      }

      if (timeValue == null) return date;

      // timeValue expected as HH:mm or TimeOfDay formatted string
      final parts = timeValue.toString().split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        return DateTime(date.year, date.month, date.day, hour, minute);
      }

      return date;
    } catch (_) {
      return null;
    }
  }
}

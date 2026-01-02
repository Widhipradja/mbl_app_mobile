import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/api_service.dart';

class EventProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setEvents(List<Event> events) {
    _events = events;
    notifyListeners();
  }

  Future<void> fetchLatestEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getLatestEvents();
      debugPrint('Fetched latest events: ${response.data}');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : (response.data['events'] ?? []);
        _events = data.map((json) => Event.fromJson(json)).toList();
        _error = null;
      } else {
        _error = 'Failed to load events';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createEvent(Event event) async {
    try {
      final response = await _apiService.createEvent(event.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchLatestEvents(); // Refresh the list
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error creating event: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEvent(String id, Event event) async {
    try {
      final response = await _apiService.updateEvent(id, event.toJson());
      if (response.statusCode == 200) {
        await fetchLatestEvents(); // Refresh the list
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating event: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEvent(String id) async {
    try {
      final response = await _apiService.deleteEvent(id);
      if (response.statusCode == 200) {
        _events.removeWhere((event) => event.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting event: $e');
      notifyListeners();
      return false;
    }
  }
}

import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  final ApiService _apiService;

  AuthProvider({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  // Initialize user from storage
  Future<void> init() async {
    _user = StorageService.getUser();
    notifyListeners();
  }

  // Login
  Future<bool> login(String userId, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.login(userId, password);
      
      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['token'];
        final userData = data['user'];

        // Save token and user
        await StorageService.saveToken(token);
        _user = User.fromJson(userData);
        await StorageService.saveUser(_user!);

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = 'Login failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Logout
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      debugPrint('Logout API error: $e');
    } finally {
      await StorageService.clearAll();
      _user = null;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
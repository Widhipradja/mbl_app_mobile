import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../utils/jwt_decoder.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  final ApiService _apiService;

  AuthProvider({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  // Initialize user from storage
  Future<void> init() async {
    _user = StorageService.getUser();

    // Check if token is expired
    final token = StorageService.getToken();
    if (token != null && JwtDecoder.isExpired(token)) {
      // Token expired, clear storage and logout
      await StorageService.clearAll();
      _user = null;
      print('🔴 Token expired, user logged out');
    }

    notifyListeners();
  }

  // Check if current token is valid
  bool isTokenValid() {
    final token = StorageService.getToken();
    if (token == null) return false;
    return !JwtDecoder.isExpired(token);
  }

  // Login
  Future<bool> login(String userId, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.login(userId, password);
      // show response
      // print('Login response: ${response.statusCode} - ${response.data}');
      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['token'];

        // Check if token is valid
        if (token == null || token.toString().isEmpty) {
          _error = 'Your user ID or password is incorrect. Please try again.';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // Save token
        await StorageService.saveToken(token);

        // Decode JWT and extract user data
        final userData = JwtDecoder.getUserDataFromToken(token);
        print('🔵 USER DATA FROM JWT: $userData');

        if (userData == null) {
          _error = 'Invalid authentication token. Please try again.';
          await StorageService.clearAll();
          _isLoading = false;
          notifyListeners();
          return false;
        }

        _user = User.fromJson(userData);
        await StorageService.saveUser(_user!);

        // Save tenant ID from JWT
        if (userData['tenant_id'] != null) {
          await StorageService.saveTenantId(userData['tenant_id']);
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Handle non-200 status codes
        _error = 'Invalid credentials. Please check your user ID and password.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors
      print('🔴 DIO ERROR: ${e.type} - ${e.response?.statusCode}');
      print('🔴 ERROR MESSAGE: ${e.message}');
      print('🔴 RESPONSE DATA: ${e.response?.data}');

      if (e.response?.statusCode == 401) {
        _error = 'Invalid user ID or password.';
      } else if (e.response?.statusCode == 403) {
        _error = 'Access denied. Please contact your administrator.';
      } else if (e.response?.statusCode == 404) {
        _error = 'Login service not found.';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _error = 'Connection timeout. Please check your internet connection.';
      } else if (e.type == DioExceptionType.connectionError) {
        _error = 'Network error. Please check your internet connection.';
      } else if (e.response?.data != null) {
        // Check for both 'error' and 'message' fields from gin.H
        _error =
            e.response?.data['error'] ??
            e.response?.data['message'] ??
            'Login failed. Please try again.';
      } else {
        _error = 'Login failed. Please try again.';
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      // Handle other errors
      print('🔴 GENERAL ERROR: $e');
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
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

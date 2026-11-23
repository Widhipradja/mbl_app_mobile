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
      debugPrint('🔴 Token expired, user logged out');
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
      // debugPrint('Login response: ${response.statusCode} - ${response.data}');
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

        // Create user data from response (priority) or decode from JWT
        Map<String, dynamic> userData;

        if (data['email'] != null && data['name'] != null) {
          // Use data directly from login response
          // Convert roles array if it's a list of strings
          List<Map<String, dynamic>>? rolesData;
          if (data['roles'] != null && data['roles'] is List) {
            final rolesList = data['roles'] as List;
            if (rolesList.isNotEmpty && rolesList.first is String) {
              // Convert string array to Role objects
              rolesData = rolesList
                  .map(
                    (roleName) => {
                      'user_id': data['user_id'] ?? data['email'],
                      'role_id': '',
                      'role_name': roleName.toString(),
                    },
                  )
                  .toList();
            } else if (rolesList.isNotEmpty && rolesList.first is Map) {
              // Already in correct format
              rolesData = List<Map<String, dynamic>>.from(rolesList);
            }
          }

          userData = {
            'id': data['user_id'] ?? data['email'],
            'name': data['name'],
            'email': data['email'],
            'user_id': data['user_id'],
            'tenant_id': data['tenant_id'],
            'roles': rolesData,
            'group_name': data['group_name'],
          };
        } else {
          // Fallback: Decode JWT and extract user data
          final decodedData = JwtDecoder.getUserDataFromToken(token);
          if (decodedData == null) {
            _error = 'Invalid authentication token. Please try again.';
            await StorageService.clearAll();
            _isLoading = false;
            notifyListeners();
            return false;
          }

          // Convert roles array if needed
          List<Map<String, dynamic>>? rolesData;
          if (decodedData['roles'] != null && decodedData['roles'] is List) {
            final rolesList = decodedData['roles'] as List;
            if (rolesList.isNotEmpty && rolesList.first is String) {
              rolesData = rolesList
                  .map(
                    (roleName) => {
                      'user_id': decodedData['user_id'] ?? decodedData['email'],
                      'role_id': '',
                      'role_name': roleName.toString(),
                    },
                  )
                  .toList();
            } else if (rolesList.isNotEmpty && rolesList.first is Map) {
              rolesData = List<Map<String, dynamic>>.from(rolesList);
            }
          }

          userData = {
            'id': decodedData['user_id'] ?? decodedData['email'],
            'name': decodedData['name'],
            'email': decodedData['email'],
            'user_id': decodedData['user_id'],
            'tenant_id': decodedData['tenant_id'],
            'roles': rolesData,
            'group_name': decodedData['group_name'],
          };
        }

        _user = User.fromJson(userData);
        await StorageService.saveUser(_user!);

        // Save tenant ID
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
      debugPrint('🔴 DIO ERROR: ${e.type} - ${e.response?.statusCode}');
      debugPrint('🔴 ERROR MESSAGE: ${e.message}');
      debugPrint('🔴 RESPONSE DATA: ${e.response?.data}');

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
        _error = e.response?.data['error'] ??
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
      debugPrint('🔴 GENERAL ERROR: $e');
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

  /// Saves own profile edits: [changes] holds only the fields that changed
  /// (never the `user_id`). The answer is flat and has no roles, tenant or
  /// group, so those stay as they are. Throws on failure so the form can show
  /// the reason.
  Future<void> updateProfile(Map<String, dynamic> changes) async {
    final resp = await _apiService.updateProfile(changes);
    final body = resp.data;
    final current = _user?.toJson() ?? <String, dynamic>{};
    final sent = {...changes}..remove('current_password');
    final merged = {
      ...current,
      ...sent,
      if (body is Map<String, dynamic>)
        for (final e in body.entries)
          // address always comes back empty: keep ours.
          if (e.key != 'address') e.key: e.value,
    };
    for (final k in ['user_id', 'tenant_id', 'id']) {
      merged[k] = current[k];
    }
    _user = User.fromJson(merged);
    await StorageService.saveUser(_user!);
    notifyListeners();
  }

  Future<void> _storeAvatar(String path) async {
    final current = _user?.toJson() ?? <String, dynamic>{};
    if ((current['avatar'] ?? '') == path) return;
    current['avatar'] = path.isEmpty ? null : path;
    _user = User.fromJson(current);
    await StorageService.saveUser(_user!);
    notifyListeners();
  }

  /// `avatar` of a profile answer: `""` for no photo, else a path on the API
  /// host whose `?v=` changes with every new photo (so image caches renew).
  static String _avatarOf(dynamic body) =>
      body is Map ? (body['avatar']?.toString().trim() ?? '') : '';

  /// Uploads a new photo (already shrunk) and keeps the address the server
  /// answers. Throws on failure so the screen can show the reason.
  Future<void> setAvatar(List<int> bytes, String name) async {
    final resp = await _apiService.uploadAvatar(bytes, name);
    final path = _avatarOf(resp.data);
    if (path.isEmpty) throw const FormatException('avatar path missing');
    await _storeAvatar(path);
  }

  Future<void> removeAvatar() async {
    final resp = await _apiService.deleteAvatar();
    await _storeAvatar(_avatarOf(resp.data));
  }

  /// Picks up what login does not give, or what changed on another device
  /// (or the web), from `GET /profile`: the photo and the date of birth.
  /// Quiet: a failure leaves what is shown.
  Future<void> refreshProfile() async {
    if (_user == null) return;
    try {
      final body = (await _apiService.getProfile()).data;
      if (body is! Map) return;
      final current = _user!.toJson();
      final avatar = _avatarOf(body);
      final birth = body['birth_date']?.toString().trim() ?? '';
      if ((current['avatar'] ?? '') == avatar &&
          (current['birth_date'] ?? '') == birth) {
        return;
      }
      current['avatar'] = avatar.isEmpty ? null : avatar;
      current['birth_date'] = birth;
      _user = User.fromJson(current);
      await StorageService.saveUser(_user!);
      notifyListeners();
    } catch (e) {
      debugPrint('refreshProfile error: $e');
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

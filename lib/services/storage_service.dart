import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../utils/constants.dart';

class StorageService {
  static late SharedPreferences _prefs;
  
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _tenantIdKey = 'tenant_id';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token management
  static Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  static String? getToken() {
    return _prefs.getString(_tokenKey);
  }

  static Future<void> removeToken() async {
    await _prefs.remove(_tokenKey);
  }

  static Future<bool> isAuthenticated() async {
    return getToken() != null;
  }

  // Tenant ID management
  static Future<void> saveTenantId(String tenantId) async {
    await _prefs.setString(_tenantIdKey, tenantId);
  }

  static String? getTenantId() {
    return _prefs.getString(_tenantIdKey);
  }

  static Future<void> removeTenantId() async {
    await _prefs.remove(_tenantIdKey);
  }

  // User data management
  static Future<void> saveUser(User user) async {
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static User? getUser() {
    final String? userJson = _prefs.getString(_userKey);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  static Future<void> removeUser() async {
    await _prefs.remove(_userKey);
  }

  // Clear all data
  static Future<void> clearAll() async {
    await removeToken();
    await removeUser();
    await removeTenantId();
  }
}
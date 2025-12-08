import 'package:dio/dio.dart';
import 'storage_service.dart';
import '../utils/constants.dart';
import '../utils/jwt_decoder.dart';
import 'package:flutter/material.dart';

class ApiService {
  // static const String baseUrl = 'https://8ff4edc65c2d.ngrok-free.app/mblapi';
  // static const String baseUrl = 'https://59141266354a.ngrok-free.app/mblapi';
  // static const String mblAPIUrl = 'https://59141266354a.ngrok-free.app/mblapi';
  // For local testing: 'http://10.0.2.2:3000/api' (Android emulator)
  // For local testing: 'http://localhost:3000/api' (iOS simulator)

  late Dio _dio;
  static final ValueNotifier<bool> tokenExpiredNotifier = ValueNotifier(false);

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Add interceptor for auth token and tenant ID
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🔵 REQUEST: ${options.method} ${options.path}');
          print('📤 DATA: ${options.data}');
          print('🔵 LOGIN URL: ${AppConstants.apiBaseUrl}${options.path}');

          // Add auth token
          final token = StorageService.getToken();
          if (token != null) {
            // Check if token is expired before making request
            if (JwtDecoder.isExpired(token)) {
              print('🔴 Token expired, clearing storage');
              StorageService.clearAll();
              tokenExpiredNotifier.value = true;
              return handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'Token expired',
                  type: DioExceptionType.cancel,
                ),
              );
            }
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Add tenant ID header
          final tenantId =
              StorageService.getTenantId() ?? AppConstants.tenantId;
          options.headers['X-Tenant-ID'] = tenantId;

          return handler.next(options);
        },
        onError: (error, handler) {
          print('🔴 ERROR: ${error.response?.statusCode} - ${error.message}');
          print('🔴 FULL ERROR: $error');
          if (error.response?.statusCode == 401) {
            // Token expired, logout user
            StorageService.clearAll();
            tokenExpiredNotifier.value = true;
          }
          return handler.next(error);
        },
        onResponse: (response, handler) {
          print('🟢 RESPONSE: ${response.statusCode}');
          print('🟢 DATA: ${response.data}');
          return handler.next(response);
        },
      ),
    );
  }

  // Auth endpoints
  Future<Response> login(String userId, String password) async {
    return await _dio.post(
      '/login',
      data: {"user_id": userId, "password": password},
    );
  }

  Future<Response> logout() async {
    return await _dio.post('/logout');
  }

  // Transaction endpoints
  Future<Response> getTransactions() async {
    return await _dio.get('/api/transactions');
  }

  Future<Response> getRecentTransactions(int limit) async {
    return await _dio.get('/api/transaction/recent/$limit');
  }

  Future<Response> getMonthlyTransactions(int month, int year) async {
    return await _dio.get('/api/transaction/monthlysummary/$month/$year');
  }

  Future<Response> createTransaction(Map<String, dynamic> data) async {
    return await _dio.post('/api/transaction/addtrx', data: data);
  }

  Future<Response> getLookups(String type) async {
    return await _dio.get('/api/lookups/type/$type');
  }

  Future<Response> getTransactionSummary() async {
    return await _dio.get('/api/transaction/summary/categories');
  }

  Future<Response> updateTransaction(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await _dio.put('/transactions/$id', data: data);
  }

  Future<Response> deleteTransaction(String id) async {
    return await _dio.delete('/transactions/$id');
  }

  // User endpoints
  Future<Response> getProfile() async {
    return await _dio.get('/user/profile');
  }
}

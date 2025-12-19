// ...existing imports...
import 'package:dio/dio.dart';
import 'storage_service.dart';
import 'config_service.dart';
import '../utils/constants.dart';
import '../utils/jwt_decoder.dart';
import 'package:flutter/material.dart';

class ApiService {
  Future<Response> getMemberStatisticsByCategory({
    required String category,
    required int year,
    int? month,
    required String sex,
    required String familyId,
  }) async {
    final payload = {
      'category': category,
      'year': year,
      if (month != null) 'month': month,
      'sex': sex,
      'family_id': familyId,
    };
    return await _dio.post('/api/members/event/statistics', data: payload);
  }
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
        baseUrl: ConfigService.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Add interceptor for auth token and tenant ID
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // debugPrint('🔵 REQUEST: ${options.method} ${options.path}');
          // debugPrint('📤 DATA: ${options.data}');
          // debugPrint('🔵 LOGIN URL: ${AppConstants.apiBaseUrl}${options.path}');

          // Add auth token
          final token = StorageService.getToken();
          if (token != null) {
            // Check if token is expired before making request
            if (JwtDecoder.isExpired(token)) {
              debugPrint('🔴 Token expired, clearing storage');
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
          debugPrint(
            '🔴 ERROR: ${error.response?.statusCode} - ${error.message}',
          );
          debugPrint('🔴 FULL ERROR: $error');
          debugPrint('🔴 ERROR URL: ${error.requestOptions.uri}');
          debugPrint('🔴 ERROR PAYLOAD: ${error.requestOptions.data}');
          if (error.response?.statusCode == 401) {
            // Token expired, logout user
            StorageService.clearAll();
            tokenExpiredNotifier.value = true;
          }
          return handler.next(error);
        },
        onResponse: (response, handler) {
          // debugPrint('🟢 RESPONSE: ${response.statusCode}');
          // debugPrint('🟢 DATA: ${response.data}');
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

  Future<Response> inquiryTransactions({
    String? category,
    String? pic,
    String? trxType,
    String? description,
    String? startDate,
    String? endDate,
  }) async {
    final Map<String, dynamic> payload = {};
    if (category != null) payload['category'] = category;
    if (pic != null) payload['pic'] = pic;
    if (trxType != null) payload['trx_type'] = trxType;
    if (description != null) payload['description'] = description;
    if (startDate != null) payload['start_date'] = startDate;
    if (endDate != null) payload['end_date'] = endDate;

    return await _dio.post('/api/transaction/inquiry', data: payload);
  }

  Future<Response> updateTransaction(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await _dio.put('/api/transaction/$id', data: data);
  }

  Future<Response> deleteTransaction(String id) async {
    return await _dio.delete('/api/transaction/$id');
  }

  // Event endpoints
  Future<Response> createEvent(Map<String, dynamic> data) async {
    return await _dio.post('/api/events', data: data);
  }

  Future<Response> getEventsByYear(int year) async {
    return await _dio.get('/api/events/year/$year');
  }

  Future<Response> getEventsByYearMonth({int? year, int? month}) async {
    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;
    return await _dio.get('/api/events/year/$targetYear/month/$targetMonth');
  }

  Future<Response> getLatestEvents({int? year, int? month}) async {
    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;
    return await _dio.get(
      '/api/events/ongoing/year/$targetYear/month/$targetMonth',
    );
  }

  Future<Response> getCompletedEvents({int? year, int? month}) async {
    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;
    return await _dio.get(
      '/api/events/completed/year/$targetYear/month/$targetMonth',
    );
  }

  Future<Response> updateEvent(String id, Map<String, dynamic> data) async {
    return await _dio.put('/api/events/$id', data: data);
  }

  Future<Response> updateEventStatus(String id, String status) async {
    return await _dio.put('/api/events/$id/status', data: {'status': status});
  }

  Future<Response> deleteEvent(String id) async {
    return await _dio.delete('/api/events/$id');
  }

  // User endpoints
  Future<Response> getProfile() async {
    return await _dio.get('/user/profile');
  }

  // Attendance endpoints
  Future<Response> markAttendance(
    String eventId,
    String userId,
    bool isAttending,
  ) async {
    return await _dio.put(
      '/api/events/$eventId/attendance/user/$userId',
      data: {'is_attending': isAttending},
    );
  }

  Future<Response> updateAttendanceRemark(
    String eventId,
    String userId,
    String remark,
  ) async {
    return await _dio.put(
      '/api/events/$eventId/attendance/user/$userId/remark',
      data: {'remark': remark},
    );
  }

  Future<Response> getEventAttendance(String eventId) async {
    return await _dio.get('/api/events/$eventId/attendance');
  }

  Future<Response> syncEventAttendees(String eventId) async {
    return await _dio.post('/api/events/$eventId/syncattendees');
  }

  // Member endpoints
  Future<Response> getMembers() async {
    return await _dio.get('/api/members');
  }

  Future<Response> getMemberById(String id) async {
    return await _dio.get('/api/members/$id');
  }

  Future<Response> createMember(Map<String, dynamic> data) async {
    return await _dio.post('/api/members', data: data);
  }

  Future<Response> updateMember(String id, Map<String, dynamic> data) async {
    return await _dio.put('/api/members/$id', data: data);
  }

  Future<Response> deleteMember(String id) async {
    return await _dio.delete('/api/members/$id');
  }
}

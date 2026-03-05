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
    return await _dio.get('/api/ku/transactions');
  }

  Future<Response> getRecentTransactions(int limit) async {
    return await _dio.get('/api/ku/transaction/recent/$limit');
  }

  Future<Response> getMonthlyTransactions(int month, int year) async {
    return await _dio.get('/api/ku/transaction/monthlysummary/$month/$year');
  }

  Future<Response> createTransaction(Map<String, dynamic> data) async {
    return await _dio.post('/api/ku/transaction/addtrx', data: data);
  }

  Future<Response> getLookups(String type) async {
    return await _dio.get('/api/lookups/type/$type');
  }

  Future<Response> getTransactionSummary() async {
    return await _dio.get('/api/ku/transaction/summary/categories');
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

    return await _dio.post('/api/ku/transaction/inquiry', data: payload);
  }

  Future<Response> updateTransaction(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await _dio.put('/api/ku/transaction/$id', data: data);
  }

  Future<Response> deleteTransaction(String id) async {
    return await _dio.delete('/api/ku/transaction/$id');
  }

  // Event endpoints
  Future<Response> createEvent(Map<String, dynamic> data) async {
    debugPrint('API createEvent payload: $data');
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

  Future<Response> getAttendanceTrend() async {
    return await _dio.get('/api/events/attendance/trend/last2months');
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

  // ── Zakat Fitrah endpoints ──────────────────────────────────────────────────

  /// Fetch available Zakat Fitrah years.
  Future<Response> getZakatYears() async {
    return await _dio.get('/api/zakat-fitrah/years');
  }

  /// Create a new Zakat Fitrah year.
  ///
  /// Endpoint: `POST /api/zakat-fitrah/years`
  Future<Response> createZakatYear(Map<String, dynamic> data) async {
    return await _dio.post('/api/zakat-fitrah/years', data: data);
  }

  /// Update an existing Zakat Fitrah year.
  ///
  /// Endpoint: `PUT /api/zakat-fitrah/years/{id}`
  Future<Response> updateZakatYear(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await _dio.put('/api/zakat-fitrah/years/$id', data: data);
  }

  /// Fetch muzakki with payment status for a specific Zakat year.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/years/{yearId}/muzakki/status`
  /// The response is paginated: `{ data: [...], limit, offset, total }`.
  Future<Response> getZakatMuzakkiStatus(String yearId,
      {int limit = 400}) async {
    return await _dio.get(
      '/api/zakat-fitrah/years/$yearId/muzakki/status',
      queryParameters: {'limit': limit},
    );
  }

  /// Create a new muzakki entry.
  ///
  /// Endpoint: `POST /api/zakat-fitrah/muzakki`
  ///
  /// [familyId] empty → server creates a new family; provided → joins existing.
  Future<Response> createMuzakki({
    required String firstName,
    required String yearId,
    String lastName = '',
    String surname = '',
    String sex = 'M',
    String relationship = '',
    bool isHeadOfFamily = false,
    bool isInternal = true,
    String familyId = '',
    String address = '',
    String phone = '',
    String groupName = '',
  }) async {
    return await _dio.post(
      '/api/zakat-fitrah/muzakki',
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'surname': surname,
        'sex': sex,
        'relationship': relationship,
        'is_head_of_family': isHeadOfFamily,
        'is_internal': isInternal,
        'family_id': familyId,
        'address': address,
        'phone': phone,
        'group_name': groupName,
        'year_id': yearId,
      },
    );
  }

  /// Create muzakki in bulk.
  ///
  /// Endpoint: `POST /api/zakat-fitrah/muzakki/bulk`
  /// Payload: `{ year_id?: string, muzakkis: MuzakkiRequest[] }`
  Future<Response> createMuzakkiBulk({
    String? yearId,
    required List<Map<String, dynamic>> muzakkis,
  }) async {
    return await _dio.post(
      '/api/zakat-fitrah/muzakki/bulk',
      data: {
        if (yearId != null && yearId.isNotEmpty) 'year_id': yearId,
        'muzakkis': muzakkis,
      },
    );
  }

  /// Delete a muzakki record.
  ///
  /// Endpoint: `DELETE /api/zakat-fitrah/muzakki/{id}`
  Future<Response> deleteMuzakki(String id) async {
    return await _dio.delete('/api/zakat-fitrah/muzakki/$id');
  }

  /// Update a muzakki record.
  ///
  /// Endpoint: `PUT /api/zakat-fitrah/muzakki/{id}`
  Future<Response> updateZakatMuzakki(
      String id, Map<String, dynamic> data) async {
    return await _dio.put('/api/zakat-fitrah/muzakki/$id', data: data);
  }

  /// Set a muzakki as the new family head.
  ///
  /// Endpoint: `PATCH /api/zakat-fitrah/muzakki/{id}/family-head`
  Future<Response> setFamilyHead(String id) async {
    return await _dio.patch('/api/zakat-fitrah/muzakki/$id/family-head');
  }

  /// Fetch recent zakat payment transactions.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/transaction/recent?limit={limit}`
  Future<Response> getZakatRecentTransactions({int limit = 10}) async {
    return await _dio.get(
      '/api/zakat-fitrah/transactions/recent',
      queryParameters: {'limit': limit},
    );
  }

  /// Fetch Ramadhan recap report summary for selected year.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/years/report-summary/{yearId}`
  Future<Response> getZakatReportSummary(String yearId) async {
    return await _dio.get('/api/zakat-fitrah/years/report-summary/$yearId');
  }

  /// Fetch list of Amil names from the lookup table.
  ///
  /// Endpoint: `GET /api/lookups/type/AMIL`
  Future<Response> getZakatAmil() async {
    return await _dio.get('/api/lookups/type/AMIL');
  }

  /// Fetch zakat configuration by module and code.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/configuration/module/{module}/code/{code}`
  Future<Response> getZakatConfigurationByModuleAndCode(
    String module,
    String code,
  ) async {
    return await _dio
        .get('/api/zakat-fitrah/configuration/module/$module/code/$code');
  }

  /// Create a new zakat payment transaction.
  ///
  /// Endpoint: `POST /api/zakat-fitrah/transactions`
  Future<Response> createZakatTransaction({
    required String muzakkiId,
    required String yearId,
    required String paymentType, // 'rice' | 'money'
    int quantity = 0,
    String amount = '0',
    required int totalSouls,
    String notes = '',
    String amilName = '',
  }) async {
    return await _dio.post(
      '/api/zakat-fitrah/transactions',
      data: {
        'muzakki_id': muzakkiId,
        'year_id': yearId,
        'payment_type': paymentType,
        'quantity': quantity,
        'amount': amount,
        'total_souls': totalSouls,
        'notes': notes,
        'amil_name': amilName,
      },
    );
  }

  /// Create bulk zakat transactions for multiple muzakki (family).
  ///
  /// Endpoint: `POST /api/zakat-fitrah/transactions/bulk`
  Future<Response> createZakatTransactionBulk({
    required String yearId,
    required int year,
    required String amilName,
    required String notes,
    required List<Map<String, String>> registeredAllocations,
    required Map<String, dynamic> externalBreakdown,
    required List<Map<String, dynamic>> paymentBreakdown,
    required int totalSouls,
  }) async {
    return await _dio.post(
      '/api/zakat-fitrah/transactions/bulk',
      data: {
        'year_id': yearId,
        'year': year,
        'amil_name': amilName,
        'notes': notes,
        'registered_allocations': registeredAllocations,
        'external_breakdown': externalBreakdown,
        'payment_breakdown': paymentBreakdown,
        'total_souls': totalSouls,
      },
    );
  }

  /// Fetch mustahiq list.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/mustahiq`
  Future<Response> getZakatMustahiq({String? yearId}) async {
    return await _dio.get(
      '/api/zakat-fitrah/mustahiq',
      queryParameters: {
        if (yearId != null && yearId.isNotEmpty) 'year_id': yearId,
      },
    );
  }

  /// Create a mustahiq record.
  ///
  /// Endpoint: `POST /api/zakat-fitrah/mustahiq`
  Future<Response> createZakatMustahiq({
    required String yearId,
    required String name,
    required String asnafType,
    required int souls,
  }) async {
    return await _dio.post(
      '/api/zakat-fitrah/mustahiq',
      data: {
        'year_id': yearId,
        'name': name,
        'asnaf_type': asnafType,
        'souls': souls,
      },
    );
  }

  /// Get mustahiq by id.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/mustahiq/{id}`
  Future<Response> getZakatMustahiqById(String id) async {
    return await _dio.get('/api/zakat-fitrah/mustahiq/$id');
  }

  /// Update mustahiq by id.
  ///
  /// Endpoint: `PUT /api/zakat-fitrah/mustahiq/{id}`
  Future<Response> updateZakatMustahiq(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await _dio.put('/api/zakat-fitrah/mustahiq/$id', data: data);
  }

  /// Delete mustahiq by id.
  ///
  /// Endpoint: `DELETE /api/zakat-fitrah/mustahiq/{id}`
  Future<Response> deleteZakatMustahiq(String id) async {
    return await _dio.delete('/api/zakat-fitrah/mustahiq/$id');
  }

  /// Fetch mustahiq summary grouped by asnaf.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/mustahiq/summary/asnaf`
  Future<Response> getZakatMustahiqSummaryAsnaf({String? yearId}) async {
    return await _dio.get(
      '/api/zakat-fitrah/mustahiq/summary/asnaf',
      queryParameters: {
        if (yearId != null && yearId.isNotEmpty) 'year_id': yearId,
      },
    );
  }

  /// Fetch asnaf bobot list.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/asnaf-bobot`
  Future<Response> getZakatAsnafBobot({String? yearId}) async {
    return await _dio.get(
      '/api/zakat-fitrah/asnaf-bobot',
      queryParameters: {
        if (yearId != null && yearId.isNotEmpty) 'year_id': yearId,
      },
    );
  }

  /// Fetch asnaf bobot lookup.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/asnaf-bobot/lookup`
  Future<Response> getZakatAsnafBobotLookup({
    required String yearId,
    required String asnafType,
  }) async {
    return await _dio.get(
      '/api/zakat-fitrah/asnaf-bobot/lookup',
      queryParameters: {
        'year_id': yearId,
        'asnaf_type': asnafType,
      },
    );
  }

  /// Create asnaf bobot.
  ///
  /// Endpoint: `POST /api/zakat-fitrah/asnaf-bobot`
  Future<Response> createZakatAsnafBobot(Map<String, dynamic> data) async {
    return await _dio.post('/api/zakat-fitrah/asnaf-bobot', data: data);
  }

  /// Get asnaf bobot by id.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/asnaf-bobot/{id}`
  Future<Response> getZakatAsnafBobotById(String id) async {
    return await _dio.get('/api/zakat-fitrah/asnaf-bobot/$id');
  }

  /// Update asnaf bobot by id.
  ///
  /// Endpoint: `PUT /api/zakat-fitrah/asnaf-bobot/{id}`
  Future<Response> updateZakatAsnafBobot(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await _dio.put('/api/zakat-fitrah/asnaf-bobot/$id', data: data);
  }

  /// Delete asnaf bobot by id.
  ///
  /// Endpoint: `DELETE /api/zakat-fitrah/asnaf-bobot/{id}`
  Future<Response> deleteZakatAsnafBobot(String id) async {
    return await _dio.delete('/api/zakat-fitrah/asnaf-bobot/$id');
  }

  // ── Distribution endpoints ───────────────────────────────────────────────

  /// Fetch list of zakat fitrah distributions (tree structure).
  ///
  /// Endpoint: `GET /api/zakat-fitrah/distributions`
  Future<Response> getZakatDistributions({String? yearId}) async {
    return await _dio.get(
      '/api/zakat-fitrah/distributions',
      queryParameters: {
        if (yearId != null && yearId.isNotEmpty) 'year_id': yearId,
      },
    );
  }

  /// Create a new zakat fitrah distribution node.
  ///
  /// Endpoint: `POST /api/zakat-fitrah/distributions`
  Future<Response> createZakatDistribution(Map<String, dynamic> data) async {
    return await _dio.post('/api/zakat-fitrah/distributions', data: data);
  }

  /// Update a zakat fitrah distribution node.
  ///
  /// Endpoint: `PUT /api/zakat-fitrah/distributions/{id}`
  Future<Response> updateZakatDistribution(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await _dio.put('/api/zakat-fitrah/distributions/$id', data: data);
  }

  /// Delete a zakat fitrah distribution node.
  ///
  /// Endpoint: `DELETE /api/zakat-fitrah/distributions/{id}`
  Future<Response> deleteZakatDistribution(String id) async {
    return await _dio.delete('/api/zakat-fitrah/distributions/$id');
  }

  // ── Adjustment endpoints ─────────────────────────────────────────────────

  /// Fetch list of zakat fitrah distribution adjustments.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/adjustments`
  Future<Response> getZakatAdjustments({String? yearId}) async {
    return await _dio.get(
      '/api/zakat-fitrah/adjustments',
      queryParameters: {
        if (yearId != null && yearId.isNotEmpty) 'year_id': yearId,
      },
    );
  }

  /// Create a zakat fitrah distribution adjustment (upsert by distribution).
  ///
  /// Endpoint: `POST /api/zakat-fitrah/adjustments`
  Future<Response> createZakatAdjustment(Map<String, dynamic> data) async {
    return await _dio.post('/api/zakat-fitrah/adjustments', data: data);
  }

  // ── Configuration endpoints ──────────────────────────────────────────────

  Future<Response> getConfigurations() async {
    return await _dio.get('/api/admin/configurations');
  }

  Future<Response> getConfigurationsByModule(String module) async {
    return await _dio.get('/api/admin/configurations/module/$module');
  }

  Future<Response> getConfigurationByModuleAndCode(
    String module,
    String code,
  ) async {
    return await _dio
        .get('/api/admin/configurations/module/$module/code/$code');
  }

  Future<Response> getConfigurationByOid(String oid) async {
    return await _dio.get('/api/admin/configurations/$oid');
  }

  Future<Response> getConfigurationValueByCode(String code) async {
    return await _dio.get('/api/admin/configurations/code/$code/value');
  }

  Future<Response> createConfiguration(Map<String, dynamic> data) async {
    return await _dio.post('/api/admin/configurations', data: data);
  }

  Future<Response> updateConfiguration(
    String oid,
    Map<String, dynamic> data,
  ) async {
    return await _dio.put('/api/admin/configurations/$oid', data: data);
  }

  Future<Response> deleteConfiguration(String oid) async {
    return await _dio.delete('/api/admin/configurations/$oid');
  }
}

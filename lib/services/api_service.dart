import 'dart:convert';

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
          debugPrint('🔵 REQUEST: ${options.method} ${options.uri}');
          debugPrint('📤 DATA: ${options.data}');
          debugPrint('📋 HEADERS: ${options.headers}');

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
          // Never print what carries a password.
          final path = error.requestOptions.path;
          final secret = path.contains('/password') ||
              path.contains('/profile') ||
              path.contains('login');
          debugPrint(
              '🔴 ERROR PAYLOAD: ${secret ? '<hidden>' : error.requestOptions.data}');
          if (error.response?.statusCode == 401) {
            // Token expired, logout user
            StorageService.clearAll();
            tokenExpiredNotifier.value = true;
          }
          return handler.next(error);
        },
        onResponse: (response, handler) {
          debugPrint(
              '🟢 RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
          debugPrint('🟢 DATA: ${response.data}');
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

  /// One call for the home cards: next event, jimpitan, fundraising and
  /// shodaqoh. Each section is `{data}` or `{error}` and fails on its own.
  ///
  /// Endpoint: `GET /api/m/v1/home`
  Future<Response> getMobileHome() async {
    return await _dio.get('/api/m/v1/home');
  }

  /// After login: the user (current roles) and the modules this user may
  /// open, worked out by the server from role and tenant settings.
  /// Endpoint: `GET /api/m/v1/bootstrap`
  Future<Response> getMobileBootstrap() async {
    return await _dio.get('/api/m/v1/bootstrap');
  }

  /// Mobile feature flags (`MODULE_<NAME>=false` hides a module) and
  /// `ORG_NAME`. Endpoint: `GET /api/m/v1/config`
  Future<Response> getMobileConfig() async {
    return await _dio.get('/api/m/v1/config');
  }

  /// Endpoint: `GET /api/m/v1/events?month=YYYY-MM`
  Future<Response> getMobileEvents(String month) async {
    return await _dio
        .get('/api/m/v1/events', queryParameters: {'month': month});
  }

  /// Endpoint: `GET /api/m/v1/events/access` → `{can_manage}`
  Future<Response> getEventAccess() async {
    return await _dio.get('/api/m/v1/events/access');
  }

  /// Choices for the event form: `{categories:[{value,order}],
  /// locations:[{value,order}]}`. Endpoint: `GET /api/m/v1/events/lookups`
  Future<Response> getEventLookups() async {
    return await _dio.get('/api/m/v1/events/lookups');
  }

  /// Endpoint: `GET /api/m/v1/events/:id` → `{event}`
  Future<Response> getMobileEvent(String id) async {
    return await _dio.get('/api/m/v1/events/$id');
  }

  /// Endpoint: `POST /api/m/v1/events` → `201 {event}`
  Future<Response> createMobileEvent(Map<String, dynamic> body) async {
    return await _dio.post('/api/m/v1/events', data: body);
  }

  /// Endpoint: `PUT /api/m/v1/events/:id` → `200 {event}`
  Future<Response> updateMobileEvent(
      String id, Map<String, dynamic> body) async {
    return await _dio.put('/api/m/v1/events/$id', data: body);
  }

  /// Endpoint: `DELETE /api/m/v1/events/:id` → `204`
  Future<Response> deleteMobileEvent(String id) async {
    return await _dio.delete('/api/m/v1/events/$id');
  }

  /// Endpoint: `GET /api/m/v1/jimpitan?month=YYYY-MM`
  Future<Response> getMobileJimpitan(String month) async {
    return await _dio
        .get('/api/m/v1/jimpitan', queryParameters: {'month': month});
  }

  /// Endpoint: `GET /api/m/v1/jimpitan/transactions?month=YYYY-MM`
  Future<Response> getMobileJimpitanTransactions(String month) async {
    return await _dio.get('/api/m/v1/jimpitan/transactions',
        queryParameters: {'month': month});
  }

  // Shodaqoh service, through the gateway. The member is taken from the login
  // token: no member id in the path or query.

  /// Tabungan Kurban of the member's family (head of family) or of themself.
  /// Endpoint: `GET /api/m/v1/shodaqoh/me/qurban-savings`
  Future<Response> getQurbanSavings() async {
    return await _dio.get('/api/m/v1/shodaqoh/me/qurban-savings');
  }

  /// Buku Amal Jariyah of one month ([period] is `YYYY-MM`).
  /// Endpoint: `GET /api/m/v1/shodaqoh/me/family-report?period=YYYY-MM`
  Future<Response> getFamilyReport(String period) async {
    return await _dio.get('/api/m/v1/shodaqoh/me/family-report',
        queryParameters: {'period': period});
  }

  /// Buku Amal Jariyah of a whole year, one report per month.
  /// Endpoint: `GET /api/m/v1/shodaqoh/me/family-report-yearly?year=YYYY`
  Future<Response> getFamilyReportYearly(int year) async {
    return await _dio.get('/api/m/v1/shodaqoh/me/family-report-yearly',
        queryParameters: {'year': year});
  }

  /// Months the member has not deposited yet.
  /// Endpoint: `GET /api/m/v1/shodaqoh/me/pending-periods`
  Future<Response> getPendingPeriods() async {
    return await _dio.get('/api/m/v1/shodaqoh/me/pending-periods');
  }

  /// The shodaqoh items that can be deposited for [month] (`YYYY-MM`).
  /// Endpoint: `GET /api/m/v1/shodaqoh/me/collection?month=YYYY-MM`
  Future<Response> getCollection(String month) async {
    return await _dio.get('/api/m/v1/shodaqoh/me/collection',
        queryParameters: {'month': month});
  }

  /// Catalog of shodaqoh items for the setoran form. Each filter is sent only
  /// when given (`true` / `false`).
  /// Endpoint: `GET /api/m/v1/shodaqoh/me/items?is_additional_item=&is_active=`
  Future<Response> getShodaqohItems(
      {bool? isAdditional, bool? isActive}) async {
    return await _dio.get('/api/m/v1/shodaqoh/me/items', queryParameters: {
      if (isAdditional != null) 'is_additional_item': '$isAdditional',
      if (isActive != null) 'is_active': '$isActive',
    });
  }

  /// Self-service deposit, `multipart/form-data`: field `payload` is the JSON
  /// `{"entries": [...]}` ([entries] each carry `collected_for_period`
  /// (`YYYY-MM`), `items` / `additional_items`, optional `notes` and
  /// `collected_at`) and `proof` is the required transfer proof (JPEG, PNG or
  /// PDF, at most 5 MB). The gateway uploads the proof and the server forces
  /// `status: "pending"` (waits for the treasurer, KU); if shodaqoh refuses,
  /// the proof is removed again. No Content-Type is forced: Dio builds it.
  /// [month] is the current month; every entry's period is at most [month].
  /// Endpoint: `POST /api/m/v1/shodaqoh/me/collection?month=YYYY-MM`
  Future<Response> submitCollection(
    String month,
    List<Map<String, dynamic>> entries, {
    required List<int> proofBytes,
    required String proofName,
  }) async {
    return await _dio.post(
      '/api/m/v1/shodaqoh/me/collection',
      queryParameters: {'month': month},
      data: FormData.fromMap({
        'payload': jsonEncode({'entries': entries}),
        'proof': MultipartFile.fromBytes(proofBytes, filename: proofName),
      }),
      options: Options(
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
  }

  /// Target and amount collected for one item (`K-07` is kurban).
  /// Endpoint: `GET /api/m/v1/shodaqoh/me/family-collection-summary`
  Future<Response> getFamilyCollectionSummary(String itemCode) async {
    return await _dio.get('/api/m/v1/shodaqoh/me/family-collection-summary',
        queryParameters: {'item_code': itemCode});
  }

  /// Endpoint: `GET /api/m/v1/fundraising`
  Future<Response> getMobileFundraising() async {
    return await _dio.get('/api/m/v1/fundraising');
  }

  // Personal budget (module `budget`): a wallet per user, apart from the
  // organisation's cash. Amounts are decimal strings.

  /// `month` is `YYYY-MM`; empty means the current month.
  Future<Response> getBudgetSummary(String month) => _dio
      .get('/api/m/v1/budget/summary', queryParameters: {'month': month});

  Future<Response> getBudgetTransactions(
          {String? from, String? to, String? categoryId, int limit = 200}) =>
      _dio.get('/api/m/v1/budget/transactions', queryParameters: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (categoryId != null) 'category_id': categoryId,
        'limit': limit,
      });

  Future<Response> createBudgetTransaction(Map<String, dynamic> body) =>
      _dio.post('/api/m/v1/budget/transactions', data: body);

  /// All fields again, not a patch.
  Future<Response> updateBudgetTransaction(
          String id, Map<String, dynamic> body) =>
      _dio.put('/api/m/v1/budget/transactions/$id', data: body);

  Future<Response> deleteBudgetTransaction(String id) =>
      _dio.delete('/api/m/v1/budget/transactions/$id');

  Future<Response> getBudgetCategories() => _dio.get(
      '/api/m/v1/budget/categories',
      queryParameters: {'include_inactive': true});

  Future<Response> createBudgetCategory(String name, String type) => _dio
      .post('/api/m/v1/budget/categories', data: {'name': name, 'type': type});

  Future<Response> updateBudgetCategory(
          String id, String name, String type, bool active) =>
      _dio.put('/api/m/v1/budget/categories/$id',
          data: {'name': name, 'type': type, 'is_active': active});

  Future<Response> deleteBudgetCategory(String id) =>
      _dio.delete('/api/m/v1/budget/categories/$id');

  Future<Response> getBudgetLimits(String month) => _dio
      .get('/api/m/v1/budget/limits', queryParameters: {'month': month});

  /// Field `audio` (m4a/wav, at most 10 MiB). 200 answers the transaction
  /// already created; 422 carries the transcript, the amount read and the
  /// candidate categories.
  Future<Response> sendBudgetVoice(List<int> bytes, String name) {
    final form = FormData.fromMap({
      'audio': MultipartFile.fromBytes(bytes, filename: name),
    });
    return _dio.post(
      '/api/m/v1/budget/voice-transaction',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
  }

  /// Upsert: new and existing limits alike; `"0"` clears it.
  Future<Response> putBudgetLimit(
          String categoryId, String amount, String month) =>
      _dio.put('/api/m/v1/budget/limits',
          data: {'category_id': categoryId, 'amount': amount, 'month': month});

  // Finance, through the mobile gateway (docs: baraka-mobile-finance-api.md).
  // Lists come back as bare arrays; amounts are decimal strings.

  /// Opening/closing balance and in/outflow of `YYYY-MM`.
  Future<Response> getFinanceBalances(String month) => _dio
      .get('/api/m/v1/finance/balances', queryParameters: {'month': month});

  Future<Response> getFinanceTransactions(String month) => _dio.get(
      '/api/m/v1/finance/transactions',
      queryParameters: {'month': month});

  Future<Response> getFinanceBookkeeping(String month) => _dio.get(
      '/api/m/v1/finance/daily-bookkeeping',
      queryParameters: {'month': month});

  Future<Response> getFinancePending() =>
      _dio.get('/api/m/v1/finance/submissions/pending');

  Future<Response> getFinanceAccounts() =>
      _dio.get('/api/m/v1/finance/lookups/accounts');

  /// `action`: approve, reject (needs [reason]) or cancel.
  Future<Response> decideFinanceSubmission(String id, String action,
          {String? reason}) =>
      _dio.post('/api/m/v1/finance/submissions/$id/$action',
          data: {if (reason != null) 'reason': reason});

  /// A manual submission; resending the same key returns the same one.
  Future<Response> submitFinanceTransaction(Map<String, dynamic> body) =>
      _dio.post('/api/m/v1/finance/transactions', data: body);

  /// Field `audio` (m4a/wav, at most 10 MiB); the answer is a pending
  /// submission, not a finished transaction.
  Future<Response> sendVoiceTransaction(List<int> bytes, String name) {
    final form = FormData.fromMap({
      'audio': MultipartFile.fromBytes(bytes, filename: name),
    });
    return _dio.post(
      '/api/m/v1/finance/voice-transaction',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
  }

  /// The request that donates to a fundraising campaign, apart from the call
  /// itself so it can be checked without a server.
  ///
  /// Four form fields only: the donor is taken from the login token, and a
  /// `member_id` or `donor_name` from the client would be ignored. No
  /// Content-Type is forced: Dio builds the multipart one, boundary included.
  static ({String path, FormData data, Options options}) donationRequest({
    required String campaignId,
    required String amount,
    required String paidDate,
    String notes = '',
    required List<int> proofBytes,
    required String proofName,
    required String idempotencyKey,
  }) {
    return (
      path:
          '/api/m/v1/fundraising/${Uri.encodeComponent(campaignId)}/donations',
      data: FormData.fromMap({
        'amount': amount,
        'paid_date': paidDate,
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
        'proof': MultipartFile.fromBytes(proofBytes, filename: proofName),
      }),
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey},
        // An upload of up to 5 MB needs longer than the 10 s of other calls.
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
  }

  /// Donate to a fundraising campaign. Answers 202 `{donation_id, status:
  /// "pending"}`: the donation waits for the treasurer (KU) and is not part of
  /// the contribution until approved.
  ///
  /// [idempotencyKey] is a UUID per donation attempt: the same one for a retry
  /// of the same donation, a new one for the next.
  ///
  /// Endpoint: `POST /api/m/v1/fundraising/{campaignId}/donations`
  Future<Response> submitFundraisingDonation({
    required String campaignId,
    required String amount,
    required String paidDate,
    String notes = '',
    required List<int> proofBytes,
    required String proofName,
    required String idempotencyKey,
  }) async {
    final r = donationRequest(
      campaignId: campaignId,
      amount: amount,
      paidDate: paidDate,
      notes: notes,
      proofBytes: proofBytes,
      proofName: proofName,
      idempotencyKey: idempotencyKey,
    );
    return await _dio.post(r.path, data: r.data, options: r.options);
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
  /// Own profile. Endpoint: `GET /api/m/v1/profile` (flat answer; no `sex`
  /// for an account not linked to a member). See docs/PROFILE_PASSWORD_API.md.
  Future<Response> getProfile() async {
    return await _dio.get('/api/m/v1/profile');
  }

  /// Own family, read-only, already sorted by the server (head first, then
  /// oldest birth date, then name). The family comes from the token.
  /// Endpoint: `GET /api/m/v1/profile/family`.
  Future<Response> getProfileFamily() async {
    return await _dio.get('/api/m/v1/profile/family');
  }

  /// Edit own profile, partially: only the fields in [data] change
  /// (`first_name`, `last_name`, `email`, `phone`, `sex`). Changing the email
  /// also needs `current_password`. Never the `user_id`. Answers the updated
  /// profile. Endpoint: `PUT /api/m/v1/profile`.
  Future<Response> updateProfile(Map<String, dynamic> data) async {
    return await _dio.put('/api/m/v1/profile', data: data);
  }

  /// Replaces the profile photo: multipart field `avatar` (jpeg/png/webp,
  /// at most 2 MB; the server does not resize). Answers the updated profile,
  /// whose `avatar` is the new path. Endpoint: `PUT /api/m/v1/profile/avatar`.
  Future<Response> uploadAvatar(List<int> bytes, String name) {
    return _dio.put(
      '/api/m/v1/profile/avatar',
      data: FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: name),
      }),
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  }

  /// Removes the photo; repeatable. Answers the profile with `avatar: ""`.
  /// Endpoint: `DELETE /api/m/v1/profile/avatar`.
  Future<Response> deleteAvatar() async {
    return await _dio.delete('/api/m/v1/profile/avatar');
  }

  /// Change own password. Endpoint: `PUT /api/m/v1/password`.
  Future<Response> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return await _dio.put('/api/m/v1/password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });
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
    String afiliasi = '',
    String externalId = '',
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
        if (afiliasi.isNotEmpty) 'afiliasi': afiliasi,
        if (externalId.isNotEmpty) 'external_id': externalId,
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
    String createdBy = '',
    String updatedBy = '',
  }) async {
    return await _dio.post(
      '/api/zakat-fitrah/muzakki/bulk',
      data: {
        if (yearId != null && yearId.isNotEmpty) 'year_id': yearId,
        'muzakkis': muzakkis,
        if (createdBy.isNotEmpty) 'created_by': createdBy,
        if (updatedBy.isNotEmpty) 'updated_by': updatedBy,
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

  /// Verify or unverify a muzakki record.
  ///
  /// Endpoint: `PATCH /api/zakat-fitrah/muzakki/{id}/verify`
  /// Payload: `{ status: bool }`
  Future<Response> verifyMuzakki(String id, {required bool status}) async {
    return await _dio.patch(
      '/api/zakat-fitrah/muzakki/$id/verify',
      data: {'status': status},
    );
  }

  /// Fetch verification recap for muzakki by year.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/muzakki/verification-recap?year_id={yearId}`
  Future<Response> getZakatMuzakkiVerificationRecap({
    required String yearId,
  }) async {
    return await _dio.get(
      '/api/zakat-fitrah/muzakki/verification-recap',
      queryParameters: {'year_id': yearId},
    );
  }

  /// Fetch recent zakat payment transactions.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/transactions/recent?limit={limit}&year_id={yearId}`
  Future<Response> getZakatRecentTransactions({
    int limit = 10,
    String? yearId,
  }) async {
    return await _dio.get(
      '/api/zakat-fitrah/transactions/recent',
      queryParameters: {
        'limit': limit,
        if (yearId != null && yearId.isNotEmpty) 'year_id': yearId,
      },
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
        .get('/api/zakat-fitrah/configurations/module/$module/code/$code');
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
  ///
  /// [serahTerima] optional: `{ 'mode': 'titip'|'akad', 'amil_name': '...' }`
  /// When provided, the backend handles serah terima atomically.
  Future<Response> createZakatTransactionBulk({
    required String yearId,
    required int year,
    required String amilName,
    required String notes,
    required List<Map<String, String>> registeredAllocations,
    required Map<String, dynamic> externalBreakdown,
    required List<Map<String, dynamic>> paymentBreakdown,
    required int totalSouls,
    Map<String, dynamic>? serahTerima,
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
        if (serahTerima != null) 'serah_terima': serahTerima,
      },
    );
  }

  // ── Master Eksternal (global) ───────────────────────────────────────────

  /// Endpoint: `GET /api/zakat-fitrah/externals`
  Future<Response> getZakatExternals() async {
    return await _dio.get('/api/zakat-fitrah/externals');
  }

  /// Endpoint: `POST /api/zakat-fitrah/externals`
  Future<Response> createZakatExternal(Map<String, dynamic> data) async {
    return await _dio.post('/api/zakat-fitrah/externals', data: data);
  }

  /// Endpoint: `PUT /api/zakat-fitrah/externals/{id}`
  Future<Response> updateZakatExternal(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await _dio.put('/api/zakat-fitrah/externals/$id', data: data);
  }

  /// Endpoint: `DELETE /api/zakat-fitrah/externals/{id}`
  Future<Response> deleteZakatExternal(String id) async {
    return await _dio.delete('/api/zakat-fitrah/externals/$id');
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

  /// Mark or toggle akad (serah terima ke amil) for a single muzakki.
  ///
  /// Endpoint: `PATCH /api/zakat-fitrah/muzakki/{id}/akad`
  Future<Response> patchZakatMuzakkiAkad(
    String id, {
    required bool status,
    String? representative,
  }) async {
    final body = <String, dynamic>{
      'status': status,
      if (representative != null && representative.trim().isNotEmpty)
        'representative': representative.trim(),
    };
    debugPrint('🤝 AKAD REQUEST → PATCH /api/zakat-fitrah/muzakki/$id/akad');
    debugPrint('🤝 AKAD BODY: $body');
    final resp = await _dio.patch(
      '/api/zakat-fitrah/muzakki/$id/akad',
      data: body,
    );
    debugPrint('🤝 AKAD RESPONSE ${resp.statusCode}: ${resp.data}');
    return resp;
  }

  /// Mark akad (serah terima ke amil) for all paid members of a family.
  ///
  /// Endpoint: `PATCH /api/zakat-fitrah/muzakki/family/{family_id}/akad`
  Future<Response> patchZakatMuzakkiFamilyAkad(
    String familyId, {
    required bool status,
    required String amilName,
  }) async {
    final body = <String, dynamic>{
      'status': status,
      'amil_name': amilName,
    };
    debugPrint(
        '🤝 FAMILY AKAD REQUEST → PATCH /api/zakat-fitrah/muzakki/family/$familyId/akad');
    debugPrint('🤝 FAMILY AKAD BODY: $body');
    final resp = await _dio.patch(
      '/api/zakat-fitrah/muzakki/family/$familyId/akad',
      data: body,
    );
    debugPrint('🤝 FAMILY AKAD RESPONSE ${resp.statusCode}: ${resp.data}');
    return resp;
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

  // ── Amil endpoints ───────────────────────────────────────────────────────

  /// Fetch all amil records.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/amil`
  Future<Response> getZakatAmilList({String? yearId}) async {
    return await _dio.get(
      '/api/zakat-fitrah/amil',
      data: {
        if (yearId != null && yearId.isNotEmpty) 'year_id': yearId,
      },
    );
  }

  /// Fetch family zakat resume (paid/unpaid members summary).
  ///
  /// Endpoint: `GET /api/zakat-fitrah/families/:familyId/zakat-resume`
  Future<Response> getFamilyZakatResume(String familyId,
      {required String yearId}) async {
    return await _dio.get(
      '/api/zakat-fitrah/families/$familyId/zakat-resume',
      queryParameters: {'year_id': yearId},
    );
  }

  /// Fetch active amil records.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/amil/active`
  Future<Response> getZakatAmilActive({String? yearId}) async {
    return await _dio.get(
      '/api/zakat-fitrah/amil/active',
      queryParameters: {
        if (yearId != null && yearId.isNotEmpty) 'year_id': yearId,
      },
    );
  }

  /// Create a new amil record.
  ///
  /// Endpoint: `POST /api/zakat-fitrah/amil`
  Future<Response> createZakatAmil(Map<String, dynamic> data) async {
    return await _dio.post('/api/zakat-fitrah/amil', data: data);
  }

  /// Update an amil record by id.
  ///
  /// Endpoint: `PUT /api/zakat-fitrah/amil/{id}`
  Future<Response> updateZakatAmil(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await _dio.put('/api/zakat-fitrah/amil/$id', data: data);
  }

  /// Delete an amil record by id.
  ///
  /// Endpoint: `DELETE /api/zakat-fitrah/amil/{id}`
  Future<Response> deleteZakatAmil(String id) async {
    return await _dio.delete('/api/zakat-fitrah/amil/$id');
  }

  /// Fetch amil KPI for a given year.
  ///
  /// Endpoint: `GET /api/zakat-fitrah/amil/kpi?year_id={yearId}`
  Future<Response> getZakatAmilKpi({required String yearId}) async {
    return await _dio.get(
      '/api/zakat-fitrah/amil/kpi',
      queryParameters: {'year_id': yearId},
    );
  }

  // ── Configuration endpoints ──────────────────────────────────────────────

  Future<Response> getConfigurations() async {
    return await _dio.get('/api/zakat-fitrah/configurations');
  }

  Future<Response> getConfigurationsByModule(String module,
      {String? yearId}) async {
    return await _dio.get(
      '/api/zakat-fitrah/configurations/module/$module',
      queryParameters: {
        if (yearId != null && yearId.isNotEmpty) 'year_id': yearId,
      },
    );
  }

  Future<Response> getConfigurationByModuleAndCode(
    String module,
    String code,
  ) async {
    return await _dio
        .get('/api/zakat-fitrah/configurations/module/$module/code/$code');
  }

  Future<Response> getConfigurationByOid(String oid) async {
    return await _dio.get('/api/zakat-fitrah/configurations/$oid');
  }

  Future<Response> getConfigurationValueByCode(String code) async {
    return await _dio.get('/api/zakat-fitrah/configurations/code/$code/value');
  }

  Future<Response> createConfiguration(Map<String, dynamic> data) async {
    return await _dio.post('/api/zakat-fitrah/configurations', data: data);
  }

  Future<Response> updateConfiguration(
    String oid,
    Map<String, dynamic> data,
  ) async {
    return await _dio.put('/api/zakat-fitrah/configurations/$oid', data: data);
  }

  Future<Response> deleteConfiguration(String oid) async {
    return await _dio.delete('/api/zakat-fitrah/configurations/$oid');
  }

  // ── Zakat Fitrah History (closing) endpoints ─────────────────────────────

  /// Finalize / close a zakat year — creates a history snapshot.
  /// Endpoint: `POST /api/zakat-fitrah/history`
  Future<Response> createZakatHistory(Map<String, dynamic> data) async {
    return await _dio.post('/api/zakat-fitrah/history', data: data);
  }

  /// Fetch all history snapshots.
  /// Endpoint: `GET /api/zakat-fitrah/history`
  Future<Response> getZakatHistory() async {
    return await _dio.get('/api/zakat-fitrah/history');
  }

  /// Fetch a single history snapshot by year ID.
  /// Endpoint: `GET /api/zakat-fitrah/history/:year_id`
  Future<Response> getZakatHistoryByYearId(String yearId) async {
    return await _dio.get('/api/zakat-fitrah/history/$yearId');
  }
}

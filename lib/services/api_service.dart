import 'package:dio/dio.dart';
import 'storage_service.dart';

class ApiService {
  // static const String baseUrl = 'https://8ff4edc65c2d.ngrok-free.app/mblapi';
  static const String baseUrl = 'https://8ff4edc65c2d.ngrok-free.app/mblapi';
  static const String mblAPIUrl = 'https://8ff4edc65c2d.ngrok-free.app/mblapi';
  // For local testing: 'http://10.0.2.2:3000/api' (Android emulator)
  // For local testing: 'http://localhost:3000/api' (iOS simulator)
  
  late Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: mblAPIUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add interceptor for auth token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('🔵 REQUEST: ${options.method} ${options.path}');
        print('📤 DATA: ${options.data}');
        print('🔵 LOGIN URL: $baseUrl${options.path}');
        final token = StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        print('🔴 ERROR: ${error.response?.statusCode} - ${error.message}');
        print('🔴 FULL ERROR: $error');
        if (error.response?.statusCode == 401) {
          // Token expired, logout user
          StorageService.clearAll();
        }
        return handler.next(error);
      },
      onResponse: (response, handler) {
        print('🟢 RESPONSE: ${response.statusCode}');
        print('🟢 DATA: ${response.data}');
        return handler.next(response);
      },
    ));
  }

  // Auth endpoints
  Future<Response> login(String userId, String password) async {
    return await _dio.post('/login', data: {
      'user_id': userId,
      'password': password,
    });
  }

  Future<Response> logout() async {
    return await _dio.post('/logout');
  }

  // Transaction endpoints
  Future<Response> getTransactions() async {
    return await _dio.get('/transactions');
  }

  Future<Response> createTransaction(Map<String, dynamic> data) async {
    return await _dio.post('/transactions', data: data);
  }

  Future<Response> updateTransaction(String id, Map<String, dynamic> data) async {
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
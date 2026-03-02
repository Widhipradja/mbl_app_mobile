import 'package:dio/dio.dart';
import 'dart:async';

class ConfigService {
  static const String configUrl =
      'https://widhipradja.github.io/mblapp-config/config.json';
  static String? _apiBaseUrl;

  static String get apiBaseUrl => _apiBaseUrl ?? 'http://192.168.0.13:3000';

  static Future<void> loadRemoteConfig() async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);

      final response = await dio.get(configUrl);

      if (response.statusCode == 200 && response.data != null) {
        final config = response.data;
        if (config['mblapi_url'] != null) {
          _apiBaseUrl = config['mblapi_url'];
          // debugPrint('✅ Remote config loaded: $_apiBaseUrl');
        }
      }
    } catch (e) {
      // debugPrint('⚠️ Failed to load remote config, using default URL: $e');
      // Fallback to default URL already set in getter
    }
  }

  static void setApiBaseUrl(String url) {
    _apiBaseUrl = url;
  }
}

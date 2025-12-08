class AppConstants {
  // Tenant Configuration
  // For multi-tenant: Set to null and pass during login
  // For single-tenant: Uncomment and set specific tenant ID
  // static const String tenantId = 'c4e70117-1e32-468d-a5e5-f954a5de218d';
  static const String? tenantId = null; // Multi-tenant mode

  // API Configuration
  static const String apiBaseUrl = 'https://59141266354a.ngrok-free.app/mblapi';

  // For local development
  static const String localApiUrl =
      'http://10.0.2.2:3000/api'; // Android Emulator
  static const String iosLocalApiUrl =
      'http://localhost:3000/api'; // iOS Simulator

  // App Info
  static const String appName = 'Manage Budget & Logs';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String tenantIdKey = 'tenant_id';

  // Demo Credentials
  static const String demoEmail = 'demo@example.com';
  static const String demoPassword = 'password';
}

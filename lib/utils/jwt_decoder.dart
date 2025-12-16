import 'package:jwt_decode/jwt_decode.dart';

class JwtDecoder {
  /// Decode JWT token and return claims
  static Map<String, dynamic>? decode(String token) {
    try {
      return Jwt.parseJwt(token);
    } catch (e) {
      // debugPrint('Error decoding JWT: $e');
      return null;
    }
  }

  /// Check if token is expired
  static bool isExpired(String token) {
    try {
      return Jwt.isExpired(token);
    } catch (e) {
      // debugPrint('Error checking token expiry: $e');
      return true;
    }
  }

  /// Get expiry date from token
  static DateTime? getExpiryDate(String token) {
    try {
      return Jwt.getExpiryDate(token);
    } catch (e) {
      // debugPrint('Error getting expiry date: $e');
      return null;
    }
  }

  /// Extract user data from JWT claims
  static Map<String, dynamic>? getUserDataFromToken(String token) {
    final claims = decode(token);
    if (claims == null) return null;

    return {
      'name': claims['name'],
      'email': claims['email'],
      'user_id': claims['user_id'],
      'tenant_id': claims['tenant_id'],
      'roles': claims['roles'],
      'iss': claims['iss'],
      'aud': claims['aud'],
      'exp': claims['exp'],
    };
  }

  /// Extract tenant ID from token
  static String? getTenantId(String token) {
    final claims = decode(token);
    return claims?['tenant_id'];
  }

  /// Extract user ID from token
  static String? getUserId(String token) {
    final claims = decode(token);
    return claims?['user_id'];
  }

  /// Extract roles from token
  static List<String>? getRoles(String token) {
    final claims = decode(token);
    final roles = claims?['roles'];
    if (roles is List) {
      return List<String>.from(roles);
    }
    return null;
  }
}

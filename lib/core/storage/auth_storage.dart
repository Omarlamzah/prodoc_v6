import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();
  
  // Keys
  static const String _authTokenKey = 'authToken';
  static const String _csrfTokenKey = 'XSRF-TOKEN';
  
  // Token Management
  static Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _authTokenKey, value: token);
  }
  
  static Future<String?> getAuthToken() async {
    return await _storage.read(key: _authTokenKey);
  }
  
  static Future<void> removeAuthToken() async {
    await _storage.delete(key: _authTokenKey);
  }
  
  // CSRF Token Management
  static Future<void> saveCsrfToken(String token) async {
    await _storage.write(key: _csrfTokenKey, value: token);
  }
  
  static Future<String?> getCsrfToken() async {
    return await _storage.read(key: _csrfTokenKey);
  }
  
  static Future<void> removeCsrfToken() async {
    await _storage.delete(key: _csrfTokenKey);
  }
  
  // Clear all auth data
  static Future<void> clearAll() async {
    await removeAuthToken();
    await removeCsrfToken();
  }
  
  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }
}


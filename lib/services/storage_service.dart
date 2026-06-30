// lib/services/storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../data/models/tenant_model.dart';

class StorageService {
  static const String _selectedTenantKey = 'selected_tenant';
  static const String _authTokenKey = 'auth_token';
  static const String _rememberMeKey = 'remember_me';
  static const String _savedIdentifierKey = 'saved_identifier';
  // Legacy key kept for backwards compatibility with earlier versions
  static const String _legacySavedEmailKey = 'saved_email';

  // Use secure storage for sensitive data
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  Future<void> saveTenant(TenantModel tenant) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedTenantKey, jsonEncode(tenant.toJson()));
  }

  Future<TenantModel?> getSavedTenant() async {
    final prefs = await SharedPreferences.getInstance();
    final tenantJson = prefs.getString(_selectedTenantKey);
    if (tenantJson != null) {
      return TenantModel.fromJson(jsonDecode(tenantJson));
    }
    return null;
  }

  Future<void> clearTenant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedTenantKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  // Remember Me functionality
  Future<void> saveRememberMe(
      bool remember, String identifier, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, remember);
    await prefs.setString(_savedIdentifierKey, identifier);
    // Clean up legacy key if present to avoid stale values
    await prefs.remove(_legacySavedEmailKey);

    if (remember) {
      // Save password securely
      await _secureStorage.write(key: 'saved_password', value: password);
    } else {
      // Clear saved credentials
      await prefs.remove(_savedIdentifierKey);
      await prefs.remove(_legacySavedEmailKey);
      await _secureStorage.delete(key: 'saved_password');
    }
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  Future<String?> getSavedIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    // Prefer the new key but fall back to legacy email key for existing users
    return prefs.getString(_savedIdentifierKey) ??
        prefs.getString(_legacySavedEmailKey);
  }

  Future<String?> getSavedPassword() async {
    if (await getRememberMe()) {
      return await _secureStorage.read(key: 'saved_password');
    }
    return null;
  }

  Future<void> clearRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_savedIdentifierKey);
    await prefs.remove(_legacySavedEmailKey);
    await _secureStorage.delete(key: 'saved_password');
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secureStorage.deleteAll();
  }
}

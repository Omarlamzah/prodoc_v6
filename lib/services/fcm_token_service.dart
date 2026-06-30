// lib/services/fcm_token_service.dart
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';

/// Service to save FCM tokens to backend
class FCMTokenService {
  final ApiClient apiClient;

  FCMTokenService({required this.apiClient});

  /// Save FCM token to backend
  Future<bool> saveToken(String token) async {
    try {
      await apiClient.post(
        '/fcm-token',
        body: {
          'token': token,
          'device_type': Platform.isAndroid ? 'android' : 'ios',
        },
        requireAuth: true,
      );

      debugPrint('[FCMTokenService] Token saved successfully');
      return true;
    } catch (e) {
      debugPrint('[FCMTokenService] Error saving token: $e');
      return false;
    }
  }
}

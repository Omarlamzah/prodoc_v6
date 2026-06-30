// lib/services/api_notification_service.dart
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../data/models/api_notification.dart';

/// Service for fetching and managing notifications from Laravel API
class ApiNotificationService {
  final ApiClient apiClient;

  ApiNotificationService({required this.apiClient});

  /// Fetch all notifications for the current user
  ///
  /// [params] - Query parameters:
  /// - read: Filter by read status (true/false)
  /// - type: Filter by notification type
  /// - per_page: Number of notifications per page (default: 20)
  /// - page: Page number (default: 1)
  Future<NotificationResponse> fetchNotifications({
    bool? read,
    String? type,
    int perPage = 20,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (read != null) queryParams['read'] = read.toString();
      if (type != null) queryParams['type'] = type;
      queryParams['per_page'] = perPage.toString();
      queryParams['page'] = page.toString();

      final response = await apiClient.get(
        ApiConstants.notifications,
        queryParameters: queryParams,
        requireAuth: true,
      );

      debugPrint('[ApiNotificationService] Raw API response: $response');

      final responseMap = response as Map<String, dynamic>;
      debugPrint(
          '[ApiNotificationService] Notifications count: ${responseMap['notifications']?.length ?? 0}');

      return NotificationResponse.fromJson(responseMap);
    } catch (e) {
      debugPrint('[ApiNotificationService] Error fetching notifications: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch notifications: $e');
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadCount() async {
    try {
      final response = await apiClient.get(
        ApiConstants.notificationsUnreadCount,
        requireAuth: true,
      );

      final data = response as Map<String, dynamic>;
      return data['unread_count'] as int? ?? 0;
    } catch (e) {
      debugPrint('[ApiNotificationService] Error fetching unread count: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to fetch unread count: $e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await apiClient.post(
        ApiConstants.notificationMarkAsRead(notificationId),
        requireAuth: true,
      );
    } catch (e) {
      debugPrint(
          '[ApiNotificationService] Error marking notification as read: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await apiClient.post(
        ApiConstants.notificationsMarkAllAsRead,
        requireAuth: true,
      );
    } catch (e) {
      debugPrint('[ApiNotificationService] Error marking all as read: $e');
      if (e is ApiException) rethrow;
      throw ApiException(
          message: 'Failed to mark all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await apiClient.delete(
        ApiConstants.notificationDelete(notificationId),
        requireAuth: true,
      );
    } catch (e) {
      debugPrint('[ApiNotificationService] Error deleting notification: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to delete notification: $e');
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      await apiClient.delete(
        ApiConstants.notifications,
        requireAuth: true,
      );
    } catch (e) {
      debugPrint(
          '[ApiNotificationService] Error deleting all notifications: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to delete all notifications: $e');
    }
  }

  /// Delete all read notifications
  Future<void> deleteReadNotifications() async {
    try {
      await apiClient.delete(
        ApiConstants.notificationsDeleteRead,
        requireAuth: true,
      );
    } catch (e) {
      debugPrint(
          '[ApiNotificationService] Error deleting read notifications: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to delete read notifications: $e');
    }
  }
}

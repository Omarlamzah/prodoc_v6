// lib/data/models/api_notification.dart
import 'package:flutter/foundation.dart';

class ApiNotification {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;
  final String message;

  ApiNotification({
    required this.id,
    required this.type,
    required this.data,
    this.readAt,
    required this.createdAt,
    required this.message,
  });

  bool get isRead => readAt != null;

  factory ApiNotification.fromJson(Map<String, dynamic> json) {
    return ApiNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      readAt: json['read_at'] != null
          ? _parseDateTime(json['read_at'] as String)
          : null,
      createdAt: _parseDateTime(json['created_at'] as String),
      message: json['message'] as String? ?? '',
    );
  }

  /// Parse datetime string that can be in ISO format or Laravel format
  /// Handles formats like:
  /// - "2026-01-23 15:08:01" (Laravel format)
  /// - "2026-01-23T15:08:01.000000Z" (ISO format)
  static DateTime _parseDateTime(String dateString) {
    try {
      // Try ISO format first
      return DateTime.parse(dateString);
    } catch (e) {
      // If ISO parse fails, try Laravel format "YYYY-MM-DD HH:mm:ss"
      try {
        // Replace space with T and add Z if not present
        final normalized = dateString.replaceFirst(' ', 'T');
        if (!normalized.contains('Z') && !normalized.contains('+')) {
          return DateTime.parse('${normalized}Z');
        }
        return DateTime.parse(normalized);
      } catch (e2) {
        // If both fail, try just adding timezone
        try {
          return DateTime.parse('${dateString}Z');
        } catch (e3) {
          // Last resort: return current time
          return DateTime.now();
        }
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'message': message,
    };
  }

  ApiNotification copyWith({
    String? id,
    String? type,
    Map<String, dynamic>? data,
    DateTime? readAt,
    DateTime? createdAt,
    String? message,
  }) {
    return ApiNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      message: message ?? this.message,
    );
  }
}

class NotificationPagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  NotificationPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory NotificationPagination.fromJson(Map<String, dynamic> json) {
    // Handle per_page as string or int
    int parsePerPage(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 20;
      return 20;
    }

    return NotificationPagination(
      currentPage: json['current_page'] is int
          ? json['current_page'] as int
          : int.tryParse(json['current_page'].toString()) ?? 1,
      lastPage: json['last_page'] is int
          ? json['last_page'] as int
          : int.tryParse(json['last_page'].toString()) ?? 1,
      perPage: parsePerPage(json['per_page']),
      total: json['total'] is int
          ? json['total'] as int
          : int.tryParse(json['total'].toString()) ?? 0,
    );
  }
}

class NotificationResponse {
  final List<ApiNotification> notifications;
  final NotificationPagination pagination;
  final int unreadCount;

  NotificationResponse({
    required this.notifications,
    required this.pagination,
    required this.unreadCount,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    try {
      final notificationsList = json['notifications'] as List<dynamic>?;
      final notifications = notificationsList
              ?.map((item) {
                try {
                  return ApiNotification.fromJson(item as Map<String, dynamic>);
                } catch (e) {
                  debugPrint(
                      '[NotificationResponse] Error parsing notification: $e');
                  debugPrint('[NotificationResponse] Notification data: $item');
                  return null;
                }
              })
              .whereType<ApiNotification>()
              .toList() ??
          [];

      return NotificationResponse(
        notifications: notifications,
        pagination: NotificationPagination.fromJson(
            json['pagination'] as Map<String, dynamic>? ?? {}),
        unreadCount: json['unread_count'] is int
            ? json['unread_count'] as int
            : int.tryParse(json['unread_count'].toString()) ?? 0,
      );
    } catch (e) {
      debugPrint('[NotificationResponse] Error parsing response: $e');
      debugPrint('[NotificationResponse] Response data: $json');
      rethrow;
    }
  }
}

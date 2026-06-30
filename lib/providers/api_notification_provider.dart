// lib/providers/api_notification_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../services/api_notification_service.dart';
import '../data/models/api_notification.dart';
import 'api_providers.dart';
import 'auth_providers.dart';
import '../services/notification_service.dart';

// API Notification Service Provider
final apiNotificationServiceProvider = Provider<ApiNotificationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiNotificationService(apiClient: apiClient);
});

// Notification State
class NotificationState {
  final List<ApiNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 1,
  });

  NotificationState copyWith({
    List<ApiNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

// Notification Notifier
class NotificationNotifier extends Notifier<NotificationState> {
  late ApiNotificationService _notificationService;
  late NotificationService _localNotificationService;
  Timer? _pollingTimer;

  @override
  NotificationState build() {
    _notificationService = ref.watch(apiNotificationServiceProvider);
    _localNotificationService = ref.watch(notificationServiceProvider);
    
    // Cleanup timer when provider is disposed
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    
    // Start polling when provider is initialized
    Future.microtask(() {
      startPolling();
      // Also fetch notifications immediately when provider initializes
      // This ensures notifications are loaded when app opens
      fetchNotifications(refresh: true);
    });
    
    return NotificationState();
  }

  /// Start polling for new notifications
  void startPolling({Duration interval = const Duration(seconds: 30)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) {
      refreshUnreadCount();
      // Optionally refresh notifications in background
      // fetchNotifications(refresh: true);
    });
  }

  /// Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
  }

  /// Fetch notifications from API
  Future<void> fetchNotifications({
    bool refresh = false,
    int? page,
    bool? read,
    String? type,
  }) async {
    if (state.isLoading && !refresh) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      final currentPage = page ?? (refresh ? 1 : state.currentPage);
      final response = await _notificationService.fetchNotifications(
        read: read,
        type: type,
        perPage: 20,
        page: currentPage,
      );

      final newNotifications = refresh
          ? response.notifications
          : [...state.notifications, ...response.notifications];

      debugPrint(
          '[NotificationNotifier] Fetched ${response.notifications.length} notifications');
      debugPrint(
          '[NotificationNotifier] Total notifications: ${newNotifications.length}');
      debugPrint('[NotificationNotifier] Unread count: ${response.unreadCount}');

      state = state.copyWith(
        notifications: newNotifications,
        unreadCount: response.unreadCount,
        isLoading: false,
        hasMore: currentPage < response.pagination.lastPage,
        currentPage: currentPage,
      );

      // Show local notifications for new unread notifications
      if (refresh) {
        _showLocalNotificationsForNewUnread(response.notifications);
      }
    } catch (e, stackTrace) {
      debugPrint('[NotificationNotifier] Error fetching notifications: $e');
      debugPrint('[NotificationNotifier] Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh unread count only (lighter operation)
  Future<void> refreshUnreadCount() async {
    try {
      final unreadCount = await _notificationService.getUnreadCount();
      final previousUnreadCount = state.unreadCount;

      state = state.copyWith(unreadCount: unreadCount);

      // If unread count increased, fetch new notifications
      if (unreadCount > previousUnreadCount) {
        await fetchNotifications(refresh: true);
      }
    } catch (e) {
      debugPrint('[NotificationNotifier] Error refreshing unread count: $e');
    }
  }

  /// Show local notifications for new unread notifications
  void _showLocalNotificationsForNewUnread(
      List<ApiNotification> notifications) async {
    final unreadNotifications =
        notifications.where((n) => !n.isRead).toList();

    for (final notification in unreadNotifications) {
      // Determine notification type from Laravel notification type
      final notificationType = _getNotificationTypeFromLaravelType(
          notification.type, notification.data);

      // Show appropriate local notification
      await _showLocalNotification(notification, notificationType);
    }
  }

  /// Get notification type from Laravel notification class name
  String _getNotificationTypeFromLaravelType(
      String laravelType, Map<String, dynamic> data) {
    if (laravelType.contains('AppointmentCreated') ||
        laravelType.contains('AppointmentConfirmed')) {
      return 'appointment';
    } else if (laravelType.contains('AppointmentRejected')) {
      return 'appointment_rejected';
    } else if (laravelType.contains('Invoice')) {
      return 'invoice';
    } else if (laravelType.contains('Prescription')) {
      return 'prescription';
    } else if (laravelType.contains('Emergency')) {
      return 'emergency';
    }
    return 'info';
  }

  /// Show local notification based on API notification
  Future<void> _showLocalNotification(
      ApiNotification notification, String type) async {
    final message = notification.message;
    final title = _getNotificationTitle(type, notification.data);

    // Determine notification type enum
    NotificationType localType = NotificationType.info;
    if (type == 'emergency') {
      localType = NotificationType.urgent;
    } else if (type == 'appointment_rejected') {
      localType = NotificationType.warning;
    } else if (type == 'appointment' || type == 'prescription') {
      localType = NotificationType.success;
    }

    // Extract IDs from data for navigation
    final appointmentId = notification.data['appointment_id'] as int?;
    final prescriptionId = notification.data['prescription_id'] as int?;
    final invoiceId = notification.data['invoice_id'] as int?;

    final payload = <String, dynamic>{
      'type': type,
      'notification_id': notification.id,
      if (appointmentId != null) 'appointment_id': appointmentId,
      if (prescriptionId != null) 'prescription_id': prescriptionId,
      if (invoiceId != null) 'invoice_id': invoiceId,
    };

    // Show notification based on type
    if (type == 'appointment' && appointmentId != null) {
      await _localNotificationService.showAppointmentNotification(
        title: title,
        message: message,
        appointmentId: appointmentId,
        payload: payload,
      );
    } else if (type == 'prescription' && prescriptionId != null) {
      await _localNotificationService.showPrescriptionReadyNotification(
        patientName: notification.data['patient_name'] as String? ?? 'Patient',
        prescriptionId: prescriptionId,
        payload: payload,
      );
    } else if (type == 'emergency') {
      await _localNotificationService.showEmergencyNotification(
        title: title,
        message: message,
        location: notification.data['location'] as String? ?? '',
        payload: payload,
      );
    } else {
      // Generic notification
      final role = ref.read(authProvider).user?.role ?? 'patient';
      if (role == 'admin') {
        await _localNotificationService.showAdminNotification(
          title: title,
          message: message,
          notificationId: int.tryParse(notification.id) ?? 0,
          type: localType,
          payload: payload,
        );
      } else if (role == 'doctor') {
        await _localNotificationService.showDoctorNotification(
          title: title,
          message: message,
          notificationId: int.tryParse(notification.id) ?? 0,
          type: localType,
          payload: payload,
        );
      } else {
        await _localNotificationService.showPatientNotification(
          title: title,
          message: message,
          notificationId: int.tryParse(notification.id) ?? 0,
          type: localType,
          payload: payload,
        );
      }
    }
  }

  /// Get notification title from type and data
  String _getNotificationTitle(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'appointment':
        return 'Nouveau rendez-vous';
      case 'appointment_rejected':
        return 'Rendez-vous rejeté';
      case 'prescription':
        return 'Ordonnance prête';
      case 'invoice':
        return 'Nouvelle facture';
      case 'emergency':
        return 'Alerte d\'urgence';
      default:
        return 'Notification';
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);

      // Update local state
      state = state.copyWith(
        notifications: state.notifications.map((n) {
          if (n.id == notificationId) {
            return n.copyWith(readAt: DateTime.now());
          }
          return n;
        }).toList(),
        unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
      );
    } catch (e) {
      debugPrint('[NotificationNotifier] Error marking as read: $e');
      throw e;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();

      // Update local state
      final now = DateTime.now();
      state = state.copyWith(
        notifications: state.notifications
            .map((n) => n.copyWith(readAt: n.readAt ?? now))
            .toList(),
        unreadCount: 0,
      );
    } catch (e) {
      debugPrint('[NotificationNotifier] Error marking all as read: $e');
      throw e;
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);

      // Update local state
      final wasUnread = state.notifications
          .firstWhere((n) => n.id == notificationId, orElse: () => throw Exception())
          .isRead == false;

      state = state.copyWith(
        notifications: state.notifications
            .where((n) => n.id != notificationId)
            .toList(),
        unreadCount: wasUnread && state.unreadCount > 0
            ? state.unreadCount - 1
            : state.unreadCount,
      );
    } catch (e) {
      debugPrint('[NotificationNotifier] Error deleting notification: $e');
      throw e;
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      await _notificationService.deleteAllNotifications();

      state = state.copyWith(
        notifications: [],
        unreadCount: 0,
      );
    } catch (e) {
      debugPrint('[NotificationNotifier] Error deleting all: $e');
      throw e;
    }
  }

  /// Delete all read notifications
  Future<void> deleteReadNotifications() async {
    try {
      await _notificationService.deleteReadNotifications();

      state = state.copyWith(
        notifications: state.notifications.where((n) => n.isRead).toList(),
      );
    } catch (e) {
      debugPrint('[NotificationNotifier] Error deleting read: $e');
      throw e;
    }
  }
}

// Notification Provider
final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
        NotificationNotifier.new);

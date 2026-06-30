// lib/services/fcm_service.dart
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import '../core/network/api_client.dart';

/// Top-level function to handle background messages
/// This must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message received: ${message.messageId}');
  debugPrint('[FCM] Message data: ${message.data}');
  debugPrint('[FCM] Message notification: ${message.notification?.title}');

  // Show notification even when app is closed
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Handle different message types
  final messageType = message.data['type'] as String?;

  if (messageType == 'message') {
    await notificationService.showMessageNotification(
      senderName: message.data['sender_name'] as String? ??
          message.notification?.title ??
          'Nouveau message',
      message: message.data['message'] as String? ??
          message.notification?.body ??
          '',
      senderId: int.tryParse(message.data['sender_id']?.toString() ?? '0') ?? 0,
      messageType: message.data['message_type'] as String?,
      senderAvatar: message.data['sender_avatar'] as String?,
      payload: message.data,
    );
  } else if (messageType == 'emergency') {
    await notificationService.showEmergencyNotification(
      title: message.data['title'] as String? ??
          message.notification?.title ??
          'Alerte',
      message: message.data['message'] as String? ??
          message.notification?.body ??
          '',
      location: message.data['location'] as String? ?? '',
      requesterName: message.data['requester_name'] as String?,
      payload: message.data,
    );
  } else if (messageType == 'appointment' ||
      messageType == 'appointment_created' ||
      messageType == 'appointment_confirmed' ||
      messageType == 'appointment_rejected' ||
      message.data.containsKey('appointment_id')) {
    // Appointment notification
    await notificationService.showAppointmentNotification(
      title: message.data['title'] as String? ??
          message.notification?.title ??
          'Nouveau rendez-vous',
      message: message.data['message'] as String? ??
          message.notification?.body ??
          '',
      appointmentId:
          int.tryParse(message.data['appointment_id']?.toString() ?? '0') ?? 0,
      patientName: message.data['patient_name'] as String?,
      doctorName: message.data['doctor_name'] as String?,
      payload: message.data,
    );
  } else if (messageType == 'prescription' ||
      messageType == 'prescription_ready' ||
      message.data.containsKey('prescription_id')) {
    // Prescription notification
    await notificationService.showPrescriptionReadyNotification(
      patientName: message.data['patient_name'] as String? ?? 'Patient',
      prescriptionId:
          int.tryParse(message.data['prescription_id']?.toString() ?? '0') ?? 0,
      doctorName: message.data['doctor_name'] as String?,
      payload: message.data,
    );
  } else if (messageType == 'invoice' ||
      message.data.containsKey('invoice_id')) {
    // Invoice notification - use admin notification
    await notificationService.showAdminNotification(
      title: message.data['title'] as String? ??
          message.notification?.title ??
          'Nouvelle facture',
      message: message.data['message'] as String? ??
          message.notification?.body ??
          '',
      notificationId:
          int.tryParse(message.data['invoice_id']?.toString() ?? '0') ?? 0,
      type: NotificationType.info,
      payload: message.data,
    );
  } else if (messageType == 'whatsapp_status' ||
      message.data.containsKey('whatsapp_message_id')) {
    // WhatsApp status notification
    await notificationService.showWhatsAppStatusNotification(
      messageId: message.data['whatsapp_message_id'] as String? ??
          message.data['message_id'] as String? ??
          '',
      status: message.data['status'] as String? ?? 'unknown',
      patientName: message.data['patient_name'] as String?,
      appointmentId: message.data['appointment_id'] as String?,
    );
  } else {
    // Generic notification from FCM - check if it's an API notification
    final notificationId = message.data['notification_id'] as String?;
    if (notificationId != null || message.data.containsKey('notification_id')) {
      // This is an API notification, show as generic admin notification
      await notificationService.showAdminNotification(
        title: message.data['title'] as String? ??
            message.notification?.title ??
            'Notification',
        message: message.data['message'] as String? ??
            message.notification?.body ??
            '',
        notificationId: int.tryParse(notificationId ?? '0') ?? 0,
        type: NotificationType.info,
        payload: message.data,
      );
    } else if (message.notification != null) {
      await notificationService.showMessageNotification(
        senderName: message.notification!.title ?? 'Notification',
        message: message.notification!.body ?? '',
        senderId: 0,
        payload: message.data,
      );
    }
  }
}

/// Service for managing Firebase Cloud Messaging
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _fcmToken;

  /// Initialize FCM service
  Future<void> initialize() async {
    try {
      // Check if Firebase is initialized
      try {
        // Try to get token to verify Firebase is available
        await _firebaseMessaging.getToken();
      } catch (e) {
        debugPrint(
          '[FCM] Firebase not configured. FCM push notifications will not work.',
        );
        debugPrint(
          '[FCM] Local notifications will still work when app is in background.',
        );
        debugPrint(
          '[FCM] To enable FCM: Configure google-services.json (see FCM_BACKEND_INTEGRATION.md)',
        );
        return;
      }

      // Request permission for notifications
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        _fcmToken = await _firebaseMessaging.getToken();
        debugPrint('[FCM] FCM Token: $_fcmToken');

        // Save token to backend if needed
        if (_fcmToken != null) {
          await _saveTokenToBackend(_fcmToken!);
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          debugPrint('[FCM] Token refreshed: $newToken');
          _fcmToken = newToken;
          _saveTokenToBackend(newToken);
        });

        // Set up background message handler
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification taps when app is opened from terminated state
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Check if app was opened from a notification
        final initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      }
    } catch (e) {
      debugPrint('[FCM] Error initializing FCM: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message received: ${message.messageId}');
    debugPrint('[FCM] Message data: ${message.data}');

    // Show notification even in foreground
    final notificationService = NotificationService();
    await notificationService.initialize();

    final messageType = message.data['type'] as String?;

    if (messageType == 'message') {
      await notificationService.showMessageNotification(
        senderName: message.data['sender_name'] as String? ??
            message.notification?.title ??
            'Nouveau message',
        message: message.data['message'] as String? ??
            message.notification?.body ??
            '',
        senderId:
            int.tryParse(message.data['sender_id']?.toString() ?? '0') ?? 0,
        messageType: message.data['message_type'] as String?,
        senderAvatar: message.data['sender_avatar'] as String?,
        payload: message.data,
      );
    } else if (messageType == 'emergency') {
      await notificationService.showEmergencyNotification(
        title: message.data['title'] as String? ??
            message.notification?.title ??
            'Alerte',
        message: message.data['message'] as String? ??
            message.notification?.body ??
            '',
        location: message.data['location'] as String? ?? '',
        requesterName: message.data['requester_name'] as String?,
        payload: message.data,
      );
    } else if (messageType == 'appointment' ||
        messageType == 'appointment_created' ||
        messageType == 'appointment_confirmed' ||
        messageType == 'appointment_rejected' ||
        message.data.containsKey('appointment_id')) {
      // Appointment notification
      await notificationService.showAppointmentNotification(
        title: message.data['title'] as String? ??
            message.notification?.title ??
            'Nouveau rendez-vous',
        message: message.data['message'] as String? ??
            message.notification?.body ??
            '',
        appointmentId:
            int.tryParse(message.data['appointment_id']?.toString() ?? '0') ??
                0,
        patientName: message.data['patient_name'] as String?,
        doctorName: message.data['doctor_name'] as String?,
        payload: message.data,
      );
    } else if (messageType == 'prescription' ||
        messageType == 'prescription_ready' ||
        message.data.containsKey('prescription_id')) {
      // Prescription notification
      await notificationService.showPrescriptionReadyNotification(
        patientName: message.data['patient_name'] as String? ?? 'Patient',
        prescriptionId:
            int.tryParse(message.data['prescription_id']?.toString() ?? '0') ??
                0,
        doctorName: message.data['doctor_name'] as String?,
        payload: message.data,
      );
    } else if (messageType == 'invoice' ||
        message.data.containsKey('invoice_id')) {
      // Invoice notification - use admin notification
      await notificationService.showAdminNotification(
        title: message.data['title'] as String? ??
            message.notification?.title ??
            'Nouvelle facture',
        message: message.data['message'] as String? ??
            message.notification?.body ??
            '',
        notificationId:
            int.tryParse(message.data['invoice_id']?.toString() ?? '0') ?? 0,
        type: NotificationType.info,
        payload: message.data,
      );
    } else if (messageType == 'whatsapp_status' ||
        message.data.containsKey('whatsapp_message_id')) {
      // WhatsApp status notification
      await notificationService.showWhatsAppStatusNotification(
        messageId: message.data['whatsapp_message_id'] as String? ??
            message.data['message_id'] as String? ??
            '',
        status: message.data['status'] as String? ?? 'unknown',
        patientName: message.data['patient_name'] as String?,
        appointmentId: message.data['appointment_id'] as String?,
      );
    } else {
      // Generic notification - check if it's an API notification
      final notificationId = message.data['notification_id'] as String?;
      if (notificationId != null ||
          message.data.containsKey('notification_id')) {
        await notificationService.showAdminNotification(
          title: message.data['title'] as String? ??
              message.notification?.title ??
              'Notification',
          message: message.data['message'] as String? ??
              message.notification?.body ??
              '',
          notificationId: int.tryParse(notificationId ?? '0') ?? 0,
          type: NotificationType.info,
          payload: message.data,
        );
      }
    }
  }

  /// Handle notification tap (opens app)
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped, opening app: ${message.messageId}');
    debugPrint('[FCM] Message data: ${message.data}');

    // You can add navigation logic here based on message data
    // For example, navigate to chat screen, etc.
  }

  /// Save FCM token to backend
  /// Note: This method should be called after user login when API client is available
  /// You can call it manually from your login flow or use a callback
  Future<void> _saveTokenToBackend(String token) async {
    try {
      debugPrint('[FCM] Token received: ${token.substring(0, 20)}...');
      debugPrint(
          '[FCM] Note: Token will be saved to backend when user logs in');
      debugPrint(
          '[FCM] Call FCMTokenService.saveToken() after login to save token');

      // Token will be saved when user logs in via FCMTokenService
      // This is done to avoid circular dependencies and ensure API client is available
    } catch (e) {
      debugPrint('[FCM] Error in token handler: $e');
    }
  }

  /// Public method to save token (call this after login)
  Future<void> saveTokenToBackend(String token, ApiClient apiClient) async {
    try {
      await apiClient.post(
        '/fcm-token',
        body: {
          'token': token,
          'device_type': Platform.isAndroid ? 'android' : 'ios',
        },
        requireAuth: true,
      );

      debugPrint('[FCM] Token saved to backend successfully');
    } catch (e) {
      debugPrint('[FCM] Error saving token to backend: $e');
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('[FCM] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error unsubscribing from topic: $e');
    }
  }
}

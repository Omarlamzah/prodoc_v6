// lib/services/notification_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'notification_localization.dart';
import '../screens/appointments_screen.dart';
import '../main.dart';

/// Service for handling WhatsApp-like notifications for chat messages
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _messageNotificationId = 1000;
  int _emergencyNotificationId = 2000;
  int _appointmentNotificationId = 3000;
  int _prescriptionNotificationId = 4000;
  int _adminNotificationId = 5000;
  int _doctorNotificationId = 6000;
  int _patientNotificationId = 7000;
  int _whatsappStatusNotificationId = 8000;

  // Track message count per sender for grouping
  final Map<String, int> _messageCounts = {};
  
  // Track notified WhatsApp statuses to avoid duplicate notifications
  final Map<String, String> _notifiedWhatsAppStatuses = {};

  // Notification channel IDs
  static const String _messageChannelId = 'chat_messages';
  static const String _emergencyChannelId = 'emergency_alerts';
  static const String _appointmentChannelId = 'appointments';
  static const String _prescriptionChannelId = 'prescriptions';
  static const String _adminChannelId = 'admin_alerts';
  static const String _doctorChannelId = 'doctor_alerts';
  static const String _patientChannelId = 'patient_alerts';
  static const String _whatsappStatusChannelId = 'whatsapp_status';

  // Notification channel names
  static const String _messageChannelName = 'Messages';
  static const String _emergencyChannelName = 'Urgences';
  static const String _appointmentChannelName = 'Rendez-vous';
  static const String _prescriptionChannelName = 'Ordonnances';
  static const String _adminChannelName = 'Alertes Admin';
  static const String _doctorChannelName = 'Alertes Médecin';
  static const String _patientChannelName = 'Alertes Patient';
  static const String _whatsappStatusChannelName = 'Statut WhatsApp';

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(
          tz.getLocation('Africa/Casablanca')); // Adjust to your timezone

      // Initialize Android settings
      // Use drawable notification icon (white/transparent for Android 5.0+)
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');

      // Initialize iOS settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Initialize plugin
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels for Android
      if (Platform.isAndroid) {
        await _createAndroidChannels();
      }

      // Request permissions for iOS
      if (Platform.isIOS) {
        await _requestIOSPermissions();
      }

      _initialized = true;
      debugPrint('[NotificationService] Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
      return false;
    }
  }

  /// Create Android notification channels
  Future<void> _createAndroidChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Message channel - High importance (like WhatsApp)
    const AndroidNotificationChannel messageChannel =
        AndroidNotificationChannel(
      _messageChannelId,
      _messageChannelName,
      description: 'Notifications pour les messages de chat',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Emergency channel - Max importance
    const AndroidNotificationChannel emergencyChannel =
        AndroidNotificationChannel(
      _emergencyChannelId,
      _emergencyChannelName,
      description: 'Notifications pour les alertes d\'urgence',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Appointment channel - High importance
    const AndroidNotificationChannel appointmentChannel =
        AndroidNotificationChannel(
      _appointmentChannelId,
      _appointmentChannelName,
      description: 'Notifications pour les rendez-vous',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Prescription channel - High importance
    const AndroidNotificationChannel prescriptionChannel =
        AndroidNotificationChannel(
      _prescriptionChannelId,
      _prescriptionChannelName,
      description: 'Notifications pour les ordonnances',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Admin channel - High importance
    const AndroidNotificationChannel adminChannel = AndroidNotificationChannel(
      _adminChannelId,
      _adminChannelName,
      description: 'Notifications pour les administrateurs',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Doctor channel - High importance
    const AndroidNotificationChannel doctorChannel = AndroidNotificationChannel(
      _doctorChannelId,
      _doctorChannelName,
      description: 'Notifications pour les médecins',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Patient channel - High importance
    const AndroidNotificationChannel patientChannel =
        AndroidNotificationChannel(
      _patientChannelId,
      _patientChannelName,
      description: 'Notifications pour les patients',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // WhatsApp Status channel - High importance (more noticeable)
    const AndroidNotificationChannel whatsappStatusChannel =
        AndroidNotificationChannel(
      _whatsappStatusChannelId,
      _whatsappStatusChannelName,
      description: 'Notifications pour le statut des messages WhatsApp',
      importance: Importance.high, // High importance for better visibility
      playSound: true, // Play sound for notifications
      enableVibration: true, // Enable vibration
      showBadge: true, // Show badge count
    );

    await androidPlugin.createNotificationChannel(messageChannel);
    await androidPlugin.createNotificationChannel(emergencyChannel);
    await androidPlugin.createNotificationChannel(appointmentChannel);
    await androidPlugin.createNotificationChannel(prescriptionChannel);
    await androidPlugin.createNotificationChannel(adminChannel);
    await androidPlugin.createNotificationChannel(doctorChannel);
    await androidPlugin.createNotificationChannel(patientChannel);
    await androidPlugin.createNotificationChannel(whatsappStatusChannel);
  }

  /// Request iOS notification permissions
  Future<void> _requestIOSPermissions() async {
    final iOSImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iOSImplementation != null) {
      await iOSImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
        '[NotificationService] Notification tapped: ${response.payload}');

    // Navigate based on notification type
    _handleNotificationNavigation(response.payload);
  }

  /// Handle navigation when notification is tapped
  void _handleNotificationNavigation(String? payload) {
    if (payload == null || payload.isEmpty) {
      debugPrint('[NotificationService] No payload, cannot navigate');
      return;
    }

    try {
      // Parse payload (format: {type: 'appointment_reminder', appointment_id: 123, ...})
      // The payload is stored as a string representation of the map

      // Check if it's an appointment-related notification
      if (payload.contains('appointment') ||
          payload.contains('appointment_id') ||
          payload.contains('appointment_reminder') ||
          payload.contains('appointment_soon') ||
          payload.contains('appointment_confirmed')) {
        _navigateToAppointmentsScreen();
      } else if (payload.contains('prescription') ||
          payload.contains('prescription_id')) {
        // Could navigate to prescriptions screen in the future
        debugPrint('[NotificationService] Prescription notification tapped');
      } else if (payload.contains('patient_id')) {
        // Could navigate to patient details in the future
        debugPrint('[NotificationService] Patient notification tapped');
      }
    } catch (e) {
      debugPrint(
          '[NotificationService] Error handling notification navigation: $e');
    }
  }

  /// Navigate to appointments screen
  void _navigateToAppointmentsScreen() {
    try {
      // Use global navigator key to navigate from anywhere
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        // Navigate to appointments screen
        navigator.push(
          MaterialPageRoute(
            builder: (_) => const AppointmentsScreen(),
          ),
        );
        debugPrint('[NotificationService] Navigating to appointments screen');
      } else {
        debugPrint(
            '[NotificationService] Navigator not available, cannot navigate');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error navigating to appointments: $e');
    }
  }

  /// Show a WhatsApp-like notification for a chat message
  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required int senderId,
    String? senderAvatar,
    String? messageType,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Increment message count for this sender (for grouping)
      final senderKey = senderId.toString();
      _messageCounts[senderKey] = (_messageCounts[senderKey] ?? 0) + 1;
      final messageCount = _messageCounts[senderKey]!;

      // Truncate long messages (like WhatsApp)
      final truncatedMessage =
          message.length > 100 ? '${message.substring(0, 100)}...' : message;

      // Build notification title and body
      String title;
      String body;

      if (messageCount > 1) {
        // Grouped notification: "Sender Name (2)" when multiple messages
        title = '$senderName ($messageCount)';
        body = truncatedMessage;
      } else {
        // Single message: show sender name and message
        title = senderName;
        body = truncatedMessage;
      }

      // Add message type emoji if present
      final emoji = _getMessageTypeEmoji(messageType);
      if (emoji.isNotEmpty) {
        title = '$emoji $title';
      }

      // Android notification details
      final androidDetails = AndroidNotificationDetails(
        _messageChannelId,
        _messageChannelName,
        channelDescription: 'Notifications pour les messages de chat',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        styleInformation: _buildMessageStyle(senderName, message, messageCount),
        groupKey: 'chat_messages_group',
        setAsGroupSummary: false,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_notification',
        color: const Color(0xFF25D366), // WhatsApp green color
        ledColor: const Color(0xFF25D366),
        ledOnMs: 1000,
        ledOffMs: 500,
        // Large icon from avatar if available (only for local file paths)
        largeIcon: senderAvatar != null && senderAvatar.startsWith('/')
            ? FilePathAndroidBitmap(senderAvatar)
            : null,
      );

      // iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // Uses default iOS notification sound
        badgeNumber: 1,
        threadIdentifier: 'chat_messages',
        categoryIdentifier: 'MESSAGE_CATEGORY',
      );

      // Notification details
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Calculate notification ID (use sender ID to group notifications)
      final notificationId = _messageNotificationId + senderId;

      // Show notification
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload?.toString(),
      );

      // Show summary notification for Android (WhatsApp style grouping)
      if (Platform.isAndroid && messageCount > 1) {
        await _showGroupSummaryNotification();
      }

      debugPrint(
          '[NotificationService] Message notification shown: $senderName - $truncatedMessage');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error showing message notification: $e');
    }
  }

  /// Build message style for Android (conversation-style like WhatsApp)
  StyleInformation _buildMessageStyle(
      String senderName, String message, int messageCount) {
    if (messageCount > 1) {
      // Use inbox style for multiple messages
      return InboxStyleInformation(
        [message],
        htmlFormatLines: false,
        contentTitle: senderName,
        summaryText: '$messageCount messages',
      );
    } else {
      // Use big text style for single message
      return BigTextStyleInformation(
        message,
        htmlFormatBigText: false,
        contentTitle: senderName,
        summaryText: '',
      );
    }
  }

  /// Show group summary notification (Android)
  Future<void> _showGroupSummaryNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _messageChannelId,
        _messageChannelName,
        channelDescription: 'Notifications pour les messages de chat',
        importance: Importance.high,
        priority: Priority.high,
        groupKey: 'chat_messages_group',
        setAsGroupSummary: true,
        enableVibration: false,
        playSound: false,
        icon: '@drawable/ic_notification',
        color: Color(0xFF25D366),
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notifications.show(
        999,
        'Nouveaux messages',
        'Vous avez de nouveaux messages',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing group summary: $e');
    }
  }

  /// Show emergency alert notification
  Future<void> showEmergencyNotification({
    required String title,
    required String message,
    required String location,
    String? requesterName,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final notificationId = _emergencyNotificationId++;
      final body = location.isNotEmpty ? '$message\n📍 $location' : message;

      const androidDetails = AndroidNotificationDetails(
        _emergencyChannelId,
        _emergencyChannelName,
        channelDescription: 'Notifications pour les alertes d\'urgence',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_notification',
        color: Colors.red,
        ledColor: Colors.red,
        ledOnMs: 500,
        ledOffMs: 500,
        styleInformation: BigTextStyleInformation(''),
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // Uses default iOS notification sound
        interruptionLevel: InterruptionLevel.critical,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        notificationId,
        '🚨 $title',
        body,
        notificationDetails,
        payload: payload?.toString(),
      );

      debugPrint('[NotificationService] Emergency notification shown: $title');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error showing emergency notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    await _notifications.cancelAll();
    _messageCounts.clear();
    debugPrint('[NotificationService] All notifications cleared');
  }

  /// Clear notifications for a specific sender
  Future<void> clearSenderNotifications(int senderId) async {
    final notificationId = _messageNotificationId + senderId;
    await _notifications.cancel(notificationId);
    _messageCounts.remove(senderId.toString());
    debugPrint(
        '[NotificationService] Notifications cleared for sender: $senderId');
  }

  /// Cancel a specific notification
  Future<void> cancel(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Get message type emoji
  String _getMessageTypeEmoji(String? messageType) {
    switch (messageType) {
      case 'urgent':
        return '🚨';
      case 'important':
        return '⚠️';
      case 'info':
        return 'ℹ️';
      default:
        return '';
    }
  }

  /// Reset message counts (call when user opens the app)
  void resetMessageCounts() {
    _messageCounts.clear();
  }

  /// Get badge count (total unread messages)
  int getBadgeCount() {
    return _messageCounts.values.fold(0, (sum, count) => sum + count);
  }

  // ==================== APPOINTMENT NOTIFICATIONS ====================

  /// Schedule an appointment reminder notification
  Future<void> scheduleAppointmentReminder({
    required int appointmentId,
    required DateTime appointmentDate,
    required String patientName,
    required String doctorName,
    String? serviceName,
    Duration reminderBefore = const Duration(hours: 1),
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final reminderTime = appointmentDate.subtract(reminderBefore);

      // Don't schedule if reminder time is in the past
      if (reminderTime.isBefore(DateTime.now())) {
        debugPrint(
            '[NotificationService] Reminder time is in the past, skipping');
        return;
      }

      final tzLocation = tz.local;
      final scheduledDate = tz.TZDateTime.from(reminderTime, tzLocation);

      final notificationId = _appointmentNotificationId + appointmentId;

      // Get localized strings
      final strings = await NotificationLocalization.getStrings();
      final title = strings.appointmentReminderTitle;
      final timeStr = _formatTime(appointmentDate);
      final body =
          strings.appointmentReminderBody(doctorName, serviceName, timeStr);

      const androidDetails = AndroidNotificationDetails(
        _appointmentChannelId,
        _appointmentChannelName,
        channelDescription: 'Notifications pour les rendez-vous',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFF1976D2),
        ledColor: Color(0xFF1976D2),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        threadIdentifier: 'appointments',
        categoryIdentifier: 'APPOINTMENT_CATEGORY',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload?.toString(),
      );

      debugPrint(
          '[NotificationService] Appointment reminder scheduled: $appointmentId at $scheduledDate');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error scheduling appointment reminder: $e');
    }
  }

  /// Show immediate appointment notification (new appointment created)
  Future<void> showAppointmentNotification({
    required String title,
    required String message,
    required int appointmentId,
    String? patientName,
    String? doctorName,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final notificationId = _appointmentNotificationId + appointmentId;
      final body = patientName != null && doctorName != null
          ? '$message\n👤 Patient: $patientName\n👨‍⚕️ Médecin: $doctorName'
          : message;

      const androidDetails = AndroidNotificationDetails(
        _appointmentChannelId,
        _appointmentChannelName,
        channelDescription: 'Notifications pour les rendez-vous',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFF1976D2),
        ledColor: Color(0xFF1976D2),
        ledOnMs: 1000,
        ledOffMs: 500,
        styleInformation: BigTextStyleInformation(''),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        threadIdentifier: 'appointments',
        categoryIdentifier: 'APPOINTMENT_CATEGORY',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        notificationId,
        '📅 $title',
        body,
        notificationDetails,
        payload: payload?.toString(),
      );

      debugPrint(
          '[NotificationService] Appointment notification shown: $title');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error showing appointment notification: $e');
    }
  }

  /// Cancel appointment reminder
  Future<void> cancelAppointmentReminder(int appointmentId) async {
    try {
      final notificationId = _appointmentNotificationId + appointmentId;
      await _notifications.cancel(notificationId);
      debugPrint(
          '[NotificationService] Appointment reminder cancelled: $appointmentId');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error cancelling appointment reminder: $e');
    }
  }

  // ==================== PRESCRIPTION NOTIFICATIONS ====================

  /// Show prescription ready notification
  Future<void> showPrescriptionReadyNotification({
    required String patientName,
    required int prescriptionId,
    String? doctorName,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final notificationId = _prescriptionNotificationId + prescriptionId;

      // Get localized strings
      final strings = await NotificationLocalization.getStrings();
      final title = strings.prescriptionReadyTitle;
      final body = strings.prescriptionReadyMessage(doctorName);

      const androidDetails = AndroidNotificationDetails(
        _prescriptionChannelId,
        _prescriptionChannelName,
        channelDescription: 'Notifications pour les ordonnances',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFF4CAF50),
        ledColor: Color(0xFF4CAF50),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        threadIdentifier: 'prescriptions',
        categoryIdentifier: 'PRESCRIPTION_CATEGORY',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload?.toString(),
      );

      debugPrint(
          '[NotificationService] Prescription ready notification shown: $prescriptionId');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error showing prescription notification: $e');
    }
  }

  /// Schedule medication reminder
  Future<void> scheduleMedicationReminder({
    required int reminderId,
    required String medicationName,
    required String dosage,
    required DateTime reminderTime,
    required int prescriptionId,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Don't schedule if reminder time is in the past
      if (reminderTime.isBefore(DateTime.now())) {
        debugPrint(
            '[NotificationService] Reminder time is in the past, skipping');
        return;
      }

      final tzLocation = tz.local;
      final scheduledDate = tz.TZDateTime.from(reminderTime, tzLocation);

      final notificationId = _prescriptionNotificationId + reminderId;

      // Get localized strings
      final strings = await NotificationLocalization.getStrings();
      final title = strings.medicationReminderTitle;
      final body = strings.medicationReminderMessage(medicationName, dosage);

      const androidDetails = AndroidNotificationDetails(
        _prescriptionChannelId,
        _prescriptionChannelName,
        channelDescription: 'Notifications pour les ordonnances',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFF4CAF50),
        ledColor: Color(0xFF4CAF50),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        threadIdentifier: 'prescriptions',
        categoryIdentifier: 'PRESCRIPTION_CATEGORY',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload?.toString(),
      );

      debugPrint(
          '[NotificationService] Medication reminder scheduled: $medicationName at $scheduledDate');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error scheduling medication reminder: $e');
    }
  }

  /// Cancel medication reminder
  Future<void> cancelMedicationReminder(int reminderId) async {
    try {
      final notificationId = _prescriptionNotificationId + reminderId;
      await _notifications.cancel(notificationId);
      debugPrint(
          '[NotificationService] Medication reminder cancelled: $reminderId');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error cancelling medication reminder: $e');
    }
  }

  // ==================== ADMIN NOTIFICATIONS ====================

  /// Show admin notification (system alerts, new registrations, etc.)
  Future<void> showAdminNotification({
    required String title,
    required String message,
    required int notificationId,
    NotificationType type = NotificationType.info,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final id = _adminNotificationId + notificationId;
      final emoji = _getNotificationTypeEmoji(type);
      final finalTitle = '$emoji $title';

      final color = _getNotificationTypeColor(type);

      final androidDetails = AndroidNotificationDetails(
        _adminChannelId,
        _adminChannelName,
        channelDescription: 'Notifications pour les administrateurs',
        importance:
            type == NotificationType.urgent ? Importance.max : Importance.high,
        priority:
            type == NotificationType.urgent ? Priority.max : Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_notification',
        color: color,
        ledColor: color,
        ledOnMs: 1000,
        ledOffMs: 500,
        styleInformation: BigTextStyleInformation(message),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        threadIdentifier: 'admin_alerts',
        categoryIdentifier: 'ADMIN_CATEGORY',
        interruptionLevel: type == NotificationType.urgent
            ? InterruptionLevel.critical
            : InterruptionLevel.active,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id,
        finalTitle,
        message,
        notificationDetails,
        payload: payload?.toString(),
      );

      debugPrint('[NotificationService] Admin notification shown: $title');
    } catch (e) {
      debugPrint('[NotificationService] Error showing admin notification: $e');
    }
  }

  // ==================== DOCTOR NOTIFICATIONS ====================

  /// Show doctor notification (new appointment, patient waiting, etc.)
  Future<void> showDoctorNotification({
    required String title,
    required String message,
    required int notificationId,
    NotificationType type = NotificationType.info,
    String? patientName,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final id = _doctorNotificationId + notificationId;
      final emoji = _getNotificationTypeEmoji(type);
      final finalTitle = '$emoji $title';

      // Get localized strings for patient label
      final strings = await NotificationLocalization.getStrings();
      final body = patientName != null
          ? '$message\n${strings.patientLabel(patientName)}'
          : message;

      final color = _getNotificationTypeColor(type);

      final androidDetails = AndroidNotificationDetails(
        _doctorChannelId,
        _doctorChannelName,
        channelDescription: 'Notifications pour les médecins',
        importance:
            type == NotificationType.urgent ? Importance.max : Importance.high,
        priority:
            type == NotificationType.urgent ? Priority.max : Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_notification',
        color: color,
        ledColor: color,
        ledOnMs: 1000,
        ledOffMs: 500,
        styleInformation: BigTextStyleInformation(body),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        threadIdentifier: 'doctor_alerts',
        categoryIdentifier: 'DOCTOR_CATEGORY',
        interruptionLevel: type == NotificationType.urgent
            ? InterruptionLevel.critical
            : InterruptionLevel.active,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id,
        finalTitle,
        body,
        notificationDetails,
        payload: payload?.toString(),
      );

      debugPrint('[NotificationService] Doctor notification shown: $title');
    } catch (e) {
      debugPrint('[NotificationService] Error showing doctor notification: $e');
    }
  }

  // ==================== PATIENT NOTIFICATIONS ====================

  /// Show patient notification (appointment confirmations, reminders, etc.)
  Future<void> showPatientNotification({
    required String title,
    required String message,
    required int notificationId,
    NotificationType type = NotificationType.info,
    String? doctorName,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final id = _patientNotificationId + notificationId;
      final emoji = _getNotificationTypeEmoji(type);
      final finalTitle = '$emoji $title';

      // Get localized strings for doctor label
      final strings = await NotificationLocalization.getStrings();
      final body = doctorName != null
          ? '$message\n${strings.doctorLabel(doctorName)}'
          : message;

      final color = _getNotificationTypeColor(type);

      final androidDetails = AndroidNotificationDetails(
        _patientChannelId,
        _patientChannelName,
        channelDescription: 'Notifications pour les patients',
        importance:
            type == NotificationType.urgent ? Importance.max : Importance.high,
        priority:
            type == NotificationType.urgent ? Priority.max : Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_notification',
        color: color,
        ledColor: color,
        ledOnMs: 1000,
        ledOffMs: 500,
        styleInformation: BigTextStyleInformation(body),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        threadIdentifier: 'patient_alerts',
        categoryIdentifier: 'PATIENT_CATEGORY',
        interruptionLevel: type == NotificationType.urgent
            ? InterruptionLevel.critical
            : InterruptionLevel.active,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id,
        finalTitle,
        body,
        notificationDetails,
        payload: payload?.toString(),
      );

      debugPrint('[NotificationService] Patient notification shown: $title');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error showing patient notification: $e');
    }
  }

  /// Show WhatsApp status notification
  /// Only shows notification for important status changes (delivered, read, failed)
  Future<void> showWhatsAppStatusNotification({
    required String messageId,
    required String status,
    String? patientName,
    String? appointmentId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Only notify for important status changes
      final importantStatuses = ['delivered', 'read', 'failed'];
      if (!importantStatuses.contains(status.toLowerCase())) {
        return;
      }

      // Check if we've already notified for this status
      final statusKey = '$messageId-$status';
      if (_notifiedWhatsAppStatuses.containsKey(statusKey)) {
        return; // Already notified
      }

      // Mark as notified
      _notifiedWhatsAppStatuses[statusKey] = status;
      
      String title;
      String body;
      Color color;

      switch (status.toLowerCase()) {
        case 'delivered':
          title = '📱 Message WhatsApp livré';
          body = patientName != null
              ? 'Message livré à $patientName'
              : 'Message livré avec succès';
          color = Colors.green;
          break;
        case 'read':
          title = '✅ Message WhatsApp lu';
          body = patientName != null
              ? 'Message lu par $patientName'
              : 'Message lu par le destinataire';
          color = Colors.teal;
          break;
        case 'failed':
          title = '❌ Échec d\'envoi WhatsApp';
          body = 'Le message WhatsApp n\'a pas pu être envoyé';
          color = Colors.red;
          break;
        default:
          return; // Don't notify for other statuses
      }

      final notificationId = _whatsappStatusNotificationId +
          (messageId.hashCode % 1000).abs();

      final androidDetails = AndroidNotificationDetails(
        _whatsappStatusChannelId,
        _whatsappStatusChannelName,
        channelDescription: 'Notifications pour le statut des messages WhatsApp',
        importance: Importance.high, // High importance for better visibility
        priority: Priority.high, // High priority
        showWhen: true,
        enableVibration: true, // Enable vibration
        playSound: true, // Play sound
        icon: '@drawable/ic_notification',
        color: color,
        ledColor: color,
        ledOnMs: 1000,
        ledOffMs: 500,
        styleInformation: BigTextStyleInformation(body),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true, // Show badge
        presentSound: true, // Play sound
        threadIdentifier: 'whatsapp_status',
        categoryIdentifier: 'WHATSAPP_STATUS_CATEGORY',
        interruptionLevel: InterruptionLevel.active, // Active interruption level
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: jsonEncode({
          'type': 'whatsapp_status',
          'message_id': messageId,
          'status': status,
          'appointment_id': appointmentId,
        }),
      );

      debugPrint(
          '[NotificationService] WhatsApp status notification shown: $status for message $messageId');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error showing WhatsApp status notification: $e');
    }
  }

  // ==================== HELPER METHODS ====================

  /// Get notification type emoji
  String _getNotificationTypeEmoji(NotificationType type) {
    switch (type) {
      case NotificationType.urgent:
        return '🚨';
      case NotificationType.warning:
        return '⚠️';
      case NotificationType.success:
        return '✅';
      case NotificationType.info:
        return 'ℹ️';
    }
  }

  /// Get notification type color
  Color _getNotificationTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.urgent:
        return Colors.red;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.success:
        return Colors.green;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  /// Format time for display
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Get all pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Cancel all appointment reminders
  Future<void> cancelAllAppointmentReminders() async {
    try {
      final pending = await getPendingNotifications();
      for (final notification in pending) {
        if (notification.id >= _appointmentNotificationId &&
            notification.id < _prescriptionNotificationId) {
          await _notifications.cancel(notification.id);
        }
      }
      debugPrint('[NotificationService] All appointment reminders cancelled');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error cancelling all appointment reminders: $e');
    }
  }

  /// Cancel all medication reminders
  Future<void> cancelAllMedicationReminders() async {
    try {
      final pending = await getPendingNotifications();
      for (final notification in pending) {
        if (notification.id >= _prescriptionNotificationId &&
            notification.id < _adminNotificationId) {
          await _notifications.cancel(notification.id);
        }
      }
      debugPrint('[NotificationService] All medication reminders cancelled');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error cancelling all medication reminders: $e');
    }
  }
}

/// Notification types for different priority levels
enum NotificationType {
  info,
  success,
  warning,
  urgent,
}

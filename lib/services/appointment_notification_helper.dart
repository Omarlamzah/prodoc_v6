// lib/services/appointment_notification_helper.dart
// Helper class to schedule appointment reminders automatically

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/models/appointment_model.dart';
import '../data/models/appointment_response_model.dart';
import 'notification_service.dart';
import 'notification_localization.dart';

/// Helper class to handle appointment notification scheduling
class AppointmentNotificationHelper {
  final NotificationService _notificationService = NotificationService();

  /// Schedule appointment reminder 1 hour before the appointment
  /// This should be called after successfully creating an appointment
  Future<void> scheduleAppointmentReminder({
    required AppointmentModel appointment,
    Duration reminderBefore = const Duration(hours: 1),
  }) async {
    try {
      // Ensure notification service is initialized
      await _notificationService.initialize();

      // Validate appointment data
      if (appointment.id == null) {
        debugPrint(
            '[AppointmentNotificationHelper] Appointment ID is null, cannot schedule reminder');
        return;
      }

      if (appointment.appointmentDate == null ||
          appointment.appointmentTime == null) {
        debugPrint(
            '[AppointmentNotificationHelper] Appointment date or time is null');
        return;
      }

      // Parse appointment date and time
      final appointmentDateTime = _parseAppointmentDateTime(
        appointment.appointmentDate!,
        appointment.appointmentTime!,
      );

      if (appointmentDateTime == null) {
        debugPrint(
            '[AppointmentNotificationHelper] Failed to parse appointment date/time');
        return;
      }

      // Check if appointment is in the future
      if (appointmentDateTime.isBefore(DateTime.now())) {
        debugPrint(
            '[AppointmentNotificationHelper] Appointment is in the past, skipping reminder');
        return;
      }

      // Calculate reminder time (1 hour before by default)
      final reminderTime = appointmentDateTime.subtract(reminderBefore);

      // Check if reminder time is in the past
      if (reminderTime.isBefore(DateTime.now())) {
        debugPrint(
            '[AppointmentNotificationHelper] Reminder time is in the past, skipping');
        return;
      }

      // Get patient and doctor names
      final patientName = appointment.patient?.user?.name ?? 'Patient';
      final doctorName = appointment.doctor?.user?.name ?? 'Médecin';
      final serviceName = appointment.service?.title;

      // Schedule the reminder
      await _notificationService.scheduleAppointmentReminder(
        appointmentId: appointment.id!,
        appointmentDate: appointmentDateTime,
        patientName: patientName,
        doctorName: doctorName,
        serviceName: serviceName,
        reminderBefore: reminderBefore,
        payload: {
          'type': 'appointment_reminder',
          'appointment_id': appointment.id,
          'appointment_date': appointment.appointmentDate,
          'appointment_time': appointment.appointmentTime,
          'action': 'view_appointment',
        },
      );

      debugPrint(
        '[AppointmentNotificationHelper] Reminder scheduled for appointment #${appointment.id} '
        'at ${DateFormat('yyyy-MM-dd HH:mm').format(reminderTime)} '
        '(1 hour before appointment at ${DateFormat('yyyy-MM-dd HH:mm').format(appointmentDateTime)})',
      );
    } catch (e) {
      debugPrint(
          '[AppointmentNotificationHelper] Error scheduling reminder: $e');
    }
  }

  /// Parse appointment date and time strings into DateTime
  DateTime? _parseAppointmentDateTime(String dateStr, String timeStr) {
    try {
      // Parse date (format: yyyy-MM-dd)
      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) {
        debugPrint(
            '[AppointmentNotificationHelper] Invalid date format: $dateStr');
        return null;
      }

      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      // Parse time (format: HH:mm or HH:mm:ss)
      final timeParts = timeStr.split(':');
      if (timeParts.length < 2) {
        debugPrint(
            '[AppointmentNotificationHelper] Invalid time format: $timeStr');
        return null;
      }

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      debugPrint('[AppointmentNotificationHelper] Error parsing date/time: $e');
      return null;
    }
  }

  /// Handle appointment creation success - schedule reminder automatically
  /// Call this method after successfully creating an appointment
  Future<void> handleAppointmentCreated(
      AppointmentResponseModel response) async {
    await scheduleAppointmentReminder(appointment: response.appointment);
  }

  /// Cancel appointment reminder when appointment is cancelled
  Future<void> cancelAppointmentReminder(int appointmentId) async {
    try {
      await _notificationService.cancelAppointmentReminder(appointmentId);
      debugPrint(
          '[AppointmentNotificationHelper] Cancelled reminder for appointment #$appointmentId');
    } catch (e) {
      debugPrint(
          '[AppointmentNotificationHelper] Error cancelling reminder: $e');
    }
  }

  /// Notify doctor about new appointment
  Future<void> notifyDoctorNewAppointment(AppointmentModel appointment) async {
    try {
      await _notificationService.initialize();

      if (appointment.id == null) return;

      final patientName = appointment.patient?.user?.name ?? 'Patient';

      // Get localized strings
      final strings = await NotificationLocalization.getStrings();

      await _notificationService.showDoctorNotification(
        title: strings.newAppointmentTitle,
        message: strings.newAppointmentMessage,
        notificationId: appointment.id!,
        type: NotificationType.info,
        patientName: patientName,
        payload: {
          'type': 'new_appointment',
          'appointment_id': appointment.id,
          'action': 'view_appointment',
        },
      );
    } catch (e) {
      debugPrint('[AppointmentNotificationHelper] Error notifying doctor: $e');
    }
  }

  /// Notify patient about appointment confirmation
  Future<void> notifyPatientAppointmentConfirmed(
      AppointmentModel appointment) async {
    try {
      await _notificationService.initialize();

      if (appointment.id == null) return;

      final doctorName = appointment.doctor?.user?.name ?? 'Médecin';

      // Get localized strings
      final strings = await NotificationLocalization.getStrings();

      await _notificationService.showPatientNotification(
        title: strings.appointmentConfirmedTitle,
        message: strings.appointmentConfirmedMessage,
        notificationId: appointment.id!,
        type: NotificationType.success,
        doctorName: doctorName,
        payload: {
          'type': 'appointment_confirmed',
          'appointment_id': appointment.id,
          'action': 'view_appointment',
        },
      );
    } catch (e) {
      debugPrint('[AppointmentNotificationHelper] Error notifying patient: $e');
    }
  }

  /// Notify patient that appointment is soon (less than 1 hour away)
  Future<void> notifyPatientAppointmentSoon(
      AppointmentModel appointment) async {
    try {
      await _notificationService.initialize();

      if (appointment.id == null ||
          appointment.appointmentDate == null ||
          appointment.appointmentTime == null) {
        return;
      }

      final appointmentDateTime = _parseAppointmentDateTime(
        appointment.appointmentDate!,
        appointment.appointmentTime!,
      );

      if (appointmentDateTime == null) return;

      final doctorName = appointment.doctor?.user?.name ?? 'Médecin';
      final serviceName = appointment.service?.title;
      final timeUntil = appointmentDateTime.difference(DateTime.now());
      final minutesUntil = timeUntil.inMinutes;

      // Get localized strings
      final strings = await NotificationLocalization.getStrings();
      final message = strings.appointmentSoonMessage(minutesUntil);
      final timeStr = DateFormat('HH:mm').format(appointmentDateTime);
      final details =
          strings.appointmentSoonDetails(doctorName, serviceName, timeStr);
      final fullMessage = '$message\n$details';

      await _notificationService.showPatientNotification(
        title: strings.appointmentSoonTitle,
        message: fullMessage,
        notificationId: appointment.id!,
        type: NotificationType.urgent,
        doctorName: doctorName,
        payload: {
          'type': 'appointment_soon',
          'appointment_id': appointment.id,
          'appointment_date': appointment.appointmentDate,
          'appointment_time': appointment.appointmentTime,
          'action': 'view_appointment',
        },
      );

      debugPrint(
        '[AppointmentNotificationHelper] Immediate notification shown for appointment #${appointment.id} (${minutesUntil} minutes away)',
      );
    } catch (e) {
      debugPrint(
          '[AppointmentNotificationHelper] Error showing immediate notification: $e');
    }
  }
}

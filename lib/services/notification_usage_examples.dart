// lib/services/notification_usage_examples.dart
// This file contains examples of how to use the enhanced NotificationService
// for doctors, admins, and patients in your healthcare management app.

import 'package:flutter/material.dart';
import 'notification_service.dart';

/// Example usage of NotificationService for different user roles
class NotificationUsageExamples {
  final NotificationService _notificationService = NotificationService();

  // ==================== APPOINTMENT NOTIFICATIONS ====================

  /// Example: Schedule appointment reminder for a patient
  Future<void> schedulePatientAppointmentReminder({
    required int appointmentId,
    required DateTime appointmentDate,
    required String patientName,
    required String doctorName,
    String? serviceName,
  }) async {
    // Schedule reminder 1 hour before appointment
    await _notificationService.scheduleAppointmentReminder(
      appointmentId: appointmentId,
      appointmentDate: appointmentDate,
      patientName: patientName,
      doctorName: doctorName,
      serviceName: serviceName,
      reminderBefore: const Duration(hours: 1),
      payload: {
        'type': 'appointment_reminder',
        'appointment_id': appointmentId,
        'action': 'view_appointment',
      },
    );
  }

  /// Example: Notify doctor when new appointment is created
  Future<void> notifyDoctorNewAppointment({
    required int appointmentId,
    required String patientName,
    required DateTime appointmentDate,
  }) async {
    await _notificationService.showDoctorNotification(
      title: 'Nouveau rendez-vous',
      message: 'Un nouveau rendez-vous a été réservé',
      notificationId: appointmentId,
      type: NotificationType.info,
      patientName: patientName,
      payload: {
        'type': 'new_appointment',
        'appointment_id': appointmentId,
        'action': 'view_appointment',
      },
    );
  }

  /// Example: Notify patient when appointment is confirmed
  Future<void> notifyPatientAppointmentConfirmed({
    required int appointmentId,
    required String doctorName,
    required DateTime appointmentDate,
  }) async {
    await _notificationService.showPatientNotification(
      title: 'Rendez-vous confirmé',
      message: 'Votre rendez-vous a été confirmé',
      notificationId: appointmentId,
      type: NotificationType.success,
      doctorName: doctorName,
      payload: {
        'type': 'appointment_confirmed',
        'appointment_id': appointmentId,
        'action': 'view_appointment',
      },
    );
  }

  /// Example: Notify when appointment is cancelled
  Future<void> notifyAppointmentCancelled({
    required int appointmentId,
    required String patientName,
    required String doctorName,
    bool isPatient = true,
  }) async {
    if (isPatient) {
      await _notificationService.showPatientNotification(
        title: 'Rendez-vous annulé',
        message: 'Votre rendez-vous a été annulé',
        notificationId: appointmentId,
        type: NotificationType.warning,
        doctorName: doctorName,
        payload: {
          'type': 'appointment_cancelled',
          'appointment_id': appointmentId,
        },
      );
    } else {
      await _notificationService.showDoctorNotification(
        title: 'Rendez-vous annulé',
        message: 'Un rendez-vous a été annulé',
        notificationId: appointmentId,
        type: NotificationType.warning,
        patientName: patientName,
        payload: {
          'type': 'appointment_cancelled',
          'appointment_id': appointmentId,
        },
      );
    }
  }

  // ==================== PRESCRIPTION NOTIFICATIONS ====================

  /// Example: Notify patient when prescription is ready
  Future<void> notifyPrescriptionReady({
    required int prescriptionId,
    required String patientName,
    required String doctorName,
  }) async {
    await _notificationService.showPrescriptionReadyNotification(
      patientName: patientName,
      prescriptionId: prescriptionId,
      doctorName: doctorName,
      payload: {
        'type': 'prescription_ready',
        'prescription_id': prescriptionId,
        'action': 'view_prescription',
      },
    );
  }

  /// Example: Schedule medication reminder for patient
  Future<void> scheduleMedicationReminder({
    required int reminderId,
    required String medicationName,
    required String dosage,
    required DateTime reminderTime,
    required int prescriptionId,
  }) async {
    await _notificationService.scheduleMedicationReminder(
      reminderId: reminderId,
      medicationName: medicationName,
      dosage: dosage,
      reminderTime: reminderTime,
      prescriptionId: prescriptionId,
      payload: {
        'type': 'medication_reminder',
        'prescription_id': prescriptionId,
        'medication': medicationName,
        'action': 'view_prescription',
      },
    );
  }

  // ==================== ADMIN NOTIFICATIONS ====================

  /// Example: Notify admin about new user registration
  Future<void> notifyAdminNewUser({
    required int userId,
    required String userName,
    required String userRole,
  }) async {
    await _notificationService.showAdminNotification(
      title: 'Nouvel utilisateur enregistré',
      message: '$userName ($userRole) s\'est inscrit',
      notificationId: userId,
      type: NotificationType.info,
      payload: {
        'type': 'new_user',
        'user_id': userId,
        'action': 'view_user',
      },
    );
  }

  /// Example: Notify admin about system alert
  Future<void> notifyAdminSystemAlert({
    required String title,
    required String message,
    required int alertId,
    bool isUrgent = false,
  }) async {
    await _notificationService.showAdminNotification(
      title: title,
      message: message,
      notificationId: alertId,
      type: isUrgent ? NotificationType.urgent : NotificationType.warning,
      payload: {
        'type': 'system_alert',
        'alert_id': alertId,
        'action': 'view_alert',
      },
    );
  }

  // ==================== DOCTOR NOTIFICATIONS ====================

  /// Example: Notify doctor when patient is waiting
  Future<void> notifyDoctorPatientWaiting({
    required int patientId,
    required String patientName,
    required String waitingRoom,
  }) async {
    await _notificationService.showDoctorNotification(
      title: 'Patient en attente',
      message: 'Un patient vous attend dans $waitingRoom',
      notificationId: patientId,
      type: NotificationType.info,
      patientName: patientName,
      payload: {
        'type': 'patient_waiting',
        'patient_id': patientId,
        'action': 'view_waiting_room',
      },
    );
  }

  /// Example: Notify doctor about urgent patient request
  Future<void> notifyDoctorUrgentRequest({
    required int requestId,
    required String patientName,
    required String requestType,
  }) async {
    await _notificationService.showDoctorNotification(
      title: 'Demande urgente',
      message: 'Demande urgente: $requestType',
      notificationId: requestId,
      type: NotificationType.urgent,
      patientName: patientName,
      payload: {
        'type': 'urgent_request',
        'request_id': requestId,
        'action': 'view_request',
      },
    );
  }

  // ==================== PATIENT NOTIFICATIONS ====================

  /// Example: Notify patient about appointment reminder (immediate)
  Future<void> notifyPatientAppointmentReminder({
    required int appointmentId,
    required String doctorName,
    required DateTime appointmentDate,
  }) async {
    await _notificationService.showPatientNotification(
      title: 'Rappel de rendez-vous',
      message: 'Vous avez un rendez-vous aujourd\'hui',
      notificationId: appointmentId,
      type: NotificationType.info,
      doctorName: doctorName,
      payload: {
        'type': 'appointment_reminder',
        'appointment_id': appointmentId,
        'action': 'view_appointment',
      },
    );
  }

  /// Example: Notify patient about follow-up reminder
  Future<void> notifyPatientFollowUp({
    required int followUpId,
    required String doctorName,
    required DateTime followUpDate,
  }) async {
    await _notificationService.showPatientNotification(
      title: 'Rappel de suivi',
      message: 'N\'oubliez pas votre rendez-vous de suivi',
      notificationId: followUpId,
      type: NotificationType.info,
      doctorName: doctorName,
      payload: {
        'type': 'follow_up',
        'follow_up_id': followUpId,
        'action': 'view_follow_up',
      },
    );
  }

  // ==================== INTEGRATION EXAMPLES ====================

  /// Example: Complete workflow when creating an appointment
  Future<void> handleAppointmentCreated({
    required int appointmentId,
    required DateTime appointmentDate,
    required String patientName,
    required String doctorName,
    required bool isDoctor,
    required bool isPatient,
    String? serviceName,
  }) async {
    // Initialize notification service
    await _notificationService.initialize();

    // Notify doctor about new appointment
    if (isDoctor) {
      await notifyDoctorNewAppointment(
        appointmentId: appointmentId,
        patientName: patientName,
        appointmentDate: appointmentDate,
      );
    }

    // Notify patient and schedule reminder
    if (isPatient) {
      await notifyPatientAppointmentConfirmed(
        appointmentId: appointmentId,
        doctorName: doctorName,
        appointmentDate: appointmentDate,
      );

      // Schedule reminder 1 hour before
      await schedulePatientAppointmentReminder(
        appointmentId: appointmentId,
        appointmentDate: appointmentDate,
        patientName: patientName,
        doctorName: doctorName,
        serviceName: serviceName,
      );
    }
  }

  /// Example: Complete workflow when creating a prescription
  Future<void> handlePrescriptionCreated({
    required int prescriptionId,
    required String patientName,
    required String doctorName,
    required List<Map<String, dynamic>> medications,
  }) async {
    // Initialize notification service
    await _notificationService.initialize();

    // Notify patient that prescription is ready
    await notifyPrescriptionReady(
      prescriptionId: prescriptionId,
      patientName: patientName,
      doctorName: doctorName,
    );

    // Schedule medication reminders for each medication
    // This is a simplified example - you would calculate actual reminder times
    // based on medication frequency and duration
    for (int i = 0; i < medications.length; i++) {
      final medication = medications[i];
      final medicationName = medication['name'] as String? ?? 'Médicament';
      final dosage = medication['dosage'] as String? ?? '';

      // Example: Schedule reminder for tomorrow at 8 AM
      final reminderTime = DateTime.now().add(const Duration(days: 1));
      final reminderDateTime = DateTime(
        reminderTime.year,
        reminderTime.month,
        reminderTime.day,
        8, // 8 AM
      );

      await scheduleMedicationReminder(
        reminderId: prescriptionId * 100 + i, // Unique ID
        medicationName: medicationName,
        dosage: dosage,
        reminderTime: reminderDateTime,
        prescriptionId: prescriptionId,
      );
    }
  }

  /// Example: Cancel all appointment reminders when appointment is cancelled
  Future<void> handleAppointmentCancelled(int appointmentId) async {
    await _notificationService.cancelAppointmentReminder(appointmentId);
  }

  /// Example: Cancel all medication reminders when prescription is updated
  Future<void> handlePrescriptionUpdated(int prescriptionId) async {
    // You would need to track reminder IDs, but this is a simplified example
    // In practice, you'd cancel specific reminder IDs
    await _notificationService.cancelAllMedicationReminders();
  }
}

/// Helper class to handle notification tap navigation
class NotificationNavigationHandler {
  /// Handle notification tap based on payload
  static void handleNotificationTap(
    BuildContext context,
    String? payload,
  ) {
    if (payload == null) return;

    try {
      // Parse payload (in real app, you'd use proper JSON parsing)
      // This is a simplified example
      if (payload.contains('appointment_id')) {
        // Navigate to appointment details
        // Navigator.pushNamed(context, '/appointment', arguments: {...});
      } else if (payload.contains('prescription_id')) {
        // Navigate to prescription details
        // Navigator.pushNamed(context, '/prescription', arguments: {...});
      } else if (payload.contains('patient_id')) {
        // Navigate to patient details
        // Navigator.pushNamed(context, '/patient', arguments: {...});
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }
}

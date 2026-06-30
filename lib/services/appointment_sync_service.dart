// lib/services/appointment_sync_service.dart
// Service to sync appointments from website and schedule local notification reminders

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/appointment_model.dart';
import 'appointment_notification_helper.dart';

/// Service to sync appointments and schedule reminders for appointments
/// created on the website
class AppointmentSyncService {
  static const String _prefsKey = 'appointments_with_reminders';
  static const String _notifiedKey = 'appointments_notified_immediate';
  final AppointmentNotificationHelper _helper = AppointmentNotificationHelper();

  /// Sync appointments and schedule reminders for new ones
  /// Call this when appointments are fetched from the API
  Future<void> syncAppointments(List<AppointmentModel> appointments) async {
    try {
      // Get list of appointment IDs that already have reminders scheduled
      final scheduledIds = await _getScheduledAppointmentIds();

      // Get list of appointments that have been immediately notified
      final notifiedIds = await _getNotifiedAppointmentIds();

      // Separate appointments into two groups:
      // 1. Less than 1 hour away - show immediate notification
      // 2. More than 1 hour away - schedule reminder
      final appointmentsForImmediateNotification = <AppointmentModel>[];
      final appointmentsToSchedule = <AppointmentModel>[];

      for (final appointment in appointments) {
        // Only process future appointments
        if (appointment.appointmentDate == null ||
            appointment.appointmentTime == null ||
            appointment.id == null) {
          continue;
        }

        // Check if appointment is in the future
        final appointmentDateTime = _parseAppointmentDateTime(
          appointment.appointmentDate!,
          appointment.appointmentTime!,
        );

        if (appointmentDateTime == null ||
            appointmentDateTime.isBefore(DateTime.now())) {
          continue;
        }

        // Calculate time until appointment
        final timeUntilAppointment =
            appointmentDateTime.difference(DateTime.now());

        // If less than 1 hour away and not already notified, show immediate notification
        if (timeUntilAppointment.inHours < 1 &&
            timeUntilAppointment.inMinutes > 0 &&
            !notifiedIds.contains(appointment.id)) {
          appointmentsForImmediateNotification.add(appointment);
        }
        // If more than 1 hour away and reminder not scheduled, schedule reminder
        else if (timeUntilAppointment.inHours >= 1 &&
            !scheduledIds.contains(appointment.id)) {
          appointmentsToSchedule.add(appointment);
        }
      }

      // Show immediate notifications for appointments less than 1 hour away
      if (appointmentsForImmediateNotification.isNotEmpty) {
        debugPrint(
          '[AppointmentSyncService] Showing immediate notifications for ${appointmentsForImmediateNotification.length} appointments (less than 1 hour away)',
        );

        final newlyNotifiedIds = <int>[];
        for (final appointment in appointmentsForImmediateNotification) {
          try {
            // Show immediate notification
            await _helper.notifyPatientAppointmentSoon(appointment);
            newlyNotifiedIds.add(appointment.id!);
          } catch (e) {
            debugPrint(
              '[AppointmentSyncService] Error showing immediate notification for appointment ${appointment.id}: $e',
            );
          }
        }

        // Save notified appointment IDs
        if (newlyNotifiedIds.isNotEmpty) {
          notifiedIds.addAll(newlyNotifiedIds);
          await _saveNotifiedAppointmentIds(notifiedIds);
        }
      }

      // Schedule reminders for appointments more than 1 hour away
      if (appointmentsToSchedule.isNotEmpty) {
        debugPrint(
          '[AppointmentSyncService] Scheduling reminders for ${appointmentsToSchedule.length} appointments',
        );

        // Schedule reminders for each appointment
        final newlyScheduledIds = <int>[];
        for (final appointment in appointmentsToSchedule) {
          try {
            await _helper.scheduleAppointmentReminder(
              appointment: appointment,
              reminderBefore: const Duration(hours: 1),
            );
            newlyScheduledIds.add(appointment.id!);
          } catch (e) {
            debugPrint(
              '[AppointmentSyncService] Error scheduling reminder for appointment ${appointment.id}: $e',
            );
          }
        }

        // Save newly scheduled appointment IDs
        if (newlyScheduledIds.isNotEmpty) {
          scheduledIds.addAll(newlyScheduledIds);
          await _saveScheduledAppointmentIds(scheduledIds);
          debugPrint(
            '[AppointmentSyncService] Successfully scheduled ${newlyScheduledIds.length} reminders',
          );
        }
      }

      if (appointmentsForImmediateNotification.isEmpty &&
          appointmentsToSchedule.isEmpty) {
        debugPrint('[AppointmentSyncService] No new appointments to process');
      }
    } catch (e) {
      debugPrint('[AppointmentSyncService] Error syncing appointments: $e');
    }
  }

  /// Parse appointment date and time strings into DateTime
  DateTime? _parseAppointmentDateTime(String dateStr, String timeStr) {
    try {
      // Parse date (format: yyyy-MM-dd)
      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) {
        return null;
      }

      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      // Parse time (format: HH:mm or HH:mm:ss)
      final timeParts = timeStr.split(':');
      if (timeParts.length < 2) {
        return null;
      }

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      debugPrint('[AppointmentSyncService] Error parsing date/time: $e');
      return null;
    }
  }

  /// Get list of appointment IDs that already have reminders scheduled
  Future<Set<int>> _getScheduledAppointmentIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsString = prefs.getString(_prefsKey);
      if (idsString == null || idsString.isEmpty) {
        return <int>{};
      }

      final ids = idsString
          .split(',')
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .toSet();
      return ids;
    } catch (e) {
      debugPrint('[AppointmentSyncService] Error getting scheduled IDs: $e');
      return <int>{};
    }
  }

  /// Save list of appointment IDs that have reminders scheduled
  Future<void> _saveScheduledAppointmentIds(Set<int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsString = ids.join(',');
      await prefs.setString(_prefsKey, idsString);
    } catch (e) {
      debugPrint('[AppointmentSyncService] Error saving scheduled IDs: $e');
    }
  }

  /// Remove appointment ID from scheduled list (when appointment is cancelled)
  Future<void> removeScheduledAppointment(int appointmentId) async {
    try {
      final scheduledIds = await _getScheduledAppointmentIds();
      scheduledIds.remove(appointmentId);
      await _saveScheduledAppointmentIds(scheduledIds);

      // Also cancel the notification
      await _helper.cancelAppointmentReminder(appointmentId);

      debugPrint(
          '[AppointmentSyncService] Removed appointment $appointmentId from scheduled reminders');
    } catch (e) {
      debugPrint(
          '[AppointmentSyncService] Error removing scheduled appointment: $e');
    }
  }

  /// Clear all scheduled appointment reminders (useful for logout or reset)
  Future<void> clearAllScheduledAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      debugPrint(
          '[AppointmentSyncService] Cleared all scheduled appointment reminders');
    } catch (e) {
      debugPrint(
          '[AppointmentSyncService] Error clearing scheduled appointments: $e');
    }
  }

  /// Get count of scheduled reminders
  Future<int> getScheduledRemindersCount() async {
    final ids = await _getScheduledAppointmentIds();
    return ids.length;
  }

  /// Get list of appointment IDs that have been immediately notified
  Future<Set<int>> _getNotifiedAppointmentIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsString = prefs.getString(_notifiedKey);
      if (idsString == null || idsString.isEmpty) {
        return <int>{};
      }

      final ids = idsString
          .split(',')
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .toSet();
      return ids;
    } catch (e) {
      debugPrint('[AppointmentSyncService] Error getting notified IDs: $e');
      return <int>{};
    }
  }

  /// Save list of appointment IDs that have been immediately notified
  Future<void> _saveNotifiedAppointmentIds(Set<int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsString = ids.join(',');
      await prefs.setString(_notifiedKey, idsString);
    } catch (e) {
      debugPrint('[AppointmentSyncService] Error saving notified IDs: $e');
    }
  }
}

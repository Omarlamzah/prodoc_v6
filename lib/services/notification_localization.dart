// lib/services/notification_localization.dart
// Localization helper for notifications (works without BuildContext)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Localization helper for notifications
/// Works without BuildContext by reading locale from SharedPreferences
class NotificationLocalization {
  static const String _localeKey = 'selected_locale';

  /// Get current locale from SharedPreferences
  static Future<Locale> getCurrentLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeString = prefs.getString(_localeKey);

      if (localeString != null) {
        final parts = localeString.split('_');
        if (parts.length >= 1) {
          final languageCode = parts[0];

          if (languageCode == 'ar') {
            return const Locale('ar', 'SA');
          } else if (languageCode == 'fr') {
            return const Locale('fr', 'FR');
          } else {
            return const Locale('en', 'US');
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationLocalization] Error getting locale: $e');
    }

    // Default to French
    return const Locale('fr', 'FR');
  }

  /// Get localized notification strings
  static Future<NotificationStrings> getStrings() async {
    final locale = await getCurrentLocale();
    return NotificationStrings(locale);
  }
}

/// Localized notification strings
class NotificationStrings {
  final Locale locale;

  NotificationStrings(this.locale);

  // Appointment notifications
  String get appointmentReminderTitle {
    switch (locale.languageCode) {
      case 'ar':
        return '📅 تذكير بالموعد';
      case 'fr':
        return '📅 Rappel de rendez-vous';
      case 'en':
      default:
        return '📅 Appointment Reminder';
    }
  }

  String appointmentReminderBody(
      String doctorName, String? serviceName, String time) {
    switch (locale.languageCode) {
      case 'ar':
        if (serviceName != null) {
          return 'موعد مع د. $doctorName ($serviceName) في $time';
        }
        return 'موعد مع د. $doctorName في $time';
      case 'fr':
        if (serviceName != null) {
          return 'Rendez-vous avec Dr. $doctorName ($serviceName) à $time';
        }
        return 'Rendez-vous avec Dr. $doctorName à $time';
      case 'en':
      default:
        if (serviceName != null) {
          return 'Appointment with Dr. $doctorName ($serviceName) at $time';
        }
        return 'Appointment with Dr. $doctorName at $time';
    }
  }

  String get appointmentSoonTitle {
    switch (locale.languageCode) {
      case 'ar':
        return '⏰ موعد قريب';
      case 'fr':
        return '⏰ Rendez-vous bientôt';
      case 'en':
      default:
        return '⏰ Appointment Soon';
    }
  }

  String appointmentSoonMessage(int minutes) {
    switch (locale.languageCode) {
      case 'ar':
        if (minutes < 15) {
          return 'موعدك خلال $minutes دقيقة!';
        }
        return 'موعدك خلال أقل من ساعة';
      case 'fr':
        if (minutes < 15) {
          return 'Votre rendez-vous est dans $minutes minutes!';
        }
        return 'Votre rendez-vous est dans moins d\'une heure';
      case 'en':
      default:
        if (minutes < 15) {
          return 'Your appointment is in $minutes minutes!';
        }
        return 'Your appointment is in less than an hour';
    }
  }

  String appointmentSoonDetails(
      String doctorName, String? serviceName, String time) {
    switch (locale.languageCode) {
      case 'ar':
        if (serviceName != null) {
          return '👨‍⚕️ د. $doctorName ($serviceName) في $time';
        }
        return '👨‍⚕️ د. $doctorName في $time';
      case 'fr':
        if (serviceName != null) {
          return '👨‍⚕️ Dr. $doctorName ($serviceName) à $time';
        }
        return '👨‍⚕️ Dr. $doctorName à $time';
      case 'en':
      default:
        if (serviceName != null) {
          return '👨‍⚕️ Dr. $doctorName ($serviceName) at $time';
        }
        return '👨‍⚕️ Dr. $doctorName at $time';
    }
  }

  String get appointmentConfirmedTitle {
    switch (locale.languageCode) {
      case 'ar':
        return '✅ تم تأكيد الموعد';
      case 'fr':
        return '✅ Rendez-vous confirmé';
      case 'en':
      default:
        return '✅ Appointment Confirmed';
    }
  }

  String get appointmentConfirmedMessage {
    switch (locale.languageCode) {
      case 'ar':
        return 'تم تأكيد موعدك بنجاح';
      case 'fr':
        return 'Votre rendez-vous a été confirmé avec succès';
      case 'en':
      default:
        return 'Your appointment has been confirmed successfully';
    }
  }

  String doctorLabel(String doctorName) {
    switch (locale.languageCode) {
      case 'ar':
        return '👨‍⚕️ طبيب: $doctorName';
      case 'fr':
        return '👨‍⚕️ Médecin: $doctorName';
      case 'en':
      default:
        return '👨‍⚕️ Doctor: $doctorName';
    }
  }

  // Prescription notifications
  String get prescriptionReadyTitle {
    switch (locale.languageCode) {
      case 'ar':
        return '💊 الوصفة جاهزة';
      case 'fr':
        return '💊 Ordonnance prête';
      case 'en':
      default:
        return '💊 Prescription Ready';
    }
  }

  String prescriptionReadyMessage(String? doctorName) {
    switch (locale.languageCode) {
      case 'ar':
        if (doctorName != null) {
          return 'وصفتك من د. $doctorName جاهزة';
        }
        return 'وصفتك جاهزة';
      case 'fr':
        if (doctorName != null) {
          return 'Votre ordonnance de Dr. $doctorName est prête';
        }
        return 'Votre ordonnance est prête';
      case 'en':
      default:
        if (doctorName != null) {
          return 'Your prescription from Dr. $doctorName is ready';
        }
        return 'Your prescription is ready';
    }
  }

  String get medicationReminderTitle {
    switch (locale.languageCode) {
      case 'ar':
        return '💊 تذكير بالدواء';
      case 'fr':
        return '💊 Rappel de médicament';
      case 'en':
      default:
        return '💊 Medication Reminder';
    }
  }

  String medicationReminderMessage(String medicationName, String dosage) {
    switch (locale.languageCode) {
      case 'ar':
        return 'حان وقت تناول: $medicationName ($dosage)';
      case 'fr':
        return 'Il est temps de prendre: $medicationName ($dosage)';
      case 'en':
      default:
        return 'Time to take: $medicationName ($dosage)';
    }
  }

  // Doctor notifications
  String get newAppointmentTitle {
    switch (locale.languageCode) {
      case 'ar':
        return '📅 موعد جديد';
      case 'fr':
        return '📅 Nouveau rendez-vous';
      case 'en':
      default:
        return '📅 New Appointment';
    }
  }

  String get newAppointmentMessage {
    switch (locale.languageCode) {
      case 'ar':
        return 'تم حجز موعد جديد';
      case 'fr':
        return 'Un nouveau rendez-vous a été réservé';
      case 'en':
      default:
        return 'A new appointment has been booked';
    }
  }

  String patientLabel(String patientName) {
    switch (locale.languageCode) {
      case 'ar':
        return '👤 مريض: $patientName';
      case 'fr':
        return '👤 Patient: $patientName';
      case 'en':
      default:
        return '👤 Patient: $patientName';
    }
  }

  String get patientWaitingTitle {
    switch (locale.languageCode) {
      case 'ar':
        return '⏳ مريض في الانتظار';
      case 'fr':
        return '⏳ Patient en attente';
      case 'en':
      default:
        return '⏳ Patient Waiting';
    }
  }

  String patientWaitingMessage(String waitingRoom) {
    switch (locale.languageCode) {
      case 'ar':
        return 'مريض ينتظرك في $waitingRoom';
      case 'fr':
        return 'Un patient vous attend dans $waitingRoom';
      case 'en':
      default:
        return 'A patient is waiting for you in $waitingRoom';
    }
  }

  // Admin notifications
  String get newUserTitle {
    switch (locale.languageCode) {
      case 'ar':
        return '👤 مستخدم جديد';
      case 'fr':
        return '👤 Nouvel utilisateur';
      case 'en':
      default:
        return '👤 New User';
    }
  }

  String newUserMessage(String userName, String userRole) {
    switch (locale.languageCode) {
      case 'ar':
        return '$userName ($userRole) سجل للتو';
      case 'fr':
        return '$userName ($userRole) s\'est inscrit';
      case 'en':
      default:
        return '$userName ($userRole) has registered';
    }
  }

  // Emergency notifications
  String emergencyTitle(String title) {
    switch (locale.languageCode) {
      case 'ar':
        return '🚨 $title';
      case 'fr':
        return '🚨 $title';
      case 'en':
      default:
        return '🚨 $title';
    }
  }

  String emergencyMessage(String message, String location) {
    switch (locale.languageCode) {
      case 'ar':
        if (location.isNotEmpty) {
          return '$message\n📍 $location';
        }
        return message;
      case 'fr':
        if (location.isNotEmpty) {
          return '$message\n📍 $location';
        }
        return message;
      case 'en':
      default:
        if (location.isNotEmpty) {
          return '$message\n📍 $location';
        }
        return message;
    }
  }

  // Channel names
  String get appointmentsChannelName {
    switch (locale.languageCode) {
      case 'ar':
        return 'المواعيد';
      case 'fr':
        return 'Rendez-vous';
      case 'en':
      default:
        return 'Appointments';
    }
  }

  String get prescriptionsChannelName {
    switch (locale.languageCode) {
      case 'ar':
        return 'الوصفات';
      case 'fr':
        return 'Ordonnances';
      case 'en':
      default:
        return 'Prescriptions';
    }
  }

  String get messagesChannelName {
    switch (locale.languageCode) {
      case 'ar':
        return 'الرسائل';
      case 'fr':
        return 'Messages';
      case 'en':
      default:
        return 'Messages';
    }
  }

  String get emergencyChannelName {
    switch (locale.languageCode) {
      case 'ar':
        return 'الطوارئ';
      case 'fr':
        return 'Urgences';
      case 'en':
      default:
        return 'Emergencies';
    }
  }
}

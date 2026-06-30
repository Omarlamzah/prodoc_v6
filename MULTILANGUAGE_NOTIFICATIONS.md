# Multi-Language Notification Support

This document explains how notifications support multiple languages (Arabic, French, and English).

## Overview

All notifications in the app now automatically display in the user's selected language. The app supports:
- **Arabic (ar)** - العربية
- **French (fr)** - Français  
- **English (en)** - English

## How It Works

### 1. Language Detection

The notification system automatically detects the user's language preference from SharedPreferences:

```dart
// Reads locale from 'selected_locale' key in SharedPreferences
final locale = await NotificationLocalization.getCurrentLocale();
```

### 2. Localized Strings

All notification text is provided through the `NotificationLocalization` class:

```dart
final strings = await NotificationLocalization.getStrings();
final title = strings.appointmentReminderTitle;
final message = strings.appointmentReminderMessage(...);
```

### 3. Automatic Language Selection

Notifications automatically use the same language as the app UI. When a user changes the app language, all future notifications will use that language.

## Supported Notification Types

### Appointment Notifications

#### Appointment Reminder (1 hour before)
- **Arabic:** 📅 تذكير بالموعد
- **French:** 📅 Rappel de rendez-vous
- **English:** 📅 Appointment Reminder

#### Appointment Soon (< 1 hour)
- **Arabic:** ⏰ موعد قريب
- **French:** ⏰ Rendez-vous bientôt
- **English:** ⏰ Appointment Soon

#### Appointment Confirmed
- **Arabic:** ✅ تم تأكيد الموعد
- **French:** ✅ Rendez-vous confirmé
- **English:** ✅ Appointment Confirmed

### Prescription Notifications

#### Prescription Ready
- **Arabic:** 💊 الوصفة جاهزة
- **French:** 💊 Ordonnance prête
- **English:** 💊 Prescription Ready

#### Medication Reminder
- **Arabic:** 💊 تذكير بالدواء
- **French:** 💊 Rappel de médicament
- **English:** 💊 Medication Reminder

### Doctor Notifications

#### New Appointment
- **Arabic:** 📅 موعد جديد
- **French:** 📅 Nouveau rendez-vous
- **English:** 📅 New Appointment

#### Patient Waiting
- **Arabic:** ⏳ مريض في الانتظار
- **French:** ⏳ Patient en attente
- **English:** ⏳ Patient Waiting

## Examples

### Example 1: Appointment Reminder (Arabic)

**Notification:**
```
📅 تذكير بالموعد
موعد مع د. أحمد (استشارة عامة) في 14:30
```

### Example 2: Appointment Soon (French)

**Notification:**
```
⏰ Rendez-vous bientôt
Votre rendez-vous est dans 30 minutes!
👨‍⚕️ Dr. Martin (Consultation générale) à 14:30
```

### Example 3: Prescription Ready (English)

**Notification:**
```
💊 Prescription Ready
Your prescription from Dr. Smith is ready
```

## Implementation

### Notification Localization Class

The `NotificationLocalization` class provides all localized strings:

```dart
// Get localized strings
final strings = await NotificationLocalization.getStrings();

// Use in notifications
final title = strings.appointmentReminderTitle;
final message = strings.appointmentReminderBody(doctorName, serviceName, time);
```

### Language Storage

The user's language preference is stored in SharedPreferences:
- **Key:** `selected_locale`
- **Format:** `languageCode_countryCode` (e.g., `ar_SA`, `fr_FR`, `en_US`)

### Default Language

If no language preference is found, the system defaults to:
- **French (fr_FR)** - as the primary language of the app

## Code Structure

### Files

1. **`lib/services/notification_localization.dart`**
   - `NotificationLocalization` class - Gets current locale
   - `NotificationStrings` class - Provides all localized strings

2. **`lib/services/notification_service.dart`**
   - Updated to use `NotificationLocalization.getStrings()`
   - All notification methods now support multiple languages

3. **`lib/services/appointment_notification_helper.dart`**
   - Updated to use localized strings for appointment notifications

## Adding New Languages

To add support for a new language:

1. **Update `NotificationStrings` class:**
   ```dart
   String get appointmentReminderTitle {
     switch (locale.languageCode) {
       case 'ar': return '...';
       case 'fr': return '...';
       case 'en': return '...';
       case 'es': return '...'; // New language
       default: return '...';
     }
   }
   ```

2. **Update `NotificationLocalization.getCurrentLocale()`:**
   ```dart
   if (languageCode == 'es') {
     return const Locale('es', 'ES');
   }
   ```

## Testing

### Test Language Switching

1. **Change app language** to Arabic
2. **Create an appointment** or wait for notification
3. **Verify notification** appears in Arabic
4. **Change language** to French
5. **Verify next notification** appears in French

### Test All Languages

1. **Arabic:** Set language to Arabic, create appointment
2. **French:** Set language to French, create appointment
3. **English:** Set language to English, create appointment

## Benefits

1. **Better UX:** Users see notifications in their preferred language
2. **Consistent:** Notifications match app UI language
3. **Automatic:** No manual configuration needed
4. **Comprehensive:** All notification types are localized

## Notes

- Notifications use the language set in the app settings
- Language preference is stored persistently
- Default language is French if no preference is set
- All notification text is fully localized (titles, messages, labels)

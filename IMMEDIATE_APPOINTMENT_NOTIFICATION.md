# Immediate Appointment Notification (< 1 Hour)

This document explains how the app handles appointments that are less than 1 hour away.

## Problem

When an appointment is created (on website or in app) and it's less than 1 hour away, we can't schedule a reminder 1 hour before (because that time has already passed). Instead, we should **immediately notify the patient**.

## Solution

The app now automatically detects appointments less than 1 hour away and shows an **immediate notification** instead of scheduling a future reminder.

## How It Works

### Scenario 1: Appointment Created on Website (< 1 Hour Away)

1. **Website:** Admin creates appointment for patient at 2:30 PM (current time: 2:00 PM - only 30 minutes away)
2. **Patient opens app:** App fetches appointments from API
3. **App detects:** Appointment is only 30 minutes away (< 1 hour)
4. **App shows immediate notification:** 
   - **Title:** ⏰ Rendez-vous bientôt
   - **Message:** Votre rendez-vous est dans 30 minutes!
   - **Details:** 👨‍⚕️ Dr. Smith (Consultation générale) à 14:30

### Scenario 2: Appointment Created in App (< 1 Hour Away)

1. **User creates appointment:** In app, creates appointment for 3:00 PM (current time: 2:15 PM - 45 minutes away)
2. **App detects:** Appointment is less than 1 hour away
3. **App shows immediate notification:** Same as above

### Scenario 3: Appointment More Than 1 Hour Away

1. **Appointment created:** For tomorrow at 2:30 PM
2. **App detects:** Appointment is more than 1 hour away
3. **App schedules reminder:** Local notification scheduled for 1 hour before (tomorrow at 1:30 PM)

## Notification Types

### Immediate Notification (< 1 Hour)

- **Type:** Urgent (red color)
- **Title:** ⏰ Rendez-vous bientôt
- **Message:** 
  - If < 15 minutes: "Votre rendez-vous est dans X minutes!"
  - If 15-59 minutes: "Votre rendez-vous est dans moins d'une heure"
- **Includes:** Doctor name, service name, appointment time

### Scheduled Reminder (≥ 1 Hour)

- **Type:** Info (blue color)
- **Title:** 📅 Rappel de rendez-vous
- **Message:** "Rendez-vous avec Dr. [Name] à [Time]"
- **Scheduled:** 1 hour before appointment

## Code Implementation

### Sync Service Logic

```dart
// In appointment_sync_service.dart
// Calculate time until appointment
final timeUntilAppointment = appointmentDateTime.difference(DateTime.now());

// If less than 1 hour away, show immediate notification
if (timeUntilAppointment.inHours < 1 && 
    timeUntilAppointment.inMinutes > 0) {
  await helper.notifyPatientAppointmentSoon(appointment);
}
// If more than 1 hour away, schedule reminder
else if (timeUntilAppointment.inHours >= 1) {
  await helper.scheduleAppointmentReminder(appointment);
}
```

### Helper Method

```dart
// In appointment_notification_helper.dart
Future<void> notifyPatientAppointmentSoon(AppointmentModel appointment) async {
  // Shows immediate notification with urgent priority
  // Includes time until appointment
  // Includes doctor and service details
}
```

## Features

### ✅ Smart Detection
- Automatically detects appointments < 1 hour away
- Calculates exact time until appointment
- Shows appropriate message based on time remaining

### ✅ Prevents Duplicates
- Tracks which appointments have been immediately notified
- Won't show duplicate notifications
- Uses SharedPreferences to remember notified appointments

### ✅ Works Everywhere
- Works for appointments created on website
- Works for appointments created in app
- Works when app syncs appointments

### ✅ User-Friendly Messages
- Shows exact minutes if < 15 minutes
- Shows "less than 1 hour" if 15-59 minutes
- Includes all relevant appointment details

## Examples

### Example 1: 30 Minutes Away

**Notification:**
```
⏰ Rendez-vous bientôt
Votre rendez-vous est dans 30 minutes!
👨‍⚕️ Dr. Smith (Consultation générale) à 14:30
```

### Example 2: 10 Minutes Away

**Notification:**
```
⏰ Rendez-vous bientôt
Votre rendez-vous est dans 10 minutes!
👨‍⚕️ Dr. Johnson (Urgence) à 15:00
```

### Example 3: 45 Minutes Away

**Notification:**
```
⏰ Rendez-vous bientôt
Votre rendez-vous est dans moins d'une heure
👨‍⚕️ Dr. Brown (Radiologie) à 16:15
```

## Storage

The service tracks immediately notified appointments separately from scheduled reminders:

- **Scheduled reminders:** `appointments_with_reminders` (for ≥ 1 hour)
- **Immediate notifications:** `appointments_notified_immediate` (for < 1 hour)

This prevents:
- Duplicate immediate notifications
- Scheduling reminders for appointments that already got immediate notifications

## Testing

### Test Immediate Notification

1. **Create appointment** for 30 minutes from now
2. **Open app** or **refresh appointments**
3. **Check notification** appears immediately
4. **Verify message** shows correct time remaining

### Test Scheduled Reminder

1. **Create appointment** for tomorrow
2. **Open app** or **refresh appointments**
3. **Check notification** is scheduled (not immediate)
4. **Verify reminder** appears 1 hour before

## Edge Cases

### Appointment in Past
- **Handled:** App ignores past appointments
- **No notification:** Past appointments don't trigger notifications

### Appointment Exactly 1 Hour Away
- **Handled:** Treated as "more than 1 hour" (schedules reminder)
- **Reason:** Gives full 1 hour notice

### Appointment Less Than 1 Minute Away
- **Handled:** Shows "X minutes" message
- **Note:** Only if appointment is still in future

## Files Modified

1. `lib/services/appointment_sync_service.dart` - Added immediate notification logic
2. `lib/services/appointment_notification_helper.dart` - Added `notifyPatientAppointmentSoon()` method
3. `lib/screens/create_appointment_screen.dart` - Added immediate notification check

## Benefits

1. **Better UX:** Patients are immediately notified about urgent appointments
2. **No Missed Appointments:** Patients won't miss appointments created last minute
3. **Smart Handling:** App automatically chooses best notification method
4. **Comprehensive:** Works for both website and app-created appointments

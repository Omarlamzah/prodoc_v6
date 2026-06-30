# Website Appointment Sync - Local Notification Reminders

This document explains how appointments created on the website are synced to the mobile app and how local notification reminders are automatically scheduled.

## Problem

When an appointment is created on the website (online), the patient's mobile app needs to:
1. **See the appointment** when they open the app
2. **Receive a local notification reminder** 1 hour before the appointment

## Solution

The app automatically syncs appointments when they are fetched from the API and schedules local notification reminders for any new appointments.

## How It Works

### 1. App Fetches Appointments

When the user opens the appointments screen or refreshes it, the app fetches appointments from the API:

```dart
// In appointments_screen.dart
final appointmentsAsync = ref.watch(appointmentsProvider(_currentParams()));
```

### 2. Automatic Sync

When appointments are successfully loaded, the app automatically:

1. **Checks which appointments need reminders**
   - Only future appointments (not past)
   - Only appointments that don't already have reminders scheduled

2. **Schedules reminders**
   - Schedules local notification 1 hour before each appointment
   - Stores appointment IDs to avoid duplicate reminders

3. **Tracks scheduled reminders**
   - Uses SharedPreferences to remember which appointments have reminders
   - Prevents scheduling duplicate reminders

### 3. Example Flow

**Scenario:** Patient books appointment on website

1. **Website:** Appointment created on December 20, 2024 at 2:30 PM
2. **Patient opens app:** App fetches appointments from API
3. **App detects new appointment:** Sees appointment #123 (created on website)
4. **App schedules reminder:** Local notification scheduled for December 20, 2024 at 1:30 PM (1 hour before)
5. **Reminder appears:** Patient receives notification 1 hour before appointment

## Code Implementation

### Sync Service

The `AppointmentSyncService` handles all the sync logic:

```dart
// lib/services/appointment_sync_service.dart
final syncService = AppointmentSyncService();

// Sync appointments and schedule reminders
await syncService.syncAppointments(appointments);
```

### Integration in Appointments Screen

The sync happens automatically when appointments are loaded:

```dart
// In appointments_screen.dart
ref.listen<AsyncValue<Result<List<AppointmentModel>>>>(
  appointmentsProvider(_currentParams()),
  (previous, next) {
    next.whenData((result) {
      if (result is Success<List<AppointmentModel>>) {
        // Sync appointments in background
        _syncAppointments(result.data);
      }
    });
  },
);
```

## Features

### ✅ Automatic Detection
- Detects appointments created on website
- Only schedules reminders for future appointments
- Skips appointments that already have reminders

### ✅ Prevents Duplicates
- Tracks scheduled appointment IDs in SharedPreferences
- Won't schedule duplicate reminders for same appointment
- Handles app restarts gracefully

### ✅ Background Sync
- Syncs in background (doesn't block UI)
- No user interaction required
- Works when app opens or refreshes

### ✅ Smart Filtering
- Only schedules for appointments in the future
- Validates appointment date and time
- Handles missing data gracefully

## When Sync Happens

The sync automatically happens when:

1. **Appointments screen opens** - Fetches and syncs appointments
2. **User refreshes appointments** - Re-syncs and checks for new appointments
3. **App comes to foreground** - If appointments are already loaded, syncs again

## Storage

The service uses SharedPreferences to track scheduled reminders:

- **Key:** `appointments_with_reminders`
- **Value:** Comma-separated list of appointment IDs
- **Example:** `"123,456,789"` means appointments 123, 456, and 789 have reminders

## Cancellation

When an appointment is cancelled, the reminder is also cancelled:

```dart
final syncService = AppointmentSyncService();
await syncService.removeScheduledAppointment(appointmentId);
```

## Testing

### Test with Website Appointment

1. **Create appointment on website** (as patient or admin)
2. **Open mobile app** and go to appointments screen
3. **Check logs** for sync messages:
   ```
   [AppointmentSyncService] Scheduling reminders for X appointments
   [AppointmentSyncService] Successfully scheduled X reminders
   ```
4. **Check scheduled notifications:**
   ```dart
   final notificationService = NotificationService();
   await notificationService.initialize();
   final pending = await notificationService.getPendingNotifications();
   print('Pending: ${pending.length}');
   ```

### Verify Reminder

1. **Check notification is scheduled** (see above)
2. **Wait for reminder time** (or set appointment in near future for testing)
3. **Verify notification appears** 1 hour before appointment

## Troubleshooting

### Reminders Not Scheduling

1. **Check logs:** Look for `[AppointmentSyncService]` messages
2. **Check permissions:** Ensure notification permissions are granted
3. **Check date:** Verify appointment is in the future
4. **Check storage:** Verify SharedPreferences is working

### Duplicate Reminders

1. **Clear storage:** 
   ```dart
   final syncService = AppointmentSyncService();
   await syncService.clearAllScheduledAppointments();
   ```
2. **Re-sync:** Open appointments screen again

### Appointments Not Showing

1. **Check API:** Verify appointments are being fetched
2. **Check authentication:** Ensure user is logged in
3. **Check filters:** Verify appointment filters aren't hiding appointments

## Files

- `lib/services/appointment_sync_service.dart` - Sync service
- `lib/services/appointment_notification_helper.dart` - Helper for scheduling
- `lib/services/notification_service.dart` - Notification service
- `lib/screens/appointments_screen.dart` - Integration point

## Next Steps

1. ✅ Sync service created
2. ✅ Integrated into appointments screen
3. ✅ Automatic reminder scheduling
4. ✅ Duplicate prevention
5. 🔄 Test with real website appointments
6. 🔄 Add sync on app startup (optional)
7. 🔄 Add sync on login (optional)

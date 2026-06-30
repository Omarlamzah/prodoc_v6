# Appointment Reminder Example - 1 Hour Before

This document shows how the local notification reminder works when an appointment is created.

## How It Works

When an appointment is successfully created, the system automatically:

1. **Schedules a local notification** that will fire **1 hour before** the appointment time
2. **Notifies the doctor** about the new appointment (if created by admin/receptionist)
3. **Notifies the patient** about appointment confirmation (if patient has an account)

## Example Flow

### 1. User Creates Appointment

```dart
// In create_appointment_screen.dart
final result = await ref.read(createAppointmentProvider(appointmentData).future);

result.when(
  success: (response) {
    // Automatically schedule reminder 1 hour before
    _scheduleAppointmentReminder(response);
    _showSuccessDialog(response);
  },
  failure: (message) {
    // Handle error
  },
);
```

### 2. Reminder is Scheduled

The `_scheduleAppointmentReminder()` method:

- Parses the appointment date and time
- Calculates reminder time (appointment time - 1 hour)
- Schedules the notification using `AppointmentNotificationHelper`

**Example:**
- Appointment: December 25, 2024 at 2:30 PM
- Reminder scheduled for: December 25, 2024 at 1:30 PM (1 hour before)

### 3. Notification Appears

When the reminder time arrives (1 hour before appointment), the user receives a notification:

**Title:** 📅 Rappel de rendez-vous

**Message:** 
```
Rendez-vous avec Dr. Smith (Consultation générale) à 14:30
```

### 4. What Happens

- ✅ Notification appears even if app is closed
- ✅ Works offline (local notification)
- ✅ User can tap notification to open app
- ✅ Notification includes appointment details

## Code Implementation

### Helper Class

The `AppointmentNotificationHelper` class handles all the logic:

```dart
// lib/services/appointment_notification_helper.dart
final helper = AppointmentNotificationHelper();

// Schedule reminder 1 hour before
await helper.scheduleAppointmentReminder(
  appointment: response.appointment,
  reminderBefore: const Duration(hours: 1),
);
```

### Integration Point

The reminder is automatically scheduled in `create_appointment_screen.dart`:

```dart
result.when(
  success: (response) {
    // Schedule reminder 1 hour before appointment
    _scheduleAppointmentReminder(response);
    _showSuccessDialog(response);
  },
  // ...
);
```

## Customization

### Change Reminder Time

To change from 1 hour to 30 minutes before:

```dart
await helper.scheduleAppointmentReminder(
  appointment: response.appointment,
  reminderBefore: const Duration(minutes: 30), // Changed to 30 minutes
);
```

### Multiple Reminders

You can schedule multiple reminders:

```dart
// 1 day before
await helper.scheduleAppointmentReminder(
  appointment: response.appointment,
  reminderBefore: const Duration(days: 1),
);

// 1 hour before
await helper.scheduleAppointmentReminder(
  appointment: response.appointment,
  reminderBefore: const Duration(hours: 1),
);

// 15 minutes before
await helper.scheduleAppointmentReminder(
  appointment: response.appointment,
  reminderBefore: const Duration(minutes: 15),
);
```

## Testing

### Test Reminder Immediately

To test the reminder immediately (for development):

```dart
// Schedule reminder 1 minute from now
await helper.scheduleAppointmentReminder(
  appointment: response.appointment,
  reminderBefore: DateTime.now()
      .add(const Duration(minutes: 1))
      .difference(response.appointmentDateTime),
);
```

### Check Scheduled Notifications

```dart
final notificationService = NotificationService();
await notificationService.initialize();
final pending = await notificationService.getPendingNotifications();
print('Pending notifications: ${pending.length}');
```

## Cancellation

If an appointment is cancelled, cancel the reminder:

```dart
final helper = AppointmentNotificationHelper();
await helper.cancelAppointmentReminder(appointmentId);
```

## Platform Notes

### Android
- Notifications work even when app is closed
- Battery optimization may affect exact timing
- Users can customize notification settings per channel

### iOS
- Limited to 64 scheduled notifications
- Requires notification permissions
- Notifications may be grouped

## Troubleshooting

### Reminder Not Appearing

1. **Check permissions**: Ensure notification permissions are granted
2. **Check time**: Verify appointment is in the future
3. **Check timezone**: Ensure device timezone matches app timezone
4. **Check logs**: Look for debug messages in console

### Reminder Appearing at Wrong Time

1. **Check timezone**: Verify timezone initialization
2. **Check date format**: Ensure date is in `yyyy-MM-dd` format
3. **Check time format**: Ensure time is in `HH:mm` format

## Files

- `lib/services/appointment_notification_helper.dart` - Helper class
- `lib/services/notification_service.dart` - Notification service
- `lib/screens/create_appointment_screen.dart` - Integration point

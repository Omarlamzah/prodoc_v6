# Local Notifications Guide

This guide explains how to use the enhanced local notification system in your healthcare management app.

## Overview

The `NotificationService` has been enhanced with comprehensive local notification support for doctors, admins, and patients. These notifications help keep all users informed about important events even when the app is not actively being used.

## Features

### ✅ Appointment Notifications
- **Scheduled reminders**: Automatically remind patients and doctors about upcoming appointments
- **New appointment alerts**: Notify doctors when new appointments are created
- **Confirmation notifications**: Confirm appointments to patients
- **Cancellation alerts**: Notify when appointments are cancelled

### ✅ Prescription Notifications
- **Prescription ready**: Notify patients when their prescription is ready
- **Medication reminders**: Schedule reminders for patients to take their medications

### ✅ Admin Notifications
- **System alerts**: Important system-wide notifications
- **New user registrations**: Alert admins about new user signups
- **Urgent alerts**: Critical notifications that require immediate attention

### ✅ Doctor Notifications
- **New appointments**: Alert doctors about new appointment bookings
- **Patient waiting**: Notify when patients are waiting in the waiting room
- **Urgent requests**: Alert about urgent patient requests

### ✅ Patient Notifications
- **Appointment confirmations**: Confirm appointment bookings
- **Appointment reminders**: Remind patients about upcoming appointments
- **Follow-up reminders**: Remind about follow-up appointments

## Notification Channels

The service creates separate notification channels for different types of notifications:

- **Messages**: Chat messages (existing)
- **Urgences**: Emergency alerts (existing)
- **Rendez-vous**: Appointment notifications (new)
- **Ordonnances**: Prescription notifications (new)
- **Alertes Admin**: Admin notifications (new)
- **Alertes Médecin**: Doctor notifications (new)
- **Alertes Patient**: Patient notifications (new)

Users can customize notification settings for each channel in their device settings.

## Usage Examples

### 1. Schedule Appointment Reminder

```dart
final notificationService = NotificationService();
await notificationService.initialize();

await notificationService.scheduleAppointmentReminder(
  appointmentId: 123,
  appointmentDate: DateTime(2024, 12, 25, 14, 30),
  patientName: 'John Doe',
  doctorName: 'Dr. Smith',
  serviceName: 'Consultation générale',
  reminderBefore: Duration(hours: 1), // Remind 1 hour before
  payload: {
    'type': 'appointment_reminder',
    'appointment_id': 123,
  },
);
```

### 2. Notify Doctor About New Appointment

```dart
await notificationService.showDoctorNotification(
  title: 'Nouveau rendez-vous',
  message: 'Un nouveau rendez-vous a été réservé',
  notificationId: 123,
  type: NotificationType.info,
  patientName: 'John Doe',
  payload: {
    'type': 'new_appointment',
    'appointment_id': 123,
  },
);
```

### 3. Notify Patient About Prescription Ready

```dart
await notificationService.showPrescriptionReadyNotification(
  patientName: 'John Doe',
  prescriptionId: 456,
  doctorName: 'Dr. Smith',
  payload: {
    'type': 'prescription_ready',
    'prescription_id': 456,
  },
);
```

### 4. Schedule Medication Reminder

```dart
await notificationService.scheduleMedicationReminder(
  reminderId: 789,
  medicationName: 'Paracétamol',
  dosage: '500mg',
  reminderTime: DateTime(2024, 12, 25, 8, 0), // 8 AM
  prescriptionId: 456,
  payload: {
    'type': 'medication_reminder',
    'prescription_id': 456,
  },
);
```

### 5. Admin System Alert

```dart
await notificationService.showAdminNotification(
  title: 'Alerte système',
  message: 'Le serveur a besoin d\'attention',
  notificationId: 999,
  type: NotificationType.urgent,
  payload: {
    'type': 'system_alert',
    'alert_id': 999,
  },
);
```

## Notification Types

The service supports different notification types with appropriate styling:

- **`NotificationType.info`**: Blue color, informational notifications
- **`NotificationType.success`**: Green color, success confirmations
- **`NotificationType.warning`**: Orange color, warnings
- **`NotificationType.urgent`**: Red color, urgent alerts

## Integration Points

### When Creating an Appointment

```dart
// After successfully creating an appointment
await notificationService.scheduleAppointmentReminder(
  appointmentId: appointment.id!,
  appointmentDate: appointmentDate,
  patientName: patient.name,
  doctorName: doctor.name,
);

// Notify doctor
await notificationService.showDoctorNotification(
  title: 'Nouveau rendez-vous',
  message: 'Un nouveau rendez-vous a été réservé',
  notificationId: appointment.id!,
  type: NotificationType.info,
  patientName: patient.name,
);
```

### When Creating a Prescription

```dart
// After successfully creating a prescription
await notificationService.showPrescriptionReadyNotification(
  patientName: patient.name,
  prescriptionId: prescription.id!,
  doctorName: doctor.name,
);

// Schedule medication reminders based on frequency
for (final medication in medications) {
  await notificationService.scheduleMedicationReminder(
    reminderId: prescription.id! * 100 + index,
    medicationName: medication.name,
    dosage: medication.dosage,
    reminderTime: calculateNextReminderTime(medication),
    prescriptionId: prescription.id!,
  );
}
```

### When Cancelling an Appointment

```dart
// Cancel the scheduled reminder
await notificationService.cancelAppointmentReminder(appointmentId);

// Notify both parties
await notificationService.showPatientNotification(
  title: 'Rendez-vous annulé',
  message: 'Votre rendez-vous a été annulé',
  notificationId: appointmentId,
  type: NotificationType.warning,
);
```

## Handling Notification Taps

When a user taps on a notification, you can handle navigation based on the payload:

```dart
// In your main.dart or app initialization
final notificationService = NotificationService();
await notificationService.initialize();

// The service already handles notification taps via _onNotificationTapped
// You can extend this method to add navigation logic
```

## Best Practices

1. **Always initialize**: Call `await notificationService.initialize()` before using the service
2. **Use appropriate types**: Choose the right `NotificationType` for the importance level
3. **Include payload**: Add payload data to enable navigation when notifications are tapped
4. **Cancel when needed**: Cancel scheduled reminders when appointments/prescriptions are cancelled or updated
5. **Respect user preferences**: Allow users to enable/disable specific notification types
6. **Don't over-notify**: Balance between keeping users informed and avoiding notification fatigue

## Platform Considerations

### Android
- Notifications use separate channels that users can customize
- Scheduled notifications work even when the app is closed
- Battery optimization may affect exact timing on some devices

### iOS
- Requires user permission (handled automatically)
- Limited number of scheduled notifications (64 by default)
- Notifications may be grouped by thread identifier

## Troubleshooting

### Notifications not showing
1. Check if permissions are granted (especially on Android 13+)
2. Verify the notification service is initialized
3. Check device notification settings
4. Ensure the app is not in battery optimization mode

### Scheduled notifications not firing
1. Verify the scheduled time is in the future
2. Check device timezone settings
3. Ensure the app has necessary permissions
4. On Android, check battery optimization settings

### Notifications appearing at wrong time
1. Verify timezone initialization in the service
2. Check if device timezone matches app timezone
3. Ensure dates are converted to the correct timezone

## Files

- **`lib/services/notification_service.dart`**: Main notification service
- **`lib/services/notification_usage_examples.dart`**: Usage examples and integration patterns

## Next Steps

1. Integrate notification calls in your appointment creation flow
2. Add notification calls when prescriptions are created
3. Implement notification tap handling for navigation
4. Add user preferences for notification types
5. Test notifications on both Android and iOS devices

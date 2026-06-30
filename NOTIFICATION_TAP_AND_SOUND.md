# Notification Tap Navigation & Sound

This document explains how notification tap navigation and sound work in the app.

## Notification Tap Navigation

When a user taps on a notification, the app automatically navigates to the appropriate screen.

### Appointment Notifications

**When user taps appointment notification:**
- ✅ Navigates to **Appointments Screen**
- ✅ Works from any screen (background, foreground, app closed)
- ✅ Uses global navigator key for navigation

### Supported Notification Types

1. **Appointment Reminder** → Navigates to Appointments Screen
2. **Appointment Soon** (< 1 hour) → Navigates to Appointments Screen
3. **Appointment Confirmed** → Navigates to Appointments Screen
4. **New Appointment** → Navigates to Appointments Screen

### How It Works

```dart
// When notification is tapped
_onNotificationTapped(NotificationResponse response) {
  // Parse payload to determine notification type
  if (payload.contains('appointment')) {
    _navigateToAppointmentsScreen();
  }
}

// Navigate using global navigator
void _navigateToAppointmentsScreen() {
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => const AppointmentsScreen(),
    ),
  );
}
```

## Notification Sound

All notifications have **sound enabled** by default.

### Sound Configuration

#### Android
- **Channel Level:** `playSound: true` in notification channels
- **Notification Level:** `playSound: true` in notification details
- **Default Sound:** Uses system default notification sound

#### iOS
- **Permission:** `requestSoundPermission: true` during initialization
- **Notification Level:** `presentSound: true` in notification details
- **Default Sound:** Uses system default notification sound

### Sound Settings by Notification Type

| Notification Type | Sound Enabled | Vibration | Priority |
|------------------|---------------|-----------|----------|
| Appointment Reminder | ✅ Yes | ✅ Yes | High |
| Appointment Soon | ✅ Yes | ✅ Yes | Urgent |
| Appointment Confirmed | ✅ Yes | ✅ Yes | High |
| Prescription Ready | ✅ Yes | ✅ Yes | High |
| Medication Reminder | ✅ Yes | ✅ Yes | High |
| Doctor Notifications | ✅ Yes | ✅ Yes | High |
| Patient Notifications | ✅ Yes | ✅ Yes | High |
| Admin Notifications | ✅ Yes | ✅ Yes | High/Urgent |
| Emergency Alerts | ✅ Yes | ✅ Yes | Max |
| Chat Messages | ✅ Yes | ✅ Yes | High |

### Code Examples

#### Android Notification with Sound

```dart
const androidDetails = AndroidNotificationDetails(
  _appointmentChannelId,
  _appointmentChannelName,
  description: 'Notifications pour les rendez-vous',
  importance: Importance.high,
  priority: Priority.high,
  playSound: true,  // ✅ Sound enabled
  enableVibration: true,
  showWhen: true,
);
```

#### iOS Notification with Sound

```dart
const iosDetails = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,  // ✅ Sound enabled
  badgeNumber: 1,
);
```

## Testing

### Test Notification Tap

1. **Receive notification** (appointment reminder, etc.)
2. **Tap notification** from notification tray
3. **Verify** app opens and navigates to Appointments Screen
4. **Check logs** for navigation confirmation

### Test Sound

1. **Enable device sound** (not on silent/vibrate)
2. **Receive notification**
3. **Verify** notification sound plays
4. **Check** device notification settings if sound doesn't play

## User Settings

### Android

Users can customize notification sound per channel:
1. **Settings** → **Apps** → **Your App** → **Notifications**
2. Select notification channel (e.g., "Rendez-vous")
3. **Sound** → Choose custom sound or use default

### iOS

Users can customize notification sound:
1. **Settings** → **Notifications** → **Your App**
2. **Sounds** → Choose notification sound
3. Ensure "Allow Notifications" is enabled

## Troubleshooting

### Notification Tap Not Working

1. **Check navigator key:** Ensure `navigatorKey` is set in MaterialApp
2. **Check payload:** Verify notification has payload with 'appointment' keyword
3. **Check logs:** Look for `[NotificationService]` messages
4. **Test manually:** Try navigating to appointments screen manually

### Sound Not Playing

1. **Check device settings:**
   - Ensure device is not on silent/vibrate mode
   - Check app notification permissions
   - Verify notification channel sound settings (Android)

2. **Check code:**
   - Verify `playSound: true` in notification details
   - Verify `presentSound: true` for iOS
   - Check notification channel has `playSound: true`

3. **Check permissions:**
   - iOS: Ensure sound permission is granted
   - Android: Check notification channel settings

4. **Test on device:**
   - Some emulators may not play sounds
   - Test on real device for accurate results

## Customization

### Change Default Sound

#### Android
```dart
// In notification channel
const AndroidNotificationChannel(
  _appointmentChannelId,
  _appointmentChannelName,
  sound: RawResourceAndroidNotificationSound('custom_sound'),
  // ...
);
```

#### iOS
```dart
// In notification details
const DarwinNotificationDetails(
  presentSound: true,
  sound: 'custom_sound.caf',
  // ...
);
```

### Disable Sound for Specific Notification

```dart
final androidDetails = AndroidNotificationDetails(
  _appointmentChannelId,
  _appointmentChannelName,
  playSound: false,  // Disable sound
  // ...
);
```

## Files

- `lib/services/notification_service.dart` - Notification service with tap handling
- `lib/main.dart` - Global navigator key
- `lib/screens/appointments_screen.dart` - Appointments screen

## Benefits

1. **Better UX:** Users can quickly access appointments from notifications
2. **Sound Alerts:** Users won't miss important notifications
3. **Seamless Navigation:** Works from any app state
4. **User Control:** Users can customize sounds in device settings

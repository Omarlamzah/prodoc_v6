# Global Appointment Sync

This document explains how appointment notifications work globally in the app, not just when viewing the appointments screen.

## Problem

Previously, appointment sync only happened when the user opened the appointments screen. This meant:
- Notifications wouldn't appear if user was on other screens
- Appointments created on website wouldn't be detected until user visited appointments screen
- Users had to manually open appointments screen to get reminders

## Solution

Appointment sync now runs **globally in the background** when the user is authenticated, regardless of which screen they're on.

## How It Works

### 1. Global Sync Service

The `GlobalAppointmentSync` service:
- Runs automatically when user logs in
- Syncs appointments every 5 minutes in the background
- Works on any screen (dashboard, patients, prescriptions, etc.)
- Stops when user logs out

### 2. Automatic Startup

When user logs in or opens the dashboard:
1. **Sync starts immediately** - Fetches appointments and schedules reminders
2. **Periodic sync** - Checks for new appointments every 5 minutes
3. **Background operation** - Doesn't block UI or require user interaction

### 3. Smart Sync Logic

- **Prevents duplicate syncs** - Won't sync if already syncing
- **Rate limiting** - Minimum 1 minute between syncs
- **Authentication check** - Only syncs when user is logged in
- **Error handling** - Silently handles errors without disrupting user

## When Sync Happens

### Automatic Triggers

1. **User logs in** - Sync starts immediately
2. **Dashboard opens** - Sync starts if not already running
3. **Every 5 minutes** - Periodic background sync
4. **App comes to foreground** - Sync can be triggered

### Manual Triggers

- User can manually refresh appointments (existing functionality)
- Force sync can be called programmatically

## Code Implementation

### Global Sync Service

```dart
// lib/services/global_appointment_sync.dart
final syncService = ref.read(globalAppointmentSyncProvider);
syncService.startSync(ref); // Start global sync
```

### Dashboard Integration

```dart
// In dashboard_screen.dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _startAppointmentSync(); // Start sync when dashboard loads
  });
}

void _startAppointmentSync() {
  final authState = ref.read(authProvider);
  if (authState.isAuth == true) {
    final syncService = ref.read(globalAppointmentSyncProvider);
    syncService.startSync(ref);
  }
}
```

### Auth State Listener

```dart
// Automatically start/stop sync based on auth state
ref.listen<AuthState>(authProvider, (previous, next) {
  final syncService = ref.read(globalAppointmentSyncProvider);
  
  if (next.isAuth == true && previous?.isAuth != true) {
    // User logged in - start sync
    syncService.startSync(ref);
  } else if (next.isAuth == false && previous?.isAuth == true) {
    // User logged out - stop sync
    syncService.stopSync();
  }
});
```

## Benefits

### ✅ Works Everywhere
- Notifications appear regardless of current screen
- User doesn't need to visit appointments screen
- Works in background automatically

### ✅ Automatic Detection
- Detects appointments created on website immediately
- Schedules reminders without user action
- Updates every 5 minutes automatically

### ✅ Better UX
- No manual refresh needed
- Notifications appear when they should
- Works seamlessly in background

### ✅ Efficient
- Rate limiting prevents excessive API calls
- Only syncs when authenticated
- Doesn't block UI thread

## Sync Frequency

- **Initial sync:** Immediately when user logs in
- **Periodic sync:** Every 5 minutes
- **Minimum interval:** 1 minute between syncs (rate limiting)
- **Manual refresh:** User can still manually refresh appointments

## Example Flow

1. **User logs in** → Sync starts immediately
2. **User on dashboard** → Sync runs in background every 5 minutes
3. **Appointment created on website** → Detected within 5 minutes
4. **Notification scheduled** → Reminder set automatically
5. **User on any screen** → Notification appears when time comes

## Testing

### Test Global Sync

1. **Log in** to the app
2. **Stay on dashboard** (don't open appointments screen)
3. **Create appointment on website** (as admin/patient)
4. **Wait up to 5 minutes** (or manually refresh)
5. **Check notification** appears (if appointment is soon)

### Test Background Operation

1. **Log in** to the app
2. **Navigate to different screens** (patients, prescriptions, etc.)
3. **Create appointment on website**
4. **Verify** notification still appears (sync works in background)

## Files

- `lib/services/global_appointment_sync.dart` - Global sync service
- `lib/screens/dashboard_screen.dart` - Integration point
- `lib/services/appointment_sync_service.dart` - Core sync logic

## Configuration

### Change Sync Frequency

To change from 5 minutes to a different interval:

```dart
// In global_appointment_sync.dart
_periodicSyncTimer = Timer.periodic(
  const Duration(minutes: 10), // Change to 10 minutes
  (_) => _syncAppointments(ref),
);
```

### Change Rate Limit

To change minimum interval between syncs:

```dart
// In global_appointment_sync.dart
if (timeSinceLastSync.inMinutes < 2) { // Change to 2 minutes
  return;
}
```

## Troubleshooting

### Notifications Not Appearing

1. **Check if sync is running:**
   ```dart
   final syncService = ref.read(globalAppointmentSyncProvider);
   print('Is syncing: ${syncService.isSyncing}');
   print('Last sync: ${syncService.lastSyncTime}');
   ```

2. **Check authentication:** Ensure user is logged in
3. **Check logs:** Look for `[GlobalAppointmentSync]` messages
4. **Force sync:** Call `syncService.forceSync(ref)` to test

### Sync Not Starting

1. **Check dashboard:** Ensure dashboard screen is loaded
2. **Check auth state:** Verify user is authenticated
3. **Check logs:** Look for startup messages

## Next Steps

1. ✅ Global sync service created
2. ✅ Integrated into dashboard
3. ✅ Automatic start/stop on login/logout
4. ✅ Periodic background sync
5. ✅ Removed screen-specific sync
6. 🔄 Test with real appointments
7. 🔄 Monitor performance

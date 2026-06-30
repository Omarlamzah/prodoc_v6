# Flutter Notifications Integration Guide

This guide explains how to use the Laravel API notifications in your Flutter application, similar to how they work in Next.js.

## Overview

The notification system integrates with your Laravel backend to:
- Fetch notifications from the API
- Display unread count in a bell icon
- Show local push notifications when new notifications arrive
- Allow users to mark notifications as read/delete
- Auto-refresh notifications every 30 seconds

## Components

### 1. API Notification Service (`api_notification_service.dart`)
Service that handles all API calls to Laravel notification endpoints:
- `fetchNotifications()` - Get notifications with pagination
- `getUnreadCount()` - Get unread count
- `markAsRead()` - Mark notification as read
- `markAllAsRead()` - Mark all as read
- `deleteNotification()` - Delete a notification
- `deleteAllNotifications()` - Delete all notifications

### 2. Notification Provider (`api_notification_provider.dart`)
Riverpod provider that manages notification state:
- Automatically polls for new notifications every 30 seconds
- Manages notification list and unread count
- Shows local push notifications for new unread notifications
- Handles marking as read/delete operations

### 3. Notification Bell Widget (`api_notification_bell.dart`)
A bell icon widget that:
- Shows unread count badge
- Opens notification list when tapped
- Automatically fetches notifications when opened

### 4. Notification List Widget (`api_notification_list.dart`)
A bottom sheet that displays:
- List of all notifications
- Unread indicators
- Swipe to delete
- Pull to refresh
- Load more pagination
- Mark all as read button

## Usage

### Basic Usage

The notification bell is already integrated into the dashboard AppBar. It will automatically:
1. Start polling for notifications when the app loads
2. Show unread count badge
3. Display local push notifications for new notifications

### Manual Usage

If you want to use notifications in other screens:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/api_notification_bell.dart';
import '../providers/api_notification_provider.dart';

// In your widget
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Access notification state
    final notificationState = ref.watch(notificationProvider);
    final unreadCount = notificationState.unreadCount;
    
    return Scaffold(
      appBar: AppBar(
        actions: [
          // Add notification bell
          const ApiNotificationBell(),
        ],
      ),
      body: Column(
        children: [
          // Display unread count
          Text('Unread: $unreadCount'),
          
          // Manually fetch notifications
          ElevatedButton(
            onPressed: () {
              ref.read(notificationProvider.notifier).fetchNotifications(
                refresh: true,
              );
            },
            child: Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
```

### Programmatic Access

```dart
// Get notification state
final notificationState = ref.watch(notificationProvider);

// Access notifications
final notifications = notificationState.notifications;
final unreadCount = notificationState.unreadCount;
final isLoading = notificationState.isLoading;

// Mark notification as read
ref.read(notificationProvider.notifier).markAsRead(notificationId);

// Mark all as read
ref.read(notificationProvider.notifier).markAllAsRead();

// Delete notification
ref.read(notificationProvider.notifier).deleteNotification(notificationId);

// Refresh notifications
ref.read(notificationProvider.notifier).fetchNotifications(refresh: true);

// Stop/start polling
ref.read(notificationProvider.notifier).stopPolling();
ref.read(notificationProvider.notifier).startPolling();
```

## How It Works

### 1. Initialization
When the app starts and user is authenticated:
- The `NotificationNotifier` is initialized
- Polling starts automatically (every 30 seconds)
- Initial notification fetch is triggered

### 2. Polling
Every 30 seconds:
- Unread count is refreshed
- If unread count increases, new notifications are fetched
- Local push notifications are shown for new unread notifications

### 3. Local Notifications
When new notifications arrive from the API:
- The system determines notification type (appointment, prescription, invoice, etc.)
- Shows appropriate local push notification using `NotificationService`
- User can tap notification to navigate to relevant screen

### 4. Notification Types
The system automatically handles different notification types:
- **Appointment**: Shows appointment notification with navigation
- **Prescription**: Shows prescription ready notification
- **Invoice**: Shows invoice notification
- **Emergency**: Shows emergency alert
- **Generic**: Shows admin/doctor/patient notification based on user role

## API Endpoints

The system uses these Laravel API endpoints (already configured in `api_constants.dart`):

- `GET /api/notifications` - Fetch notifications
- `GET /api/notifications/unread-count` - Get unread count
- `POST /api/notifications/{id}/read` - Mark as read
- `POST /api/notifications/read-all` - Mark all as read
- `DELETE /api/notifications/{id}` - Delete notification
- `DELETE /api/notifications` - Delete all notifications
- `DELETE /api/notifications/read/all` - Delete read notifications

## Customization

### Change Polling Interval

In `api_notification_provider.dart`:
```dart
void startPolling({Duration interval = const Duration(seconds: 30)}) {
  // Change interval here
}
```

### Customize Notification Display

Modify `api_notification_list.dart` to customize:
- Colors and styling
- Layout
- Actions
- Navigation behavior

### Customize Local Notifications

Modify `_showLocalNotification()` in `api_notification_provider.dart` to:
- Change notification appearance
- Add custom navigation
- Handle custom notification types

## Troubleshooting

### Notifications not showing
1. Check if user is authenticated
2. Verify API endpoints are correct
3. Check network connectivity
4. Verify Laravel backend is sending notifications with `database` channel

### Unread count not updating
1. Check polling is running (should start automatically)
2. Verify API response format matches expected structure
3. Check authentication token is valid

### Local notifications not appearing
1. Ensure `NotificationService` is initialized
2. Check notification permissions are granted
3. Verify notification channels are created (Android)

## Integration with Existing System

The notification system integrates seamlessly with:
- **Auth System**: Only fetches notifications when user is authenticated
- **Local Notification Service**: Uses existing `NotificationService` for push notifications
- **Navigation**: Can navigate to relevant screens based on notification type

## Next Steps

1. **Add Navigation**: Update `_handleNotificationTap()` in `api_notification_list.dart` to navigate to specific screens
2. **Real-time Updates**: Consider adding WebSocket/Pusher integration for real-time notifications
3. **Notification Preferences**: Add user settings for notification types
4. **Notification History**: Add filtering and search functionality

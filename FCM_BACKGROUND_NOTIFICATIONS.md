# FCM Background Notifications Setup

This guide explains how to make notifications work when the Flutter app is closed using Firebase Cloud Messaging (FCM).

## How It Works

1. **When App is Open**: Notifications are fetched via API polling every 30 seconds
2. **When App is Closed/Background**: FCM push notifications are sent from Laravel backend
3. **When Notification Arrives**: Local notification is shown even when app is closed
4. **When App Opens**: Notification list is automatically refreshed

## Flutter Side (Already Configured ✅)

The Flutter app is already set up to:
- ✅ Handle FCM background messages
- ✅ Show local notifications for API notification types (appointment, prescription, invoice, etc.)
- ✅ Refresh notification list when app opens
- ✅ Handle notification taps

## Laravel Backend Setup

To make notifications work when the app is closed, you need to:

### 1. Install FCM Package in Laravel

```bash
composer require laravel-notification-channels/fcm
```

### 2. Configure FCM in Laravel

Add to your `.env`:
```env
FCM_SERVER_KEY=your_firebase_server_key
FCM_SENDER_ID=your_firebase_sender_id
```

### 3. Store FCM Tokens

Create a migration to store FCM tokens:

```php
php artisan make:migration create_fcm_tokens_table
```

```php
Schema::create('fcm_tokens', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->onDelete('cascade');
    $table->string('token')->unique();
    $table->string('platform')->nullable(); // 'android' or 'ios'
    $table->timestamps();
});
```

### 4. Create FCM Token Endpoint

In your Laravel API, create an endpoint to save FCM tokens:

```php
// routes/api.php
Route::post('/fcm-token', [FCMController::class, 'store'])->middleware('auth:sanctum');
```

```php
// app/Http/Controllers/FCMController.php
public function store(Request $request)
{
    $request->validate([
        'token' => 'required|string',
        'platform' => 'nullable|string|in:android,ios',
    ]);

    $user = $request->user();
    
    // Delete old token if exists
    $user->fcmTokens()->where('token', $request->token)->delete();
    
    // Save new token
    $user->fcmTokens()->create([
        'token' => $request->token,
        'platform' => $request->platform ?? 'android',
    ]);

    return response()->json(['message' => 'Token saved']);
}
```

### 5. Update Notification Classes to Send FCM

Modify your notification classes to send FCM push notifications:

```php
// app/Notifications/AppointmentCreated.php
public function via($notifiable)
{
    $channels = ['database']; // Always save to database
    
    // Add FCM if user has FCM tokens
    if ($notifiable->fcmTokens()->exists()) {
        $channels[] = 'fcm';
    }
    
    // Add email if enabled
    if (config('app.NOTIFICATION_EMAIL', false)) {
        $channels[] = 'mail';
    }
    
    return $channels;
}

public function toFcm($notifiable)
{
    return FcmMessage::create()
        ->setNotification(
            Notification::create()
                ->setTitle('Nouveau rendez-vous')
                ->setBody($this->appointment->message ?? 'Votre rendez-vous a été programmé')
        )
        ->setData([
            'type' => 'appointment_created',
            'appointment_id' => (string) $this->appointment->id,
            'message' => $this->appointment->message ?? '',
            'doctor_name' => $this->appointment->doctor->name ?? '',
            'patient_name' => $this->appointment->patient->name ?? '',
            'notification_id' => '', // Will be set by Laravel
        ]);
}
```

### 6. Send FCM to All User Tokens

Create a service to send to all user tokens:

```php
// app/Services/FCMNotificationService.php
use LaravelFCM\Message\Topics;
use LaravelFCM\Facades\FCM;

class FCMNotificationService
{
    public function sendToUser($user, $notification)
    {
        $tokens = $user->fcmTokens()->pluck('token')->toArray();
        
        if (empty($tokens)) {
            return;
        }

        $fcmMessage = $notification->toFcm($user);
        
        // Send to all user's devices
        $downstreamResponse = FCM::sendTo($tokens, null, $fcmMessage->getNotification(), $fcmMessage->getData());
        
        // Remove invalid tokens
        $this->deleteInvalidTokens($user, $downstreamResponse);
    }
    
    private function deleteInvalidTokens($user, $downstreamResponse)
    {
        $invalidTokens = $downstreamResponse->tokensToDelete();
        if (!empty($invalidTokens)) {
            $user->fcmTokens()->whereIn('token', $invalidTokens)->delete();
        }
    }
}
```

### 7. Update Notification Service

Modify your `NotificationService` to send FCM:

```php
// app/Services/NotificationService.php
use App\Services\FCMNotificationService;

public function send(User $user, $notification, array $channels = ['database'])
{
    try {
        $user->notify($notification);
        
        // Also send FCM if user has tokens
        $fcmService = app(FCMNotificationService::class);
        $fcmService->sendToUser($user, $notification);
        
        Log::info('Notification sent', [
            'user_id' => $user->id,
            'type' => get_class($notification),
        ]);
    } catch (\Exception $e) {
        Log::error('Failed to send notification', [
            'user_id' => $user->id,
            'error' => $e->getMessage(),
        ]);
    }
}
```

## FCM Message Data Format

When sending FCM notifications from Laravel, include these data fields:

```php
[
    'type' => 'appointment_created', // or 'prescription', 'invoice', etc.
    'appointment_id' => '123', // or prescription_id, invoice_id
    'message' => 'Notification message',
    'title' => 'Notification title',
    'doctor_name' => 'Dr. Name', // optional
    'patient_name' => 'Patient Name', // optional
    'notification_id' => 'uuid', // optional
]
```

## Testing

1. **Get FCM Token**: Check Flutter logs for `[FCM] FCM Token: ...`
2. **Save Token**: The token should be automatically saved to backend (implement `_saveTokenToBackend` in `fcm_service.dart`)
3. **Send Test Notification**: Create a notification in Laravel and verify it's sent via FCM
4. **Close App**: Close the app completely
5. **Send Notification**: Create a notification from Laravel backend
6. **Verify**: You should receive a push notification even when app is closed

## Troubleshooting

### Notifications not working when app is closed

1. **Check FCM Configuration**: Verify `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is configured
2. **Check Permissions**: Ensure notification permissions are granted
3. **Check FCM Token**: Verify token is saved in backend
4. **Check Laravel Logs**: Verify FCM messages are being sent
5. **Check Firebase Console**: Verify messages are being delivered

### Token not being saved

Implement the `_saveTokenToBackend` method in `fcm_service.dart` to save tokens to your Laravel backend.

## Next Steps

1. Implement FCM token saving endpoint in Laravel
2. Update notification classes to send FCM
3. Test with app closed
4. Monitor Firebase Console for delivery status

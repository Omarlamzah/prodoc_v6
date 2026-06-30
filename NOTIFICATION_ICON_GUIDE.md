# Notification Icon Setup Guide

## Problem
Notifications were showing the default Flutter logo instead of a custom app icon.

## Solution
I've created a custom notification icon and updated the notification service to use it.

## What Was Changed

1. **Created Notification Icon**: `android/app/src/main/res/drawable/ic_notification.xml`
   - White/transparent icon (required for Android 5.0+)
   - Simple bell icon design

2. **Updated Notification Service**: All notification icons now use `@drawable/ic_notification` instead of `@mipmap/ic_launcher`

## Customizing the Notification Icon

### Option 1: Use Your App Logo (Recommended)

1. **Create a white/transparent version of your app icon**
   - Must be white or transparent (Android requirement)
   - Simple design (works best at small sizes)
   - Recommended size: 24x24dp

2. **Convert to Vector Drawable** (best option)
   - Use Android Studio: Right-click drawable folder → New → Vector Asset
   - Or use online converter: https://inloop.github.io/svg2android/

3. **Or use PNG images** (alternative)
   - Create white PNG icons in different densities:
     - `drawable-mdpi/ic_notification.png` (18x18px)
     - `drawable-hdpi/ic_notification.png` (24x24px)
     - `drawable-xhdpi/ic_notification.png` (36x36px)
     - `drawable-xxhdpi/ic_notification.png` (48x48px)
     - `drawable-xxxhdpi/ic_notification.png` (72x72px)

4. **Update the icon reference** in `notification_service.dart`:
   ```dart
   icon: '@drawable/ic_notification', // Already updated
   ```

### Option 2: Use Healthcare Icon

I've also created `ic_notification_healthcare.xml` with a medical cross icon. To use it:

1. Rename the file or update the reference:
   ```dart
   icon: '@drawable/ic_notification_healthcare',
   ```

### Option 3: Create Custom Vector Icon

Edit `android/app/src/main/res/drawable/ic_notification.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <!-- Your custom white icon path here -->
    <path
        android:fillColor="#FFFFFF"
        android:pathData="..."/>
</vector>
```

## Icon Requirements

### Android
- **Color**: Must be white (#FFFFFF) or transparent
- **Format**: Vector drawable (XML) or PNG
- **Size**: 24x24dp recommended
- **Background**: Android will add colored background based on `color` property

### iOS
- Uses app icon automatically
- No special configuration needed
- Can customize in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## Testing

1. **Rebuild the app**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Send a test notification**:
   - Create a notification from your app
   - Check if the custom icon appears instead of Flutter logo

3. **Verify on different Android versions**:
   - Android 5.0+: White icon on colored background
   - Older versions: May show colored icon

## Current Icon

The current icon is a simple bell (notification icon). You can:
- Keep it as is
- Replace with your app logo (white version)
- Use the healthcare cross icon
- Create a custom icon

## Troubleshooting

### Icon not showing
1. **Check file exists**: Verify `ic_notification.xml` is in `drawable` folder
2. **Rebuild app**: Run `flutter clean` and rebuild
3. **Check reference**: Ensure `@drawable/ic_notification` is used (not `@mipmap`)

### Icon appears colored instead of white
- Android 5.0+ requires white icons
- Make sure your icon is white (#FFFFFF) or transparent
- Android will add the colored background automatically

### Icon too small/large
- Adjust `android:width` and `android:height` in XML
- For PNG, ensure correct sizes for each density

## Quick Fix: Use App Logo

If you want to use your app logo:

1. Create a white version of your logo
2. Convert to vector drawable or PNG
3. Replace `ic_notification.xml` or add PNG files
4. Rebuild app

The notification icon will now show your custom icon instead of the Flutter logo!

# Google Play READ_MEDIA Permissions - Final Solution

## Problem Summary
Google Play continues to detect `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` permissions in the app bundle, even though we have:
1. Explicitly removed them in `AndroidManifest.xml` with `tools:node="remove"`
2. Created a Gradle script to post-process manifests
3. Verified the app uses system photo picker on Android 13+

## Root Cause
The `image_picker` Flutter package (version 1.0.7) declares these permissions in its own `AndroidManifest.xml`. Even with `tools:node="remove"`, the Android manifest merger may still include them in certain scenarios, especially when they're declared by library dependencies.

## Current Implementation Status

### ✅ What We've Done
1. **Manifest Removal**: Added `tools:node="remove"` directives in main manifest
2. **Gradle Script**: Created `remove_media_permissions.gradle` to post-process manifests
3. **System Photo Picker**: App uses `ImageSource.gallery` which automatically uses system photo picker on Android 13+
4. **Legacy Support**: Uses `READ_EXTERNAL_STORAGE` with `maxSdkVersion="32"` for Android < 13

### ⚠️ Why Google Play Still Detects Them
Google Play's scanning system analyzes the **final AAB file**, including:
- All merged manifests from dependencies
- Binary-compiled manifest in the AAB
- Deep scanning of the app bundle structure

Even if we remove them from the source manifest, if a dependency declares them, Google Play may still flag them.

## Recommended Solutions

### Option 1: Appeal to Google Play (RECOMMENDED)
Since we're using the system photo picker and these permissions are not actually needed:

1. **In Google Play Console**, when submitting:
   - Select "Think this is incorrect?"
   - Explain: "Our app uses the Android system photo picker (API 33+) which does not require READ_MEDIA_* permissions. For Android < 13, we use READ_EXTERNAL_STORAGE with maxSdkVersion=32. The permissions detected are from the image_picker Flutter package dependency, but our app does not use them at runtime."

2. **Provide Evidence**:
   - Our manifest explicitly removes these permissions
   - We use `ImageSource.gallery` which uses system photo picker
   - No runtime permission requests for READ_MEDIA_*

### Option 2: Update image_picker Package
Check if a newer version of `image_picker` doesn't declare these permissions, or use a fork that removes them.

### Option 3: Use Alternative Package
Consider switching to a photo picker package that doesn't declare these permissions, such as:
- `photo_manager` (with proper configuration)
- A custom implementation using Android's PhotoPicker API directly

### Option 4: Post-Process AAB (Advanced)
Create a script that:
1. Extracts the AAB
2. Modifies the binary manifest using `aapt2` or similar tools
3. Re-packages the AAB

This is complex and may break signature verification.

## Current Configuration

### AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" 
                 tools:node="remove" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" 
                 tools:node="remove" />
```

### Code Usage
```dart
final ImagePicker picker = ImagePicker();
final XFile? image = await picker.pickImage(
  source: ImageSource.gallery,  // Uses system photo picker on Android 13+
  imageQuality: 85,
);
```

## Next Steps

1. **Immediate**: Submit an appeal in Google Play Console explaining the situation
2. **Short-term**: Check for `image_picker` updates or alternatives
3. **Long-term**: Consider migrating to a package that doesn't declare these permissions

## Version Information
- Current Version: 1.0.18+28
- Flutter: Latest
- image_picker: ^1.0.7
- Target SDK: 34 (Android 14)
- Min SDK: 21 (Android 5.0)

## References
- [Google Play Photo Permissions Policy](https://support.google.com/googleplay/android-developer/answer/9888170)
- [Android Photo Picker](https://developer.android.com/training/data-storage/shared/photopicker)
- [Flutter image_picker](https://pub.dev/packages/image_picker)

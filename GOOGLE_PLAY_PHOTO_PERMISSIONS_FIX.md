# Google Play Photo and Video Permissions Fix

## Issue
Google Play detected `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` permissions in the app, which violates the policy for apps with one-time or infrequent photo/video access.

## Solution Implemented

### 1. Manifest Configuration
The app explicitly removes these permissions in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" tools:node="remove" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" tools:node="remove" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" tools:node="remove" />
```

### 2. System Photo Picker Usage
ProDoc uses the `image_picker` Flutter package with `ImageSource.gallery`, which:
- **Automatically uses the system photo picker on Android 13+ (API 33+)** without requiring `READ_MEDIA_IMAGES` or `READ_MEDIA_VIDEO` permissions
- Falls back to `READ_EXTERNAL_STORAGE` on Android < 13 (with `maxSdkVersion="32"`)

### 3. Permission Usage
- **Camera**: Used only when user explicitly chooses to take a photo (`ImageSource.camera`)
- **Gallery/Photo Picker**: Used only when user explicitly chooses to select a photo/video (`ImageSource.gallery`)
- **No background access**: The app never accesses photos/videos in the background
- **No automatic sharing**: Photos/videos are only accessed after explicit user action

### 4. Use Cases
The app uses photo/video selection in the following scenarios:
1. **Patient profile photo**: User selects a photo to set as patient profile picture
2. **Medical record attachments**: User selects photos/documents to attach to medical records
3. **Appointment attachments**: User selects photos to attach to appointments
4. **Cabinet settings**: User selects logo/favicon images for cabinet customization

All these use cases are **one-time, user-initiated actions** that use the system photo picker.

## Google Play Console Declaration

### READ_MEDIA_IMAGES
```
ProDoc utilise READ_MEDIA_IMAGES uniquement lorsque l'utilisateur choisit d'importer une photo de profil ou un document médical. Aucun accès en arrière-plan ni partage automatique : les images sont ouvertes seulement après une action explicite.
```

### READ_MEDIA_VIDEO
```
ProDoc utilise READ_MEDIA_VIDEO uniquement lorsque l'utilisateur sélectionne une vidéo à importer dans l'application. Aucun accès en arrière-plan : les vidéos ne sont consultées qu'après une action explicite de l'utilisateur.
```

## Technical Details

### Android Version Support
- **Android 13+ (API 33+)**: Uses system photo picker (no permissions needed)
- **Android 12 and below**: Uses `READ_EXTERNAL_STORAGE` (declared with `maxSdkVersion="32"`)

### Code Implementation
The app uses `ImagePicker` from `image_picker` package:
```dart
final ImagePicker picker = ImagePicker();
final XFile? image = await picker.pickImage(
  source: ImageSource.gallery,  // Uses system photo picker on Android 13+
  imageQuality: 85,
);
```

### Build Configuration
The `build.gradle` file is configured to ensure these permissions are not included in the final APK/AAB.

## Verification
After building the app, verify that these permissions are not present:
```bash
# Check merged manifest
./gradlew processReleaseManifest
# Or use aapt2 to check the final APK/AAB
aapt2 dump permissions app-release.aab | grep READ_MEDIA
```

## References
- [Google Play Photo and Video Permissions Policy](https://support.google.com/googleplay/android-developer/answer/9888170)
- [Android Photo Picker](https://developer.android.com/training/data-storage/shared/photopicker)
- [Flutter image_picker package](https://pub.dev/packages/image_picker)

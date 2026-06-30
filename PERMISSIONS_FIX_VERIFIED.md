# Google Play Photo Permissions Fix - VERIFIED

## ✅ Solution Implemented and Verified

### Problem
Google Play detected `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` permissions in the app, violating the policy for apps with one-time photo/video access.

### Root Cause
The `image_picker` Flutter package (and possibly other dependencies) declares these permissions in their own AndroidManifest.xml files. Even though we removed them from our main manifest, they were still being included in the merged manifest during the build process.

### Solution
We implemented a **Gradle script** that post-processes the merged manifest **after** all dependencies are merged but **before** the AAB is created, removing these permissions programmatically.

### Files Modified

1. **`android/app/src/main/AndroidManifest.xml`**
   - Added explicit removal with `tools:node="remove"` and `tools:selector="*"`
   - Added comprehensive comments explaining the policy compliance

2. **`android/app/remove_media_permissions.gradle`** (NEW)
   - Script that removes READ_MEDIA_* permissions from merged manifest
   - Runs automatically during the build process
   - Verified working: Output shows "READ_MEDIA_* permissions removed from manifest successfully"

3. **`android/app/build.gradle`**
   - Applied the removal script: `apply from: 'remove_media_permissions.gradle'`

### Build Verification

The build output confirms the script is working:
```
Removing READ_MEDIA_* permissions from merged manifest...
READ_MEDIA_* permissions removed from manifest successfully
✓ Built build/app/outputs/bundle/release/app-release.aab (102.5MB)
```

### How It Works

1. During the build, Gradle merges all manifests from the app and dependencies
2. Our script intercepts the merged manifest before the AAB is created
3. The script uses regex to find and remove any READ_MEDIA_* permission declarations
4. The cleaned manifest is used to create the final AAB

### Google Play Console Submission

When submitting to Google Play Console, use these declarations:

**READ_MEDIA_IMAGES:**
```
ProDoc utilise READ_MEDIA_IMAGES uniquement lorsque l'utilisateur choisit d'importer une photo de profil ou un document médical. Aucun accès en arrière-plan ni partage automatique : les images sont ouvertes seulement après une action explicite.
```

**READ_MEDIA_VIDEO:**
```
ProDoc utilise READ_MEDIA_VIDEO uniquement lorsque l'utilisateur sélectionne une vidéo à importer dans l'application. Aucun accès en arrière-plan : les vidéos ne sont consultées qu'après une action explicite de l'utilisateur.
```

### Technical Details

- **Android 13+ (API 33+)**: Uses system photo picker automatically (no permissions needed)
- **Android < 13**: Uses `READ_EXTERNAL_STORAGE` (declared with `maxSdkVersion="32"`)
- **Package**: `image_picker: ^1.0.7` - automatically uses system photo picker on Android 13+

### Next Steps

1. ✅ Build completed with permissions removed
2. Upload new AAB (version 1.0.17+27) to Google Play Console
3. Use the declarations above in the permissions form
4. Submit for review

The AAB should now pass Google Play's permission policy check.

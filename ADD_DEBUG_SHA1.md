# Add Debug SHA-1 Fingerprint to Firebase

## Issue
The `google-services.json` file doesn't have your debug keystore SHA-1 fingerprint, which is required for Google Sign-In to work in debug mode.

## Your Debug SHA-1 Fingerprint
```
BA:CC:94:F0:98:4F:FF:DE:52:AD:D5:91:88:07:84:F5:3B:D2:17:41
```

## Steps to Add SHA-1

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **nextpital**
3. Click the gear icon ⚙️ → **Project Settings**
4. Scroll down to **Your apps** section
5. Find your Android app: **com.nextpital.prodoc**
6. Click **Add fingerprint**
7. Paste this SHA-1:
   ```
   BA:CC:94:F0:98:4F:FF:DE:52:AD:D5:91:88:07:84:F5:3B:D2:17:41
   ```
8. Click **Save**

## After Adding SHA-1

1. Wait a few minutes for Firebase to update
2. Go back to Firebase Console → Project Settings → Your Android App
3. Click **Download google-services.json**
4. Replace the file in your project:
   ```bash
   cp ~/Downloads/google-services.json /home/nextpital/Desktop/hms/apps/prodocv4/android/app/google-services.json
   cp ~/Downloads/google-services.json /home/nextpital/Desktop/hms/apps/prodocv4/google-services.json
   ```
5. Rebuild:
   ```bash
   cd /home/nextpital/Desktop/hms/apps/prodocv4
   flutter clean
   flutter pub get
   flutter run
   ```

## Verify
After adding SHA-1, the new `google-services.json` should have a `certificate_hash` that matches:
- `bacc94f0984fffde52add591880784f53bd21741` (lowercase, no colons)

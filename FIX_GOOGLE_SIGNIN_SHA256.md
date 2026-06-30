# Fix Google Sign-In SHA-256 Fingerprint Issue

## Problem
The SHA-256 fingerprint registered in Firebase doesn't match your debug keystore, causing "Account reauth failed" error.

## Current Debug SHA-256 Fingerprint
```
BA:92:20:5A:BE:C5:2D:D2:AB:BA:83:71:BE:65:B9:1C:8C:8B:04:B3:C8:75:0D:75:11:ED:6D:79:6C:21:56:3F
```

## Steps to Fix

### 1. Add SHA-256 to Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **nextpital**
3. Click the gear icon ⚙️ → **Project Settings**
4. Scroll down to **Your apps** section
5. Find your Android app: **com.nextpital.prodoc**
6. Click **Add fingerprint**
7. Paste this SHA-256:
   ```
   BA:92:20:5A:BE:C5:2D:D2:AB:BA:83:71:BE:65:B9:1C:8C:8B:04:B3:C8:75:0D:75:11:ED:6D:79:6C:21:56:3F
   ```
8. Click **Save**

### 2. Re-download google-services.json
1. Still in Firebase Console → Project Settings
2. Scroll to **Your apps** → Android app
3. Click **Download google-services.json**
4. Replace the file in your project:
   - `/home/nextpital/Desktop/hms/apps/prodocv4/android/app/google-services.json`
   - `/home/nextpital/Desktop/hms/apps/prodocv4/google-services.json`

### 3. Rebuild and Test
```bash
cd /home/nextpital/Desktop/hms/apps/prodocv4
flutter clean
flutter pub get
flutter run
```

## Verify
After adding the SHA-256, the `certificate_hash` in the new `google-services.json` should match:
- Expected: `ba92205abec52dd2abba8371be65b91c8c8b04b3c8750d7511ed6d796c21563f` (lowercase, no colons)

## Note
- This is the **debug** keystore SHA-256
- For production, you'll also need to add the **release** keystore SHA-256
- Run `./android/get_release_sha1.sh` to get the release SHA-256

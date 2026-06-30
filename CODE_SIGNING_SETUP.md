# iOS Code Signing Setup Guide

## Current Status
✅ **Privacy Manifest Issue: FIXED** - The build archives successfully
❌ **Code Signing Issue: Needs Setup** - Certificates/profiles not being found

## What You Need

For iOS code signing in Codemagic, you need:

1. **Distribution Certificate (.p12 file)**
   - Contains both certificate and private key
   - The `.cer` file you downloaded is NOT enough - you need the private key

2. **Provisioning Profile (.mobileprovision file)**
   - App Store distribution profile for bundle ID `com.nextpital.prodoc`
   - Must match your Distribution certificate

## Option 1: Manual Upload (Recommended if API key doesn't work)

### Step 1: Export Certificate as .p12 (on a Mac)

1. Open **Keychain Access** on your Mac
2. Find your Distribution certificate: **"omar lamzah"**
3. Right-click → **Export "omar lamzah"**
4. Choose format: **Personal Information Exchange (.p12)**
5. Save it (e.g., `distribution.p12`)
6. **IMPORTANT**: Set a password when prompted - you'll need this
7. Keep the password secure - you'll enter it in Codemagic

### Step 2: Download Provisioning Profile

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/profiles/list)
2. Click **Profiles** → **+** (Create new profile)
3. Select **App Store** distribution
4. Select App ID: **com.nextpital.prodoc**
5. Select your Distribution certificate: **"omar lamzah"**
6. Name it (e.g., "Prodoc App Store Profile")
7. Download the `.mobileprovision` file

### Step 3: Upload to Codemagic

1. Go to [Codemagic UI](https://codemagic.io)
2. Select your app: **prodocv3**
3. Go to **Settings** → **Code signing**
4. Upload:
   - **Certificate**: Your `distribution.p12` file
   - **Certificate password**: The password you set when exporting
   - **Provisioning profile**: Your `.mobileprovision` file
5. Save

Codemagic will automatically use these files for code signing.

## Option 2: Fix API Key Automatic Code Signing

If you want to use automatic code signing via API key:

1. **Verify API Key Permissions**:
   - Go to [App Store Connect](https://appstoreconnect.apple.com) → Users and Access → Keys
   - Find your API key: **myappkey_admin_forcodemajic**
   - Ensure it has:
     - ✅ Admin access
     - ✅ Certificate Management permission
     - ✅ App Manager permission

2. **Verify Bundle ID Exists**:
   - Go to [App Store Connect](https://appstoreconnect.apple.com) → My Apps
   - Ensure app with bundle ID **com.nextpital.prodoc** exists
   - If not, create it

3. **Verify Codemagic Integration**:
   - Go to Codemagic UI → Integrations → App Store Connect
   - Verify **myappkey_admin_forcodemajic** is correctly configured

## Current Files

- ✅ `distribution.cer` - Certificate file (needs to be converted to .p12 with private key)
- ❌ `.p12` file - Not yet created (needs Mac + Keychain Access)
- ❌ `.mobileprovision` file - Not yet downloaded

## Next Steps

1. **If you have access to a Mac**:
   - Export certificate as .p12 from Keychain Access
   - Download provisioning profile from Apple Developer
   - Upload both to Codemagic UI

2. **If you don't have access to a Mac**:
   - Ask someone with a Mac to export the .p12 file for you
   - Or use Codemagic's automatic code signing (fix API key permissions)

## Testing

After setting up code signing (either manual or automatic), trigger a new build in Codemagic. The build should now:
1. ✅ Create privacy manifests (already working)
2. ✅ Archive successfully (already working)
3. ✅ Sign the app with your certificate (should work after setup)

## Troubleshooting

If code signing still fails:
- Check Codemagic build logs for specific error messages
- Verify certificate hasn't expired (yours expires 2027/01/09)
- Ensure provisioning profile matches bundle ID exactly
- Check that certificate and profile are for the same team (JT4YJSSV45)

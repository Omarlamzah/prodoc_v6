# Xcode App Store Upload Guide

## ✅ Xcode Project Status

Your Xcode project is **ready** for App Store submission!

### Current Configuration
- ✅ **Bundle ID**: `com.nextpital.prodoc`
- ✅ **Team ID**: `JT4YJSSV45`
- ✅ **Code Signing**: Manual
- ✅ **Provisioning Profile**: "my prov profile Prodoc App Store Distr"
- ✅ **Code Sign Identity**: iPhone Distribution
- ✅ **Deployment Target**: iOS 15.6

## 📋 Step-by-Step Guide to Upload via Xcode

### Step 1: Open Xcode Project

The workspace should already be open. If not:
```bash
open ios/Runner.xcworkspace
```

**Important**: Always open `.xcworkspace`, NOT `.xcodeproj` (because of CocoaPods)

### Step 2: Verify Code Signing Settings

1. In Xcode, select the **Runner** project in the left sidebar
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Verify:
   - ✅ **Team**: Should show your team (JT4YJSSV45)
   - ✅ **Provisioning Profile**: Should show "my prov profile Prodoc App Store Distr"
   - ✅ **Bundle Identifier**: `com.nextpital.prodoc`

**If provisioning profile is missing:**
- Click the dropdown next to "Provisioning Profile"
- Select "my prov profile Prodoc App Store Distr"
- If it's not listed, you may need to download it from Apple Developer Portal

### Step 3: Select Generic iOS Device

1. At the top of Xcode, next to the Run/Stop buttons
2. Click the device selector (currently shows a simulator)
3. Select **"Any iOS Device (arm64)"** or **"Generic iOS Device"**

**Important**: You cannot archive for App Store using a simulator. Must use "Generic iOS Device" or a physical device.

### Step 4: Create Archive

1. In Xcode menu: **Product** → **Archive**
2. Wait for the build to complete (this may take several minutes)
3. The **Organizer** window will open automatically when done

**If you see build errors:**
- Check that all privacy manifests are created (they should be)
- Verify code signing settings
- Check Xcode build log for specific errors

### Step 5: Validate Archive

Before uploading, validate the archive:

1. In the **Organizer** window, select your archive
2. Click **"Validate App"**
3. Follow the wizard:
   - Select your team
   - Wait for validation to complete
   - Fix any issues if validation fails

**Common validation issues:**
- Missing privacy manifests (should be fixed)
- Code signing errors (check certificates)
- Missing app icons or screenshots (for App Store Connect)

### Step 6: Upload to App Store Connect

1. In the **Organizer** window, select your archive
2. Click **"Distribute App"**
3. Select **"App Store Connect"**
4. Click **"Next"**
5. Choose **"Upload"** (not "Export")
6. Click **"Next"**
7. Select your distribution options:
   - ✅ **Include bitcode**: NO (already configured)
   - ✅ **Upload symbols**: YES (recommended for crash reports)
8. Click **"Next"**
9. Review the summary
10. Click **"Upload"**
11. Wait for upload to complete

### Step 7: Monitor Upload

- Xcode will show upload progress
- You can check App Store Connect for the build status
- It may take 10-30 minutes to process

## 🔧 Troubleshooting

### Issue: "No provisioning profile found"

**Solution:**
1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/profiles/list)
2. Download the App Store distribution profile for `com.nextpital.prodoc`
3. Double-click to install in Xcode
4. Or manually copy to: `~/Library/MobileDevice/Provisioning Profiles/`

### Issue: "Code signing failed"

**Solution:**
1. Check that your distribution certificate is installed in Keychain
2. Verify the certificate hasn't expired
3. Ensure the provisioning profile matches the certificate
4. In Xcode: Preferences → Accounts → Select your Apple ID → Download Manual Profiles

### Issue: "Privacy manifest not found"

**Solution:**
The privacy manifests should already be created. If you see this error:
1. Run the privacy manifest creation script:
   ```bash
   cd /Users/user253899/Desktop/prodocv3-master
   bash create_all_privacy_final.sh
   ```
2. Clean build folder: Product → Clean Build Folder (Shift+Cmd+K)
3. Try archiving again

### Issue: Build fails with "Multiple commands produce"

**Solution:**
This was already fixed. If it appears again:
1. Clean build folder: Product → Clean Build Folder
2. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
3. Try archiving again

## 📱 After Upload

Once uploaded to App Store Connect:

1. **Go to App Store Connect**: https://appstoreconnect.apple.com
2. **Select your app**: ProDoc (com.nextpital.prodoc)
3. **Go to TestFlight** tab (if using TestFlight)
4. **Or go to App Store** tab to submit for review

### App Store Connect Checklist

Before submitting for review, ensure you have:

- [ ] App information (name, description, keywords)
- [ ] App icon (1024x1024)
- [ ] Screenshots for all required device sizes:
  - iPhone 6.7" (iPhone 14 Pro Max, etc.)
  - iPhone 6.5" (iPhone 11 Pro Max, etc.)
  - iPhone 5.5" (iPhone 8 Plus, etc.)
  - iPad Pro 12.9" (if supporting iPad)
- [ ] Privacy policy URL (if required)
- [ ] Age rating
- [ ] Category selection
- [ ] Pricing information

## 🎯 Quick Reference

### Xcode Keyboard Shortcuts
- **Clean Build Folder**: `Shift + Cmd + K`
- **Archive**: `Product → Archive` (no shortcut)
- **Build**: `Cmd + B`
- **Run**: `Cmd + R`

### Important Paths
- **Provisioning Profiles**: `~/Library/MobileDevice/Provisioning Profiles/`
- **DerivedData**: `~/Library/Developer/Xcode/DerivedData/`
- **Archives**: `~/Library/Developer/Xcode/Archives/`

### Current Project Info
- **Bundle ID**: `com.nextpital.prodoc`
- **Team ID**: `JT4YJSSV45`
- **App Name**: ProDoc
- **Version**: 1.0.10+18
- **Build Number**: 18

## ✅ Summary

Your project is configured and ready! Just follow these steps:

1. ✅ Open Xcode workspace
2. ✅ Select "Generic iOS Device"
3. ✅ Product → Archive
4. ✅ Validate App
5. ✅ Distribute App → App Store Connect
6. ✅ Upload

Good luck with your App Store submission! 🚀

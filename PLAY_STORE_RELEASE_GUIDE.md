# Play Store Release Guide

This guide will help you create and upload a new release to Google Play Store.

## 🚀 Quick Start

### Option 1: Automated Release (Recommended)

```bash
./create_release.sh
```

This script will:
1. ✅ Check your configuration
2. 📝 Bump the version number
3. 📋 Create release notes template
4. 🧹 Clean previous builds
5. 📦 Get dependencies
6. 🔍 Analyze code
7. 🔨 Build release AAB file
8. 📤 Provide upload instructions

### Option 2: Manual Steps

1. **Update Version**
   ```bash
   # Edit pubspec.yaml and update version
   version: 1.0.12+22  # Format: version_name+build_number
   ```

2. **Build Release**
   ```bash
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```

3. **Upload to Play Store**
   - Go to [Google Play Console](https://play.google.com/console)
   - Navigate to your app
   - Go to **Production** > **Create new release**
   - Upload `build/app/outputs/bundle/release/app-release.aab`
   - Add release notes
   - Review and publish

## 📋 Version Numbering

- **Version Name** (e.g., 1.0.12): User-visible version
  - Format: `MAJOR.MINOR.PATCH`
  - Major: Breaking changes
  - Minor: New features
  - Patch: Bug fixes

- **Version Code** (e.g., 22): Internal build number
  - Must be incremented for each release
  - Must be higher than previous releases

## 📝 Release Notes Template

When creating a release, include:

```markdown
## What's New

### New Features
- Feature 1
- Feature 2

### Bug Fixes
- Fixed issue with...
- Resolved crash when...

### Improvements
- Improved performance
- Enhanced UI/UX
```

## ✅ Pre-Release Checklist

- [ ] Version number updated in `pubspec.yaml`
- [ ] Code tested thoroughly
- [ ] All features working
- [ ] No critical bugs
- [ ] Release notes prepared
- [ ] App bundle built successfully
- [ ] Keystore configured correctly

## 🔐 Keystore Configuration

Make sure `android/key.properties` is configured:

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=upload
storeFile=upload-keystore.jks
```

## 📱 Upload to Play Store

1. **Sign in** to [Google Play Console](https://play.google.com/console)
2. **Select your app**
3. **Go to Production** (or Testing track)
4. **Click "Create new release"**
5. **Upload AAB file**: `build/app/outputs/bundle/release/app-release.aab`
6. **Add release notes** from the generated `RELEASE_NOTES_*.md` file
7. **Review** all information
8. **Save** and **Start rollout**

## 🐛 Troubleshooting

### Build Fails
- Check `android/key.properties` exists
- Verify keystore file path is correct
- Ensure all dependencies are up to date

### Upload Fails
- Verify version code is higher than previous release
- Check AAB file size (max 150MB)
- Ensure all required permissions are declared

### Version Conflicts
- Version code must be unique and increasing
- Version name can be the same, but code must change

## 📚 Additional Resources

- [Flutter Release Documentation](https://docs.flutter.dev/deployment/android)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Android App Bundle Guide](https://developer.android.com/guide/app-bundle)

# Fix Privacy Manifest Issue in Codemagic UI Workflow

## Problem
When using the **Default Workflow** (UI-based) instead of `codemagic.yaml`, the privacy manifest files aren't being created before Xcode checks for them.

## Solution: Add Pre-Build Script

### Step 1: Commit the Script to GitHub

The script `ios/create_privacy_manifests_pre_build.sh` is already created. Make sure it's committed:

```bash
git add ios/create_privacy_manifests_pre_build.sh
git commit -m "Add privacy manifest pre-build script for UI workflow"
git push
```

### Step 2: Add Script Step in Codemagic UI

1. **Go to Codemagic**:
   - https://codemagic.io
   - Your App (prodocv3) → **Settings** → **Workflow settings** (or **Build settings**)

2. **Find "Build scripts" or "Pre-build scripts" section**

3. **Add a new script step** (before "Building iOS"):
   - **Name**: `Create privacy manifests`
   - **Script**:
     ```bash
     cd $CM_BUILD_DIR
     bash ios/create_privacy_manifests_pre_build.sh
     ```

4. **Save**

### Step 3: Verify Script Order

Make sure the script runs **BEFORE** the "Building iOS" step. The order should be:
1. ✅ Installing dependencies
2. ✅ **Create privacy manifests** ← Add this
3. ✅ Building iOS

### Step 4: Trigger New Build

After adding the script, trigger a new build. The privacy manifest error should be fixed!

## Alternative: If You Can't Add Script Step

If the UI doesn't allow adding custom scripts, you can:

### Option A: Use the YAML Workflow Instead

The `codemagic.yaml` file already has all the fixes. Switch back to using the YAML workflow:
- In Codemagic UI → Your App → **Settings** → **Workflow**
- Select **iOS Workflow** (from YAML) instead of **Default Workflow**

### Option B: Modify Podfile to Run Script Automatically

The Podfile already tries to create these files, but we can make it more aggressive. However, since you're using the UI workflow, the script step is the best solution.

## What the Script Does

The script creates privacy manifest files in these locations:
- ✅ `DerivedData/Runner-*/.../UninstalledProducts/iphoneos/` (for archive builds)
- ✅ `build/ios/Release-iphoneos/` (for regular builds)
- ✅ `ios/Pods/` (so they're part of the project)

This ensures Xcode finds the files when it checks for build inputs.

## Current Status

- ✅ Code signing: **WORKING** (certificates and profiles are being fetched)
- ❌ Privacy manifests: **FAILING** (need to add pre-build script)

After adding the script step, both should work! 🎉

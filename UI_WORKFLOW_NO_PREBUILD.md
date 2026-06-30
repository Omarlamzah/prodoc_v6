# Fix Privacy Manifests in UI Workflow (No Pre-Build Script Available)

## Problem
The Codemagic UI workflow only shows:
- ❌ Post-build script (too late - runs after build)
- ❌ Pre-publish script (too late - runs after build)

But we need a **pre-build script** to create privacy manifests before Xcode checks for them.

## Solution: Use Pre-Publish Script + Enhanced Podfile

Since we can't add a pre-build script, we'll:
1. **Make Podfile create files automatically** (already done)
2. **Use Pre-publish script as backup** (won't fix current build, but helps verify)
3. **Switch to YAML workflow** (recommended - has all fixes)

## Option 1: Switch to YAML Workflow (RECOMMENDED ✅)

The `codemagic.yaml` already has all the privacy manifest fixes:

1. **Codemagic UI** → Your App → **Settings** → **Workflow**
2. Select **"iOS Workflow"** (from YAML) instead of **"Default Workflow"**
3. **Trigger new build** - Should work! ✅

This is the **easiest and most reliable** solution.

## Option 2: Use Pre-Publish Script (Workaround)

If you must use the UI workflow, add this to the **Pre-publish script**:

```bash
#!/bin/sh
set -e
set -x

# This runs AFTER build, so it won't fix the current error
# But it helps verify files are created for next build
echo "Creating privacy manifests (post-build verification)..."

PACKAGES="url_launcher_ios sqflite_darwin"

DERIVED_DATA_BASE="$HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$DERIVED_DATA_BASE" ]; then
  for runner_dir in "$DERIVED_DATA_BASE"/Runner-*; do
    if [ -d "$runner_dir" ]; then
      uninstalled_dir="${runner_dir}/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/UninstalledProducts/iphoneos"
      mkdir -p "$uninstalled_dir"
      for pkg in $PACKAGES; do
        BUNDLE_DIR="${uninstalled_dir}/${pkg}_privacy.bundle"
        mkdir -p "$BUNDLE_DIR"
        touch "${BUNDLE_DIR}/${pkg}_privacy"
        chmod 644 "${BUNDLE_DIR}/${pkg}_privacy"
      done
    fi
  done
fi
```

**Note**: This won't fix the current build error, but it prepares files for the next build.

## Option 3: Check "Installing dependencies" Section

In Codemagic UI, check if there's a way to add custom scripts to the **"Installing dependencies"** phase. If so, add:

```bash
bash ios/create_privacy_manifests_pre_build.sh
```

## Why Podfile Script Phases Might Not Work

The Podfile adds script phases to the Xcode project, but:
- They might not run early enough
- Xcode creates a NEW DerivedData directory during archive with a unique hash
- The Podfile can't predict that hash

## Best Solution: Use YAML Workflow

The YAML workflow (`codemagic.yaml`) has:
- ✅ Pre-build script to create privacy manifests
- ✅ All code signing fixes
- ✅ Proper script ordering

**Just switch to it!** It's already configured and tested.

## Current Status

- ✅ Code signing: **WORKING** (certificates fetched correctly)
- ❌ Privacy manifests: **FAILING** (need pre-build script, but UI doesn't support it)

**Recommendation**: Switch to YAML workflow - it's the simplest solution! 🎯

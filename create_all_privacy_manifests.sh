#!/bin/bash
# Create privacy manifests for all packages that need them

BUILD_DIR="build/ios/Debug-iphonesimulator"
DERIVED_DATA_BASE="$HOME/Library/Developer/Xcode/DerivedData"

# List of known packages that need privacy manifests
PACKAGES="url_launcher_ios sqflite_darwin shared_preferences_foundation path_provider_foundation flutter_secure_storage flutter_local_notifications share_plus permission_handler_apple file_picker_ios image_picker_ios camera_avfoundation google_sign_in_ios record_ios"

create_manifest() {
  local pkg=$1
  local base_dir=$2
  
  if [ -z "$pkg" ] || [ -z "$base_dir" ]; then
    return 0
  fi
  
  BUNDLE_DIR="${base_dir}/${pkg}/${pkg}_privacy.bundle"
  MANIFEST_FILE="${BUNDLE_DIR}/${pkg}_privacy"
  
  mkdir -p "$BUNDLE_DIR" 2>/dev/null || true
  touch "$MANIFEST_FILE" 2>/dev/null || true
  chmod 644 "$MANIFEST_FILE" 2>/dev/null || true
  
  if [ -f "$MANIFEST_FILE" ]; then
    echo "✓ Created: $MANIFEST_FILE"
    return 0
  fi
  return 1
}

# Create in build directory
if [ -d "$BUILD_DIR" ] || mkdir -p "$BUILD_DIR" 2>/dev/null; then
  echo "Creating manifests in: $BUILD_DIR"
  for pkg in $PACKAGES; do
    create_manifest "$pkg" "$BUILD_DIR"
  done
fi

# Create in all DerivedData locations
if [ -d "$DERIVED_DATA_BASE" ]; then
  for runner_dir in "$DERIVED_DATA_BASE"/Runner-*; do
    if [ -d "$runner_dir" ]; then
      # Debug-iphonesimulator
      debug_dir="${runner_dir}/Build/Products/Debug-iphonesimulator"
      if [ -d "$debug_dir" ] || mkdir -p "$debug_dir" 2>/dev/null; then
        for pkg in $PACKAGES; do
          create_manifest "$pkg" "$debug_dir"
        done
      fi
      
      # Release-iphonesimulator
      release_dir="${runner_dir}/Build/Products/Release-iphonesimulator"
      if [ -d "$release_dir" ] || mkdir -p "$release_dir" 2>/dev/null; then
        for pkg in $PACKAGES; do
          create_manifest "$pkg" "$release_dir"
        done
      fi
    fi
  done
fi

echo "Privacy manifest creation complete!"

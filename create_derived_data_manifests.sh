#!/bin/bash
# Create privacy manifests in all DerivedData locations

DERIVED_DATA_BASE="$HOME/Library/Developer/Xcode/DerivedData"
PACKAGES=(
  "flutter_secure_storage_darwin:flutter_secure_storage.bundle/flutter_secure_storage"
  "nanopb:nanopb_Privacy.bundle/nanopb_Privacy"
  "SwiftyGif:SwiftyGif.bundle/SwiftyGif"
  "SDWebImage:SDWebImage.bundle/SDWebImage"
  "firebase_messaging:firebase_messaging_Privacy.bundle/firebase_messaging_Privacy"
)

create_manifest() {
  local pkg=$1
  local manifest_path=$2
  local base_dir=$3
  
  if [ -z "$pkg" ] || [ -z "$manifest_path" ] || [ -z "$base_dir" ]; then
    return 0
  fi
  
  full_path="${base_dir}/${pkg}/${manifest_path}"
  mkdir -p "$(dirname "$full_path")" 2>/dev/null || true
  touch "$full_path" 2>/dev/null || true
  chmod 644 "$full_path" 2>/dev/null || true
  
  if [ -f "$full_path" ]; then
    echo "✓ Created: $full_path"
    return 0
  fi
  return 1
}

# Create in all DerivedData Runner-* directories
if [ -d "$DERIVED_DATA_BASE" ]; then
  for runner_dir in "$DERIVED_DATA_BASE"/Runner-*; do
    if [ -d "$runner_dir" ]; then
      # Debug-iphonesimulator
      debug_dir="${runner_dir}/Build/Products/Debug-iphonesimulator"
      if [ -d "$debug_dir" ] || mkdir -p "$debug_dir" 2>/dev/null; then
        for pkg_info in "${PACKAGES[@]}"; do
          pkg="${pkg_info%%:*}"
          manifest="${pkg_info##*:}"
          create_manifest "$pkg" "$manifest" "$debug_dir"
        done
      fi
      
      # Release-iphonesimulator
      release_dir="${runner_dir}/Build/Products/Release-iphonesimulator"
      if [ -d "$release_dir" ] || mkdir -p "$release_dir" 2>/dev/null; then
        for pkg_info in "${PACKAGES[@]}"; do
          pkg="${pkg_info%%:*}"
          manifest="${pkg_info##*:}"
          create_manifest "$pkg" "$manifest" "$release_dir"
        done
      fi
    fi
  done
fi

# Also create in build directory
BUILD_DIR="build/ios/Debug-iphonesimulator"
if [ -d "$BUILD_DIR" ] || mkdir -p "$BUILD_DIR" 2>/dev/null; then
  for pkg_info in "${PACKAGES[@]}"; do
    pkg="${pkg_info%%:*}"
    manifest="${pkg_info##*:}"
    create_manifest "$pkg" "$manifest" "$BUILD_DIR"
  done
fi

echo "Privacy manifest creation complete!"

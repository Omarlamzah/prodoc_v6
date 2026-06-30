#!/bin/bash
# Automatically find and create all privacy manifests needed

BUILD_DIR="build/ios/Debug-iphonesimulator"
DERIVED_DATA_BASE="$HOME/Library/Developer/Xcode/DerivedData"

# Find all packages that have privacy bundle targets in Pods
find ios/Pods -name "*_privacy.bundle" -o -name "*_Privacy.bundle" 2>/dev/null | while read bundle_path; do
  # Extract package and bundle names
  pkg_dir=$(dirname "$bundle_path" | xargs basename)
  bundle_name=$(basename "$bundle_path" | sed 's/\.bundle$//')
  
  # Create in build directory
  manifest_dir="${BUILD_DIR}/${pkg_dir}/${bundle_name}.bundle"
  manifest_file="${manifest_dir}/${bundle_name}"
  mkdir -p "$manifest_dir" 2>/dev/null
  touch "$manifest_file" 2>/dev/null
  chmod 644 "$manifest_file" 2>/dev/null
  echo "Created: $manifest_file"
done

# Also create for known packages with special naming
declare -a special_packages=(
  "PromisesObjC:FBLPromises_Privacy.bundle/FBLPromises_Privacy"
  "flutter_secure_storage_darwin:flutter_secure_storage.bundle/flutter_secure_storage"
  "firebase_messaging:firebase_messaging_Privacy.bundle/firebase_messaging_Privacy"
  "nanopb:nanopb_Privacy.bundle/nanopb_Privacy"
  "SwiftyGif:SwiftyGif.bundle/SwiftyGif"
  "SDWebImage:SDWebImage.bundle/SDWebImage"
)

for pkg_info in "${special_packages[@]}"; do
  pkg="${pkg_info%%:*}"
  manifest="${pkg_info##*:}"
  manifest_path="${BUILD_DIR}/${pkg}/${manifest}"
  mkdir -p "$(dirname "$manifest_path")" 2>/dev/null
  touch "$manifest_path" 2>/dev/null
  chmod 644 "$manifest_path" 2>/dev/null
  echo "Created: $manifest_path"
done

echo "Privacy manifest creation complete!"

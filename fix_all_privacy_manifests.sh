#!/bin/bash
# Comprehensive script to create ALL privacy manifests

BUILD_DIR="build/ios/Debug-iphonesimulator"
mkdir -p "$BUILD_DIR"

create_manifest() {
  local pkg=$1
  local bundle_name=$2
  local manifest_name=$3
  
  if [ -z "$pkg" ] || [ -z "$bundle_name" ] || [ -z "$manifest_name" ]; then
    return 0
  fi
  
  manifest_dir="${BUILD_DIR}/${pkg}/${bundle_name}.bundle"
  manifest_file="${manifest_dir}/${manifest_name}"
  mkdir -p "$manifest_dir" 2>/dev/null
  touch "$manifest_file" 2>/dev/null
  chmod 644 "$manifest_file" 2>/dev/null
  if [ -f "$manifest_file" ]; then
    echo "✓ Created: $manifest_file"
  fi
}

# Find all privacy bundles in Pods
find ios/Pods -type d -name "*_privacy.bundle" -o -name "*_Privacy.bundle" 2>/dev/null | while read bundle_dir; do
  pkg_dir=$(dirname "$bundle_dir" | xargs basename)
  bundle_name=$(basename "$bundle_dir" | sed 's/\.bundle$//')
  create_manifest "$pkg_dir" "$bundle_name" "$bundle_name"
done

# Known packages with special naming
create_manifest "PromisesObjC" "FBLPromises_Privacy" "FBLPromises_Privacy"
create_manifest "GoogleUtilities" "GoogleUtilities_Privacy" "GoogleUtilities_Privacy"
create_manifest "GoogleToolboxForMac" "GoogleToolboxForMac_Privacy" "GoogleToolboxForMac_Privacy"
create_manifest "GoogleToolboxForMac" "GoogleToolboxForMac_Logger_Privacy" "GoogleToolboxForMac_Logger_Privacy"
create_manifest "MLKitTextRecognition" "LatinOCRResources" "LatinOCRResources"
create_manifest "flutter_secure_storage_darwin" "flutter_secure_storage" "flutter_secure_storage"
create_manifest "firebase_messaging" "firebase_messaging_Privacy" "firebase_messaging_Privacy"
create_manifest "nanopb" "nanopb_Privacy" "nanopb_Privacy"
create_manifest "SwiftyGif" "SwiftyGif" "SwiftyGif"
create_manifest "SDWebImage" "SDWebImage" "SDWebImage"

echo "All privacy manifests created!"

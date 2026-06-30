#!/bin/bash
# Automatically create all privacy manifests based on build errors

BUILD_DIR="build/ios/Debug-iphonesimulator"
mkdir -p "$BUILD_DIR"

# Find all packages that might need privacy manifests by checking Pods
if [ -d "ios/Pods" ]; then
  find ios/Pods -name "*_privacy.bundle" -o -name "*_Privacy.bundle" | while read bundle_path; do
    # Extract package name and bundle name
    pkg_dir=$(dirname "$bundle_path" | xargs basename)
    bundle_name=$(basename "$bundle_path" | sed 's/\.bundle$//')
    
    # Create the privacy manifest
    manifest_dir="${BUILD_DIR}/${pkg_dir}/${bundle_name}.bundle"
    manifest_file="${manifest_dir}/${bundle_name}"
    
    mkdir -p "$manifest_dir"
    touch "$manifest_file"
    chmod 644 "$manifest_file"
    echo "Created: $manifest_file"
  done
fi

# Also create for known packages with different naming
declare -A special_packages=(
  ["flutter_secure_storage_darwin"]="flutter_secure_storage.bundle/flutter_secure_storage"
  ["firebase_messaging"]="firebase_messaging_Privacy.bundle/firebase_messaging_Privacy"
  ["nanopb"]="nanopb_Privacy.bundle/nanopb_Privacy"
)

for pkg in "${!special_packages[@]}"; do
  manifest_path="${BUILD_DIR}/${pkg}/${special_packages[$pkg]}"
  mkdir -p "$(dirname "$manifest_path")"
  touch "$manifest_path"
  chmod 644 "$manifest_path"
  echo "Created: $manifest_path"
done

echo "Privacy manifest fix complete!"

#!/bin/bash
# Comprehensive script to create ALL privacy manifests by parsing Pods project

BUILD_DIR="build/ios/Debug-iphonesimulator"
mkdir -p "$BUILD_DIR"

# Extract all privacy bundle target names from Pods project
grep -oE 'PBXNativeTarget.*name = "[^"]*[-_]privacy[-_]bundle[^"]*"|PBXNativeTarget.*name = "[^"]*[-_]Privacy[-_]bundle[^"]*"' ios/Pods/Pods.xcodeproj/project.pbxproj 2>/dev/null | \
  sed 's/.*name = "\([^"]*\)".*/\1/' | \
  sort -u | while read target_name; do
  
  # Extract package and bundle names
  if [[ "$target_name" == *"-"* ]]; then
    pkg="${target_name%%-*}"
    bundle="${target_name#*-}"
  elif [[ "$target_name" == *"_"* ]]; then
    # Find the last underscore before privacy
    pkg="${target_name%_privacy*}"
    pkg="${pkg%_Privacy*}"
    bundle="${target_name#${pkg}_}"
  else
    pkg="${target_name%_privacy*}"
    pkg="${pkg%_Privacy*}"
    bundle="$target_name"
  fi
  
  # Remove .bundle suffix if present
  bundle="${bundle%.bundle}"
  
  # Create manifest
  manifest_dir="${BUILD_DIR}/${pkg}/${bundle}.bundle"
  manifest_file="${manifest_dir}/${bundle}"
  mkdir -p "$manifest_dir" 2>/dev/null
  touch "$manifest_file" 2>/dev/null
  chmod 644 "$manifest_file" 2>/dev/null
  echo "Created: $manifest_file (from $target_name)"
done

# Also find resource bundles that might need privacy manifests
grep -oE 'PBXResourcesBuildPhase.*[Rr]esources|\.bundle' ios/Pods/Pods.xcodeproj/project.pbxproj 2>/dev/null | head -20

# Create for known resource bundles
for pkg in "DKPhotoGallery" "MLKitTextRecognition" "MLKitFaceDetection"; do
  for bundle in "${pkg}" "${pkg}_Resources" "${pkg}Resources"; do
    manifest_dir="${BUILD_DIR}/${pkg}/${bundle}.bundle"
    manifest_file="${manifest_dir}/${bundle}"
    mkdir -p "$manifest_dir" 2>/dev/null
    touch "$manifest_file" 2>/dev/null
    chmod 644 "$manifest_file" 2>/dev/null
    echo "Created: $manifest_file"
  done
done

echo "Comprehensive privacy manifest creation complete!"

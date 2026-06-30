#!/bin/bash
# Parse xcscheme files to find all privacy bundles and create manifests

BUILD_DIR="build/ios/Debug-iphonesimulator"
mkdir -p "$BUILD_DIR"

# Parse xcscheme files to extract package and bundle names
find ios/Pods/Pods.xcodeproj/xcshareddata/xcschemes -name "*.xcscheme" 2>/dev/null | while read scheme_file; do
  # Extract target name from scheme file name (format: Package-BundleName.xcscheme)
  scheme_name=$(basename "$scheme_file" .xcscheme)
  
  # Split on dash or underscore to get package and bundle
  if [[ "$scheme_name" == *"-"* ]]; then
    pkg="${scheme_name%%-*}"
    bundle="${scheme_name#*-}"
  elif [[ "$scheme_name" == *"_"* ]]; then
    pkg="${scheme_name%%_*}"
    bundle="${scheme_name#*_}"
  else
    pkg="$scheme_name"
    bundle="$scheme_name"
  fi
  
  # Create manifest
  manifest_dir="${BUILD_DIR}/${pkg}/${bundle}.bundle"
  manifest_file="${manifest_dir}/${bundle}"
  mkdir -p "$manifest_dir" 2>/dev/null
  touch "$manifest_file" 2>/dev/null
  chmod 644 "$manifest_file" 2>/dev/null
  echo "Created: $manifest_file (from $scheme_name)"
done

# Also check xcuserdata schemes
find ios/Pods/Pods.xcodeproj/xcuserdata -name "*privacy*.xcscheme" -o -name "*Privacy*.xcscheme" 2>/dev/null | while read scheme_file; do
  scheme_name=$(basename "$scheme_file" .xcscheme)
  
  # Extract package and bundle from scheme name
  if [[ "$scheme_name" == *"-"* ]]; then
    pkg="${scheme_name%%-*}"
    bundle="${scheme_name#*-}"
  else
    pkg="${scheme_name%_*}"
    bundle="${scheme_name#*_}"
  fi
  
  manifest_dir="${BUILD_DIR}/${pkg}/${bundle}.bundle"
  manifest_file="${manifest_dir}/${bundle}"
  mkdir -p "$manifest_dir" 2>/dev/null
  touch "$manifest_file" 2>/dev/null
  chmod 644 "$manifest_file" 2>/dev/null
  echo "Created: $manifest_file (from user scheme $scheme_name)"
done

echo "Privacy manifest creation from schemes complete!"

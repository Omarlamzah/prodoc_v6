#!/bin/bash
# Create privacy manifests for ALL bundle targets found in Pods

BUILD_DIR="build/ios/Debug-iphonesimulator"
mkdir -p "$BUILD_DIR"

# Find all bundle target names from Pods project
grep -oE 'name = "[^"]*"' ios/Pods/Pods.xcodeproj/project.pbxproj 2>/dev/null | \
  sed 's/name = "\([^"]*\)"/\1/' | \
  grep -iE '(bundle|privacy|resources)' | \
  sort -u | while read target_name; do
  
  # Skip if it's not a bundle or privacy target
  if [[ ! "$target_name" =~ (bundle|Bundle|privacy|Privacy|Resources|resources) ]]; then
    continue
  fi
  
  # Extract package name (everything before the last dash/underscore before bundle/privacy)
  if [[ "$target_name" == *"-"* ]]; then
    pkg="${target_name%%-*}"
    bundle="${target_name#*-}"
  elif [[ "$target_name" == *"_"* ]]; then
    # Try to find package name
    pkg="${target_name%_*}"
    bundle="${target_name#*_}"
  else
    pkg="${target_name%.bundle*}"
    pkg="${pkg%_bundle*}"
    pkg="${pkg%_Bundle*}"
    bundle="$target_name"
  fi
  
  # Remove .bundle suffix
  bundle="${bundle%.bundle}"
  
  # Create manifest
  manifest_dir="${BUILD_DIR}/${pkg}/${bundle}.bundle"
  manifest_file="${manifest_dir}/${bundle}"
  mkdir -p "$manifest_dir" 2>/dev/null
  touch "$manifest_file" 2>/dev/null
  chmod 644 "$manifest_file" 2>/dev/null
  echo "Created: $manifest_file"
done

echo "All bundle privacy manifests created!"

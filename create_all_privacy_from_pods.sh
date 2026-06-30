#!/bin/bash
# Find ALL privacy bundles from Pods and create manifests

BUILD_DIR="build/ios/Debug-iphonesimulator"
mkdir -p "$BUILD_DIR"

# Find all privacy-related targets in Pods project
if [ -f "ios/Pods/Pods.xcodeproj/project.pbxproj" ]; then
  # Extract all privacy bundle targets
  grep -oE '[A-Za-z0-9_-]+[_-]privacy[_-]bundle|[A-Za-z0-9_-]+[_-]Privacy[_-]bundle|[A-Za-z0-9_-]+[_-]privacy\.bundle|[A-Za-z0-9_-]+[_-]Privacy\.bundle' ios/Pods/Pods.xcodeproj/project.pbxproj 2>/dev/null | sort -u | while read target_name; do
    # Extract package name (remove _privacy, _Privacy, .bundle suffixes)
    pkg=$(echo "$target_name" | sed 's/[-_]privacy[-_]bundle$//i' | sed 's/[-_]Privacy[-_]bundle$//i' | sed 's/\.bundle$//i')
    bundle_name="$target_name"
    
    if [ -n "$pkg" ] && [ "$pkg" != "$bundle_name" ]; then
      manifest_dir="${BUILD_DIR}/${pkg}/${bundle_name}.bundle"
      manifest_file="${manifest_dir}/${bundle_name}"
      mkdir -p "$manifest_dir" 2>/dev/null
      touch "$manifest_file" 2>/dev/null
      chmod 644 "$manifest_file" 2>/dev/null
      echo "Created: $manifest_file"
    fi
  done
fi

# Also check for specific patterns in Podfile.lock
grep -i "privacy" ios/Podfile.lock 2>/dev/null | grep -oE '[A-Za-z0-9_-]+' | sort -u | while read pkg; do
  # Try common privacy bundle patterns
  for pattern in "${pkg}_privacy" "${pkg}_Privacy" "${pkg}-privacy" "${pkg}-Privacy"; do
    manifest_dir="${BUILD_DIR}/${pkg}/${pattern}.bundle"
    manifest_file="${manifest_dir}/${pattern}"
    mkdir -p "$manifest_dir" 2>/dev/null
    touch "$manifest_file" 2>/dev/null
    chmod 644 "$manifest_file" 2>/dev/null
  done
done

echo "Privacy manifest scan complete!"

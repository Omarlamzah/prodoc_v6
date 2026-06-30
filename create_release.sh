#!/bin/bash

# ProDoc - Complete Release Script for Play Store
# This script bumps version, builds release, and prepares for Play Store upload

set -e  # Exit on error

echo "🚀 ProDoc - Play Store Release Script"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if key.properties exists
if [ ! -f "android/key.properties" ]; then
    print_error "key.properties file not found!"
    echo ""
    echo "Please follow these steps:"
    echo "1. Generate a keystore:"
    echo "   keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload"
    echo ""
    echo "2. Copy the template:"
    echo "   cp android/key.properties.template android/key.properties"
    echo ""
    echo "3. Edit android/key.properties with your keystore information"
    echo ""
    exit 1
fi

# Check if keystore file exists
KEYSTORE_FILE=$(grep "storeFile=" android/key.properties | cut -d'=' -f2)
if [ ! -f "android/$KEYSTORE_FILE" ]; then
    print_error "Keystore file not found: android/$KEYSTORE_FILE"
    echo "Please check your key.properties file"
    exit 1
fi

print_success "Configuration found"
echo ""

# Read current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
CURRENT_VERSION_NAME=$(echo $CURRENT_VERSION | cut -d'+' -f1)
CURRENT_VERSION_CODE=$(echo $CURRENT_VERSION | cut -d'+' -f2)

print_info "Current version: $CURRENT_VERSION_NAME+$CURRENT_VERSION_CODE"
echo ""

# Ask user for version type
echo "What type of version bump?"
echo "1) Patch (1.0.11 -> 1.0.12) - Bug fixes, small improvements"
echo "2) Minor (1.0.11 -> 1.1.0) - New features, enhancements"
echo "3) Major (1.0.11 -> 2.0.0) - Major changes, breaking updates"
echo "4) Custom - Enter version manually"
echo ""
read -p "Choose option (1-4): " choice

case $choice in
    1)
        # Patch version bump
        IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION_NAME"
        MAJOR=${VERSION_PARTS[0]}
        MINOR=${VERSION_PARTS[1]}
        PATCH=${VERSION_PARTS[2]}
        NEW_PATCH=$((PATCH + 1))
        NEW_VERSION_NAME="$MAJOR.$MINOR.$NEW_PATCH"
        NEW_VERSION_CODE=$((CURRENT_VERSION_CODE + 1))
        ;;
    2)
        # Minor version bump
        IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION_NAME"
        MAJOR=${VERSION_PARTS[0]}
        MINOR=${VERSION_PARTS[1]}
        NEW_MINOR=$((MINOR + 1))
        NEW_VERSION_NAME="$MAJOR.$NEW_MINOR.0"
        NEW_VERSION_CODE=$((CURRENT_VERSION_CODE + 1))
        ;;
    3)
        # Major version bump
        IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION_NAME"
        MAJOR=${VERSION_PARTS[0]}
        NEW_MAJOR=$((MAJOR + 1))
        NEW_VERSION_NAME="$NEW_MAJOR.0.0"
        NEW_VERSION_CODE=$((CURRENT_VERSION_CODE + 1))
        ;;
    4)
        read -p "Enter new version name (e.g., 1.0.12): " NEW_VERSION_NAME
        read -p "Enter new version code (current: $CURRENT_VERSION_CODE): " NEW_VERSION_CODE
        if [ -z "$NEW_VERSION_CODE" ]; then
            NEW_VERSION_CODE=$((CURRENT_VERSION_CODE + 1))
        fi
        ;;
    *)
        print_error "Invalid choice. Exiting."
        exit 1
        ;;
esac

NEW_VERSION="$NEW_VERSION_NAME+$NEW_VERSION_CODE"

echo ""
print_info "New version will be: $NEW_VERSION"
read -p "Confirm? (y/n): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    print_warning "Cancelled."
    exit 0
fi

# Update pubspec.yaml
echo ""
print_info "📝 Updating version in pubspec.yaml..."
sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
print_success "Version updated to $NEW_VERSION"

# Create release notes file
echo ""
print_info "📝 Creating release notes template..."
RELEASE_NOTES_FILE="RELEASE_NOTES_${NEW_VERSION_NAME}.md"
cat > "$RELEASE_NOTES_FILE" << EOF
# Release Notes - Version $NEW_VERSION_NAME

## 🎉 What's New

### ✨ New Features
- [Add new features here]

### 🐛 Bug Fixes
- [Add bug fixes here]

### 🔧 Improvements
- [Add improvements here]

### 📱 Changes
- [Add other changes here]

---

**Version:** $NEW_VERSION_NAME  
**Version Code:** $NEW_VERSION_CODE  
**Release Date:** $(date +"%Y-%m-%d")  
**Build Type:** Release

## 📋 Testing Checklist

- [ ] App builds successfully
- [ ] All features tested
- [ ] No critical bugs
- [ ] Performance verified
- [ ] Play Store metadata updated

## 📤 Upload Instructions

1. Go to Google Play Console
2. Navigate to your app
3. Go to Production > Create new release
4. Upload: \`build/app/outputs/bundle/release/app-release.aab\`
5. Add release notes from this file
6. Review and publish

EOF

print_success "Release notes created: $RELEASE_NOTES_FILE"

# Clean previous builds
echo ""
print_info "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo ""
print_info "📦 Getting dependencies..."
flutter pub get

# Analyze code
echo ""
print_info "🔍 Analyzing code..."
flutter analyze || print_warning "Code analysis found some issues. Review them before releasing."

# Build app bundle
echo ""
print_info "🔨 Building release app bundle (AAB) for Play Store..."
flutter build appbundle --release

if [ $? -eq 0 ]; then
    echo ""
    print_success "Build successful!"
    echo ""
    echo "📦 Release Information:"
    echo "   Version Name: $NEW_VERSION_NAME"
    echo "   Version Code: $NEW_VERSION_CODE"
    echo "   App Bundle: build/app/outputs/bundle/release/app-release.aab"
    echo "   Release Notes: $RELEASE_NOTES_FILE"
    echo ""
    echo "📤 Next Steps for Play Store:"
    echo "   1. Review release notes: $RELEASE_NOTES_FILE"
    echo "   2. Go to Google Play Console"
    echo "   3. Navigate to: Production > Create new release"
    echo "   4. Upload: build/app/outputs/bundle/release/app-release.aab"
    echo "   5. Copy release notes from $RELEASE_NOTES_FILE"
    echo "   6. Review and publish"
    echo ""
    print_success "🎉 Release ready for Play Store!"
else
    echo ""
    print_error "Build failed! Please check the error messages above."
    exit 1
fi

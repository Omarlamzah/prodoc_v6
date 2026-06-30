#!/bin/bash

# ProDoc - Release Build Script
# This script helps you build a release version of your app for Google Play Store

echo "🚀 ProDoc Release Build Script"
echo "================================"
echo ""

# Check if key.properties exists
if [ ! -f "android/key.properties" ]; then
    echo "❌ Error: key.properties file not found!"
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
    echo "❌ Error: Keystore file not found: android/$KEYSTORE_FILE"
    echo "Please check your key.properties file"
    exit 1
fi

echo "✅ Configuration found"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build app bundle
echo "🔨 Building release app bundle (AAB)..."
flutter build appbundle --release

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📦 Your app bundle is located at:"
    echo "   build/app/outputs/bundle/release/app-release.aab"
    echo ""
    echo "📤 Next steps:"
    echo "   1. Go to Google Play Console"
    echo "   2. Upload the AAB file to your app"
    echo "   3. Complete the release process"
    echo ""
    echo "📖 For detailed instructions, see: PLAY_STORE_PUBLICATION_GUIDE.md"
else
    echo ""
    echo "❌ Build failed! Please check the error messages above."
    exit 1
fi


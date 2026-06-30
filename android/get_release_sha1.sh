#!/bin/bash

# Script to get the release keystore SHA-1 and SHA-256 fingerprints
# IMPORTANT: Firebase/Google requires SHA-256 fingerprints, not SHA-1!
# This SHA-256 needs to be added to Firebase/Google Cloud Console for Google Sign-In to work in production

echo "🔑 Getting Release Keystore SHA Fingerprints"
echo "=============================================="
echo "⚠️  IMPORTANT: Firebase/Google requires SHA-256, not SHA-1!"
echo ""

# Check if key.properties exists
if [ ! -f "key.properties" ]; then
    echo "❌ Error: key.properties file not found!"
    echo "Please make sure you're running this from the android/ directory"
    exit 1
fi

# Extract keystore file path and alias from key.properties
KEYSTORE_FILE=$(grep "storeFile=" key.properties | cut -d'=' -f2 | tr -d '\r')
KEY_ALIAS=$(grep "keyAlias=" key.properties | cut -d'=' -f2 | tr -d '\r')

# Resolve the keystore path (handle relative paths)
if [[ "$KEYSTORE_FILE" == ../* ]]; then
    # Relative path - resolve from android directory
    KEYSTORE_PATH="$(dirname "$(pwd)")/${KEYSTORE_FILE#../}"
else
    # Absolute or relative to android directory
    KEYSTORE_PATH="$KEYSTORE_FILE"
fi

echo "📋 Configuration:"
echo "   Keystore: $KEYSTORE_PATH"
echo "   Alias: $KEY_ALIAS"
echo ""

# Check if keystore file exists
if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "❌ Error: Keystore file not found at: $KEYSTORE_PATH"
    echo ""
    echo "Please check:"
    echo "  1. The keystore file exists at the specified path"
    echo "  2. The path in key.properties is correct"
    exit 1
fi

echo "✅ Keystore file found"
echo ""
echo "🔐 Please enter your keystore password when prompted..."
echo ""

# Get SHA-1 and SHA-256 fingerprints
KEYTOOL_OUTPUT=$(keytool -list -v -keystore "$KEYSTORE_PATH" -alias "$KEY_ALIAS" 2>/dev/null)
SHA1=$(echo "$KEYTOOL_OUTPUT" | grep "SHA1:" | sed 's/.*SHA1: //')
SHA256=$(echo "$KEYTOOL_OUTPUT" | grep "SHA256:" | sed 's/.*SHA256: //')

if [ -z "$SHA1" ] || [ -z "$SHA256" ]; then
    echo "❌ Failed to get fingerprint(s)"
    echo "Please check:"
    echo "  1. The keystore password is correct"
    echo "  2. The key alias is correct"
    echo "  3. The keystore file is valid"
    exit 1
fi

echo ""
echo "✅ Fingerprints Retrieved Successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 RELEASE SHA-256 FINGERPRINT (REQUIRED FOR FIREBASE):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$SHA256"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 RELEASE SHA-1 FINGERPRINT (for reference):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$SHA1"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Next Steps:"
echo ""
echo "⚠️  IMPORTANT: Add SHA-256 to Firebase/Google Cloud Console!"
echo ""
echo "Option 1 - Firebase Console (Recommended):"
echo "1. Go to: https://console.firebase.google.com/"
echo "2. Select your project → Project Settings → Your apps → Android app"
echo "3. Scroll to 'SHA certificate fingerprints'"
echo "4. Click '+ Add fingerprint'"
echo "5. Paste the SHA-256 fingerprint above:"
echo "   $SHA256"
echo "6. Click Save"
echo ""
echo "Option 2 - Google Cloud Console:"
echo "1. Go to: https://console.cloud.google.com/"
echo "2. Navigate to: APIs & Services → Credentials"
echo "3. Find your Android OAuth 2.0 Client ID"
echo "4. Click Edit (pencil icon)"
echo "5. Click '+ ADD SHA CERTIFICATE FINGERPRINT'"
echo "6. Paste the SHA-256 fingerprint above"
echo "7. Click Save"
echo ""
echo "⏱️  Wait 5 minutes to 24 hours for changes to propagate"
echo ""
echo "📖 For detailed instructions, see: QUICK_FIX_GOOGLE_SIGNIN.md"
echo ""


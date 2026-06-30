# Step-by-Step: Fix API Key Automatic Code Signing

## Overview
Your certificate was created by an API key, so Codemagic SHOULD be able to fetch it automatically. Let's verify and fix the API key configuration.

## Step 1: Verify API Key in App Store Connect

1. **Go to App Store Connect**:
   - https://appstoreconnect.apple.com
   - Sign in with your Apple Developer account

2. **Navigate to API Keys**:
   - Click **Users and Access** (top menu)
   - Click **Keys** tab
   - Find your API key: **myappkey_admin_forcodemajic** (or the one with Key ID: 87FW8F4TSV)

3. **Check Permissions**:
   - Click on the API key to view details
   - Verify it has:
     - ✅ **Access**: Admin (or at least App Manager)
     - ✅ **Permissions**: 
       - Certificate Management (REQUIRED)
       - App Manager (REQUIRED)
       - Developer (optional)

4. **If permissions are missing**:
   - You may need to create a NEW API key with correct permissions
   - Or contact your Apple Developer account admin to grant permissions

## Step 2: Verify Bundle ID Exists in App Store Connect

1. **Go to My Apps**:
   - https://appstoreconnect.apple.com → **My Apps**

2. **Check if app exists**:
   - Look for app with bundle ID: **com.nextpital.prodoc**
   - If it exists: ✅ Good
   - If it doesn't exist: Create it (click + → New App)

3. **If creating new app**:
   - Platform: iOS
   - Bundle ID: com.nextpital.prodoc
   - Name: Prodoc (or your app name)

## Step 3: Verify Codemagic Integration

1. **Go to Codemagic**:
   - https://codemagic.io
   - Sign in

2. **Check Integrations**:
   - Click your profile (top right) → **Integrations**
   - Or: Settings → Integrations
   - Find: **App Store Connect**

3. **Verify API Key Configuration**:
   - Should see: **myappkey_admin_forcodemajic**
   - Or the name you gave it in Codemagic
   - Check status: Should be ✅ Active/Connected

4. **If integration is missing or broken**:
   - Click **Add integration** or **Edit**
   - You'll need:
     - **Key ID**: 87FW8F4TSV (from App Store Connect)
     - **Issuer ID**: (from App Store Connect → Users and Access → Keys)
     - **Private Key**: Download from App Store Connect (the .p8 file)

5. **To get Private Key (.p8 file)**:
   - App Store Connect → Users and Access → Keys
   - Click your API key
   - Click **Download** next to the key
   - Save the `.p8` file
   - Upload it to Codemagic integration

## Step 4: Update Codemagic Workflow

The configuration is already updated in `codemagic.yaml`. It will:
- Try to fetch certificates automatically
- Try multiple methods
- Show detailed logs

## Step 5: Test the Build

1. **Commit and push** the updated `codemagic.yaml`
2. **Trigger a new build** in Codemagic
3. **Check the logs** for:
   - "Setting up code signing..."
   - "Attempting to fetch signing files from App Store Connect..."
   - Certificate count
   - Profile count

## Step 6: Check Build Logs

Look for these messages in the build logs:

### ✅ Success Indicators:
- "Certificates: 1" (or more)
- "Profiles: 1" (or more)
- "✓ Found certificate(s) for team JT4YJSSV45"

### ❌ Failure Indicators:
- "Certificates: 0"
- "Profiles: 0"
- "⚠ fetch-signing-files failed"
- "No certificates found for team JT4YJSSV45"

## Step 7: If Still Failing

If certificates still aren't being fetched, check the error logs:

1. **In build logs**, look for:
   - `/tmp/fetch_signing.log` output
   - Any error messages about API key
   - Permission denied errors

2. **Common Issues**:
   - API key doesn't have "Certificate Management" permission
   - API key is not linked correctly in Codemagic
   - Bundle ID doesn't exist in App Store Connect
   - Private key (.p8) not uploaded to Codemagic

3. **Next Steps**:
   - Fix the issue based on error logs
   - Or proceed to cloud Mac service (Option 1)
   - Or contact Codemagic support

## Quick Checklist

Before triggering a new build, verify:

- [ ] API key has "Certificate Management" permission
- [ ] API key has "App Manager" permission  
- [ ] API key has "Admin" or "App Manager" access level
- [ ] Bundle ID `com.nextpital.prodoc` exists in App Store Connect
- [ ] Codemagic integration is active and connected
- [ ] Private key (.p8) is uploaded to Codemagic integration
- [ ] Updated `codemagic.yaml` is committed and pushed

## Expected Result

After fixing the API key, when you trigger a build:

1. ✅ Codemagic fetches certificates automatically
2. ✅ Certificates are added to keychain
3. ✅ Profiles are downloaded
4. ✅ Build signs successfully
5. ✅ .ipa file is created

## If This Doesn't Work

If after checking everything the API key still doesn't work:

1. **Contact Codemagic Support**:
   - Email: support@codemagic.io
   - Include: Your app name, team ID, bundle ID, API key name
   - Mention: "Certificate was created by API key but automatic fetching not working"

2. **Or use Cloud Mac Service** (Option 1):
   - ~$1-5 for 1 hour
   - Export .p12 manually
   - Upload to Codemagic UI

3. **Or ask a friend with Mac** (Option 2):
   - Free
   - Takes 2 minutes

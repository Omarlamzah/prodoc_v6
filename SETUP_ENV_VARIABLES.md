# Setup: Use Environment Variables or Repository Files

## Option 1: Use Files from Repository (EASIEST - Already Configured!)

The `codemagic.yaml` is now configured to use files directly from your repository:

✅ **Already in repository:**
- `AuthKey_2SXY3XRQDL.p8` - API key private key
- `Prodoc_Medical_Management_App_ios_app_store_1767979241.mobileprovision` - Provisioning profile

The script will automatically:
1. Use the `.p8` file from repository if integration doesn't work
2. Copy the `.mobileprovision` file to system location
3. Use them for code signing

**Just commit and push these files to GitHub, then trigger a build!**

## Option 2: Set Environment Variables in Codemagic UI

If you want to use environment variables instead:

### Step 1: Get API Key Content

Read the content of `AuthKey_2SXY3XRQDL.p8`:
```bash
cat AuthKey_2SXY3XRQDL.p8
```

Copy the ENTIRE content (including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`)

### Step 2: Set Environment Variables in Codemagic

1. Go to: https://codemagic.io
2. Your App (prodocv3) → **Settings** → **Environment variables**
3. Add these variables:

   **Variable 1:**
   - Name: `APP_STORE_CONNECT_API_KEY_ID`
   - Value: `2SXY3XRQDL`
   - Secure: ✅ Yes

   **Variable 2:**
   - Name: `APP_STORE_CONNECT_ISSUER_ID`
   - Value: `24e51026-b46d-49ab-89ba-d7791751dfd5`
   - Secure: ✅ Yes

   **Variable 3:**
   - Name: `APP_STORE_CONNECT_API_KEY`
   - Value: (paste the ENTIRE content of AuthKey_2SXY3XRQDL.p8)
   - Secure: ✅ Yes (IMPORTANT!)

4. **Save**

## Option 3: Upload Certificate Files to GitHub (If You Get .p12)

If you eventually get the `.p12` file:

1. **Add to repository** (but be careful with security):
   ```bash
   # Add .p12 file (but add password as environment variable)
   git add distribution.p12
   ```

2. **Set password as environment variable**:
   - In Codemagic UI → Environment variables
   - Name: `CERTIFICATE_PASSWORD`
   - Value: (the password you set when exporting)
   - Secure: ✅ Yes

3. **Update codemagic.yaml** to use the .p12 file:
   - The script will automatically find and import it

## Current Configuration

The `codemagic.yaml` is now set up to:
1. ✅ Try Codemagic integration first
2. ✅ Fall back to environment variables
3. ✅ Fall back to repository files (.p8)
4. ✅ Use provisioning profile from repository
5. ✅ Copy provisioning profile to system location

## What to Do Now

### Recommended: Use Repository Files (Easiest)

1. **Commit files to GitHub**:
   ```bash
   git add AuthKey_2SXY3XRQDL.p8
   git add Prodoc_Medical_Management_App_ios_app_store_1767979241.mobileprovision
   git commit -m "Add API key and provisioning profile for code signing"
   git push
   ```

2. **Trigger build in Codemagic**
   - The script will automatically use these files

### Alternative: Set Environment Variables

1. Follow "Option 2" above to set environment variables
2. Commit and push codemagic.yaml
3. Trigger build

## Security Note

⚠️ **Important**: The `.p8` file contains your private key. 

**Options:**
- ✅ **Safe**: Use Codemagic environment variables (encrypted)
- ⚠️ **Less safe**: Store in GitHub (but still works)
- ✅ **Best**: Use Codemagic integration (if it works)

For now, storing in GitHub will work, but consider moving to environment variables later for better security.

## Testing

After setup, check build logs for:
- ✅ "Using .p8 file from repository as fallback"
- ✅ "✓ Loaded API key from repository file"
- ✅ "Certificates: 1" (or more)
- ✅ "Profiles: 1" (or more)

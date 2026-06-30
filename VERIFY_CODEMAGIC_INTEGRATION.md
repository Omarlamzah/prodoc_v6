# Verify Codemagic Integration is Correct

## Critical Check: Integration Name Must Match

The `codemagic.yaml` file references the integration name. This name must **EXACTLY** match what you named it in Codemagic UI.

### Current Configuration:
In `codemagic.yaml` line 19, it says:
```yaml
app_store_connect: prodoc_api_key_admin
```

### What to Check:

1. **Go to Codemagic UI**:
   - https://codemagic.io
   - Your profile → Integrations → App Store Connect

2. **Check the Integration Name**:
   - What name did you give it when you created/edited it?
   - It might be: `prodoc_api_key_admin`, `myappkey_admin_forcodemajic`, or something else

3. **Update codemagic.yaml**:
   - The name in line 19 must **EXACTLY** match the name in Codemagic UI
   - Case-sensitive!

### Example:
If in Codemagic UI you named it: `prodoc_new_key`
Then in codemagic.yaml line 19, change:
```yaml
app_store_connect: prodoc_new_key  # Must match exactly!
```

## Verify Integration is Active

1. In Codemagic UI → Integrations → App Store Connect
2. Check:
   - ✅ Status: "Active" or "Connected"
   - ✅ Key ID: 2R56FU2DCS
   - ✅ Private Key: Uploaded (should show file name or checkmark)
   - ❌ No error messages

## If Integration Shows Errors:

1. **Private Key Missing**:
   - Click "Edit" on the integration
   - Upload: `AuthKey_2R56FU2DCS.p8`
   - Save

2. **Key ID Mismatch**:
   - Verify Key ID is: `2R56FU2DCS`
   - Verify Issuer ID is: `24e51026-b46d-49ab-89ba-d7791751dfd5`

3. **Integration Not Active**:
   - Delete and recreate the integration
   - Make sure all fields are correct
   - Save

## After Verifying:

1. **Update codemagic.yaml** with correct integration name (if different)
2. **Commit and push**
3. **Trigger new build**
4. **Check "Set up code signing" step logs** - should show:
   - ✅ API key environment variables detected
   - ✅ Certificates: 1 (or more)
   - ✅ Profiles: 1 (or more)

## Quick Test:

After updating, the build logs should show in "Set up code signing" step:
```
✓ APP_STORE_CONNECT_API_KEY_ID: 2R56FU2DCS
✓ APP_STORE_CONNECT_ISSUER_ID: 24e51026-b46d-49ab-89ba-d7791751dfd5
✓ APP_STORE_CONNECT_API_KEY is set (private key)
```

If you see "⚠ not set" for any of these, the integration isn't configured correctly.

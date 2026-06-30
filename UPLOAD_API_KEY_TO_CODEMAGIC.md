# Upload New API Key to Codemagic

## Your New API Key Details:
- **Key ID**: 2R56FU2DCS
- **Access**: Admin ✅
- **Issuer ID**: 24e51026-b46d-49ab-89ba-d7791751dfd5
- **Private Key File**: AuthKey_2R56FU2DCS.p8 ✅ (you have this!)

## Step 1: Upload to Codemagic

1. **Go to Codemagic**:
   - https://codemagic.io
   - Sign in

2. **Navigate to Integrations**:
   - Click your profile (top right) → **Integrations**
   - OR: Settings → Integrations

3. **Add/Edit App Store Connect Integration**:
   - Find **App Store Connect** integration
   - Click **Add integration** (if new) or **Edit** (if exists)

4. **Enter API Key Details**:
   - **Name**: `prodoc_api_key_admin` (or any name you want)
   - **Key ID**: `2R56FU2DCS`
   - **Issuer ID**: `24e51026-b46d-49ab-89ba-d7791751dfd5`
   - **Private Key**: Upload the file `AuthKey_2R56FU2DCS.p8`
     - Click "Upload" or "Choose File"
     - Select: `/home/nextpital/Desktop/hms/nextpitalmobileapp/AuthKey_2R56FU2DCS.p8`

5. **Save** the integration

## Step 2: Update codemagic.yaml

After uploading, note the **integration name** you gave it in Codemagic (e.g., `prodoc_api_key_admin`).

Then update `codemagic.yaml` line 19 to use the new integration name.

## Step 3: Verify Integration

After saving, check that:
- ✅ Integration shows as "Active" or "Connected"
- ✅ No error messages
- ✅ Key ID matches: 2R56FU2DCS

## Step 4: Test Build

1. Update `codemagic.yaml` with new integration name
2. Commit and push
3. Trigger new build
4. Check logs - should now fetch certificates successfully!

## Important Notes:

- The integration name in Codemagic UI can be different from the API key name
- Use the **integration name** (what you named it in Codemagic) in `codemagic.yaml`
- The .p8 file must be uploaded - Codemagic needs it to authenticate

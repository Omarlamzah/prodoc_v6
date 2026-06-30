# Quick Guide: Check API Key Right Now

## You're Currently At:
- App Store Connect → Users and Access → **Users** tab

## What You Need To Do:

### Step 1: Go to Keys Tab
1. In the same page (Users and Access), look at the **top tabs**:
   - Personnes (People)
   - Sandbox
   - **Intégrations** (Integrations) ← Click this!
   - Xcode Cloud

2. Click **"Intégrations"** (Integrations) tab

3. Then click **"Clés"** (Keys) sub-tab

### Step 2: Find Your API Key
You should see a list of API keys. Look for:
- **Name**: myappkey_admin_forcodemajic
- **Key ID**: 87FW8F4TSV
- Or any key that says "Admin" access

### Step 3: Check Permissions
Click on the API key to open it, then check:

**Required Permissions:**
- ✅ **Accès** (Access): Admin or Gestionnaire d'apps (App Manager)
- ✅ **Gestion des certificats** (Certificate Management): Must be enabled
- ✅ **Gestionnaire d'apps** (App Manager): Must be enabled

### Step 4: Check Private Key
- Look for a **"Télécharger"** (Download) button
- This downloads the `.p8` private key file
- **IMPORTANT**: This file must be uploaded to Codemagic

## If API Key Doesn't Have Permissions:

1. You may need to **create a new API key** with correct permissions
2. Or you may not have permission to modify API keys (only account holder can)

## What to Look For:

✅ **GOOD**:
- Access: Admin or App Manager
- Certificate Management: ✅ Enabled
- App Manager: ✅ Enabled

❌ **BAD**:
- Access: Developer only
- Certificate Management: ❌ Not enabled
- Missing permissions

## Next Steps After Checking:

1. **If permissions are correct**: 
   - Check Codemagic integration (next step)
   - Trigger a new build

2. **If permissions are missing**:
   - Create new API key with correct permissions
   - Update Codemagic integration with new key

3. **If you can't modify API keys**:
   - You're not the account holder
   - Need account holder to fix permissions
   - Or use cloud Mac service to get .p12 file

## Visual Guide:

```
App Store Connect
└── Users and Access (Utilisateurs et accès)
    ├── Users (Personnes) ← You are here
    ├── Sandbox
    ├── Integrations (Intégrations) ← Click this!
    │   └── Keys (Clés) ← Then this!
    └── Xcode Cloud
```

## After Checking Keys:

Come back and tell me:
1. ✅ Does the API key have "Certificate Management" permission?
2. ✅ Does it have "App Manager" permission?
3. ✅ What is the Access level? (Admin/App Manager/Developer)
4. ✅ Can you download the .p8 private key file?

Then we'll fix the Codemagic integration!

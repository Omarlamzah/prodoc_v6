# Fix YAML Workflow Code Signing

## The Problem
The YAML workflow has a complex manual code signing script that's causing issues. The UI workflow uses Codemagic's **automatic code signing** which works perfectly!

## The Solution
The YAML workflow should use Codemagic's automatic code signing (just like the UI workflow), not manual scripts.

## What to Do

The YAML workflow already has the integration configured:
```yaml
integrations:
  app_store_connect: prodoc_api_key_admin
```

**Codemagic will automatically:**
1. ✅ Use the integration to fetch certificates and profiles
2. ✅ Set up keychain
3. ✅ Configure code signing

**You don't need the manual "Set up code signing" script!**

## Quick Fix

In `codemagic.yaml`, find the "Set up code signing" script (around line 47) and **replace it** with:

```yaml
      # Code signing is handled automatically by Codemagic using the app_store_connect integration
      # The integration 'prodoc_api_key_admin' is configured above
      # Codemagic will automatically fetch certificates and profiles - no manual setup needed!
      
      - name: Create privacy manifests before build
        script: |
          echo "Creating privacy manifest files before build..."
          bash ios/create_privacy_manifests_pre_build.sh
```

**Remove all the old code signing script** (lines 56-306 approximately) - it's trying to do manually what Codemagic does automatically!

## Why This Works

The UI workflow works because it uses Codemagic's automatic code signing. The YAML workflow should do the same - just let Codemagic handle it automatically using the integration.

## Summary

- ✅ **UI workflow**: Uses automatic code signing → **WORKS**
- ❌ **YAML workflow**: Uses manual code signing script → **FAILS**
- ✅ **Fix**: Remove manual script, use automatic code signing → **WILL WORK**

The integration `prodoc_api_key_admin` is already configured, so Codemagic will handle everything automatically!

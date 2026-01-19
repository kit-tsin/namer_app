# Facebook Key Hash Setup Guide

## Your Facebook Key Hash (Base64 Format)

**Use this Base64 hash** (Facebook requires Base64, not hex):
```
cqLH0heinyI4S9IYqDQnXQbTa+k=
```

This has been copied to your clipboard automatically.

## Step-by-Step Instructions

### Method 1: Quick Start (Recommended - Easiest!)

This is the **easiest and most reliable** method:

1. Visit: https://developers.facebook.com/apps/
2. Select your app (App ID: `850045457924806`)
3. In the left sidebar, click **Settings** → **Basic**
4. Scroll down to the **"Android"** section
5. Click the **"Quick Start"** button
6. Follow the step-by-step UI wizard:
   - It will ask for **Package Name**: `com.example.namer_app`
   - It will ask for **Class Name**: `com.example.namer_app.MainActivity`
   - It will have a field for **Key Hashes**: paste `cqLH0heinyI4S9IYqDQnXQbTa+k=`
7. Complete the wizard and save
8. **Wait 2-3 minutes** for Facebook's servers to update
9. **Completely close and restart your app** (not just hot reload)
10. Try Facebook login again

### Method 2: Manual Configuration (Alternative)

If Quick Start is not available:

1. Visit: https://developers.facebook.com/apps/
2. Select your app (App ID: `850045457924806`)
3. In the left sidebar, click **Settings** → **Basic**
4. Scroll down to the bottom of the page
5. Look for the **"Platform"** section
6. If you don't see "Android" listed, click **"+ Add Platform"** button
7. Select **"Android"** from the list
8. Fill in the required fields:
   - **Package Name**: `com.example.namer_app`
   - **Class Name**: `com.example.namer_app.MainActivity`
   - **Key Hashes**: `cqLH0heinyI4S9IYqDQnXQbTa+k=`
9. Click **"Save Changes"** at the bottom of the page
10. **Wait 2-3 minutes** for Facebook's servers to update
11. **Completely close and restart your app** (not just hot reload)
12. Try Facebook login again

## Important Notes

- **Recommended Method**: Use **Quick Start** - it's more reliable than manual entry
- **Format**: Facebook requires Base64 format, NOT the colon-separated hex format
- **Package Name**: Must match exactly: `com.example.namer_app`
- **If Key Hashes field doesn't appear**: Use Quick Start method instead, or make sure you've added Android as a platform first

## Troubleshooting

### "Key Hashes field is not visible"
- Make sure Android platform is added (Step 2)
- Fill in the Package Name field first
- The Key Hashes field should appear after Package Name is filled

### "Still getting key hash error after adding"
- Wait 3-5 minutes for changes to propagate
- Make sure you used the Base64 format (not hex)
- Clear app data: Settings → Apps → Your App → Clear Data
- Uninstall and reinstall the app
- Make sure you're testing on the same device/emulator that generated the key hash

### "Different key hash needed"
- Each computer/emulator has a different debug keystore
- Run `get_facebook_key_hash.ps1` to get the key hash for your current setup
- Add all key hashes you need (you can have multiple)

## For Release Builds

When you create a release build, you'll need to:
1. Generate key hash from your **release keystore** (not debug keystore)
2. Add that key hash to Facebook Developer Console as well

## Quick Command to Get Key Hash Again

Run this script to get the Base64 key hash:
```powershell
powershell -ExecutionPolicy Bypass -File get_facebook_key_hash.ps1
```

The script will:
- Get your current debug key hash
- Convert it to Base64 format
- Copy it to your clipboard automatically

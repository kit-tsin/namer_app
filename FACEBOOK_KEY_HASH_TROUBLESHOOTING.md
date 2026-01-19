# Facebook Key Hash Not Saving - Troubleshooting Guide

## Your Configuration (Verified)
- **Package Name**: `com.example.namer_app` ✅
- **Class Name**: `com.example.namer_app.MainActivity` ✅
- **Key Hash (Base64)**: `cqLH0heinyI4S9IYqDQnXQbTa+k=`

## Common Issues & Solutions

### Issue 1: Key Hash Field Clears After Save

This is a known Facebook Developer Console bug. Try these solutions in order:

#### Solution A: Try Different Browser
1. Open Facebook Developer Console in **Chrome** (if you're using Edge/Firefox)
2. Or try **Edge** (if you're using Chrome)
3. Clear browser cache: `Ctrl+Shift+Delete` → Clear cached images and files
4. Try adding the key hash again

#### Solution B: Check for Validation Errors
1. Before saving, check if there are any **red error messages** on the page
2. Make sure **Package Name** field has no extra spaces: `com.example.namer_app`
3. Make sure **Class Name** field has no extra spaces: `com.example.namer_app.MainActivity`
4. Make sure **Key Hashes** field has no extra spaces before/after the hash

#### Solution C: Enter Hash Without Trailing = (Sometimes Works)
Try entering the hash **without** the trailing `=`:
```
cqLH0heinyI4S9IYqDQnXQbTa+k
```

Then save and check if it persists.

#### Solution D: Use Quick Start Method
1. In Facebook Developer Console, go to **Settings → Basic**
2. Look for **"Quick Start"** button in the Android section
3. Click **"Quick Start"** - this might help configure Android platform properly
4. Then try adding the key hash again

#### Solution E: Remove and Re-add Android Platform
1. Go to **Settings → Basic**
2. Scroll to **Platforms** section
3. Find **Android** and click the **X** or **Remove** button
4. Click **"+ Add Platform"** → Select **Android**
5. Fill in:
   - Package Name: `com.example.namer_app`
   - Class Name: `com.example.namer_app.MainActivity`
   - Key Hashes: `cqLH0heinyI4S9IYqDQnXQbTa+k=`
6. Click **Save Changes**

#### Solution F: Check App Permissions
1. Go to **Settings → Basic**
2. Check your **App Roles** - make sure you have **Administrator** or **Developer** role
3. If you're just a **Tester**, you might not be able to save settings

### Issue 2: Hash Format Verification

Let's verify the hash is in the correct format. The hash should:
- Be Base64 encoded (not hex with colons)
- Have no spaces or newlines
- Be exactly: `cqLH0heinyI4S9IYqDQnXQbTa+k=`

To regenerate and verify:
```powershell
powershell -ExecutionPolicy Bypass -File get_facebook_key_hash.ps1
```

### Issue 3: Alternative - Use Graph API

If the web UI keeps failing, you can try using Facebook's Graph API Explorer:

1. Go to: https://developers.facebook.com/tools/explorer/
2. Select your app
3. Use this API call (you'll need an access token with `manage_app` permission)

However, this is more complex and usually not necessary.

### Issue 4: Test Without Saving

Sometimes the hash works even if the UI doesn't show it saved:

1. Add the hash and save (even if it appears to clear)
2. Wait 5 minutes
3. Test Facebook login in your app
4. If it works, the hash was actually saved (just a UI display bug)

## Step-by-Step: Complete Reset

If nothing works, try this complete reset:

1. **Remove Android Platform**:
   - Settings → Basic → Platforms → Remove Android

2. **Clear Browser Cache**:
   - `Ctrl+Shift+Delete` → Select "Cached images and files" → Clear

3. **Log Out and Log Back In** to Facebook Developer Console

4. **Add Android Platform Fresh**:
   - Settings → Basic → "+ Add Platform" → Android
   - Package Name: `com.example.namer_app`
   - Class Name: `com.example.namer_app.MainActivity`
   - Key Hashes: `cqLH0heinyI4S9IYqDQnXQbTa+k=`

5. **Save Changes**

6. **Wait 5 minutes**, then test your app

## Verification

After saving, test if it actually worked:

1. Wait 5 minutes for changes to propagate
2. Open your Flutter app
3. Try Facebook login
4. If you get a **different error** (not "no key hash configured"), the hash was saved!
5. If you still get "no key hash configured", the hash wasn't saved

## Still Not Working?

If none of the above works, it might be a Facebook server-side issue. Try:

1. **Wait 24 hours** - sometimes Facebook's servers need time to sync
2. **Contact Facebook Support** - https://developers.facebook.com/support/
3. **Check Facebook Status** - https://developers.facebook.com/status/

## Alternative: Use Web Login Only

If native Facebook login keeps having issues, you can configure the app to always use webview login (which doesn't require key hash). However, this defeats the purpose of native login.

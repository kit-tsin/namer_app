# Google Sign-In Setup - No Credits Needed!

## ✅ Good News: It's FREE!

Google Sign-In and Firebase Authentication are **completely FREE** for:
- Up to 50,000 Monthly Active Users
- No billing account required for basic usage
- No credits needed

## 🔍 Why You Can't Find the API

For **Firebase projects**, the APIs are usually **automatically enabled**. You might not need to manually enable anything!

## What You Actually Need to Do

### Option 1: Skip API Enabling (Recommended for Firebase)

If you're using Firebase, you can **skip the API enabling step** and go directly to:

1. **Create OAuth Clients** (APIs & Services → Credentials)
   - This is what you actually need!
   - Create Web application OAuth client
   - Create Android OAuth client

2. **Add SHA Fingerprints to Firebase**
   - Firebase Console → Project Settings → Your Android app
   - Add SHA-1 and SHA-256 fingerprints

3. **Add Web Client ID to AndroidManifest.xml**
   - This is the key step that fixes the ClientConfigurationError

### Option 2: If You Really Need to Enable APIs

If you want to check/enable APIs manually:

1. Go to **APIs & Services** → **Library**
2. Search for: **"Identity Toolkit API"** (not "Google Sign-In API")
3. Or search for: **"Firebase Authentication API"**
4. Click **Enable** if it's not already enabled

## The Real Solution

You don't need to enable APIs manually! Just:

1. ✅ Create OAuth clients in Credentials
2. ✅ Add SHA fingerprints to Firebase  
3. ✅ Add Web Client ID to AndroidManifest.xml

That's it! The APIs are already working through Firebase.


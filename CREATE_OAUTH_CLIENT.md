# How to Create OAuth Client ID for Google Sign-In

## Step 1: Go to Google Cloud Console
1. Visit: https://console.cloud.google.com/
2. Select project: **namer-project-50f7d**

## Step 2: Configure OAuth Consent Screen (if not done)
1. Go to **APIs & Services** → **OAuth consent screen**
2. Select **External** (for public apps)
3. Fill in:
   - App name: `Namer App`
   - User support email: Your email
   - Developer contact: Your email
4. Click **Save and Continue** through all steps

## Step 3: Create Web Application OAuth Client
1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Select **Web application** as Application type
4. Name it: `Web Client for Android Sign-In`
5. Click **CREATE**
6. **Copy the Client ID** (you'll need this!)

## Step 4: Create Android OAuth Client (Optional but Recommended)
1. Still in **Credentials** page
2. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Select **Android** as Application type
4. Name it: `Android Client`
5. Package name: `com.example.namer_app`
6. SHA-1 certificate fingerprint: Get it by running:
   ```powershell
   keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android
   ```
7. Click **CREATE**

## Step 5: Re-download google-services.json
1. Go back to Firebase Console
2. Project Settings → Your apps → Android app
3. Click **Download google-services.json**
4. Replace your existing file

## Alternative: Just Use Web Client ID in AndroidManifest.xml
If you don't want to wait for google-services.json to update, you can:
1. Use the Web Client ID you copied in Step 3
2. Add it to AndroidManifest.xml (already done, just replace the placeholder)


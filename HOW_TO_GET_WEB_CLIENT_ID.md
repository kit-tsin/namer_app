# How to Get Web Client ID for Google Sign-In

## Method 1: From Firebase Console (Easiest)

1. Go to https://console.firebase.google.com/
2. Select your project: **namer-project-50f7d**
3. Click **Authentication** in the left menu
4. Click **Sign-in method** tab
5. Click on **Google** provider
6. Click **Enable** if it's not already enabled
7. In the **Web SDK configuration** section, you'll see:
   - **Web client ID**: `718875273858-XXXXXXXXXXXX.apps.googleusercontent.com`
   - Copy this value

## Method 2: From Google Cloud Console

1. Go to https://console.cloud.google.com/
2. Make sure you're in project: **namer-project-50f7d**
3. Click **APIs & Services** → **Credentials** in the left menu
4. Look for **OAuth 2.0 Client IDs**
5. Find the one with type **Web application** (or create one if it doesn't exist)
6. Click on it to see the **Client ID**
7. Copy the Client ID (format: `718875273858-XXXXXXXXXXXX.apps.googleusercontent.com`)

## Method 3: Create Web Client ID (If it doesn't exist)

If you don't see a Web client ID:

1. Go to https://console.cloud.google.com/
2. Select project: **namer-project-50f7d**
3. Click **APIs & Services** → **Credentials**
4. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
5. Select **Web application** as the application type
6. Give it a name (e.g., "Web Client for Android Sign-In")
7. Click **CREATE**
8. Copy the **Client ID** that appears

## After Getting the Client ID

1. Open `android/app/src/main/AndroidManifest.xml`
2. Find this line:
   ```xml
   <meta-data
       android:name="com.google.android.gms.auth.api.signin.DEFAULT_WEB_CLIENT_ID"
       android:value="YOUR_WEB_CLIENT_ID_HERE" />
   ```
3. Replace `YOUR_WEB_CLIENT_ID_HERE` with your actual Client ID
4. Save the file
5. Run `flutter clean && flutter run`

## Important Notes

- Use the Web Client ID from the **Android project** (`namer-project-50f7d`), NOT from the web project
- The Client ID format should be: `PROJECT_NUMBER-XXXXXXXXXXXX.apps.googleusercontent.com`
- Your project number is: `718875273858`
- Make sure Google Sign-In is enabled in Firebase Authentication


# Google Sign-In Setup Guide

## Overview
The Google Sign-In functionality is currently disabled because the GoogleSignIn SDK is not included in the project. Follow these steps to enable Google Sign-In:

## Step 1: Add Google Sign-In SDK

### Option A: Using Swift Package Manager (Recommended)
1. Open your Xcode project
2. Go to **File** → **Add Package Dependencies**
3. Enter the URL: `https://github.com/google/GoogleSignIn-iOS`
4. Click **Add Package**
5. Select **GoogleSignIn** and click **Add Package**

### Option B: Using CocoaPods
1. Add to your `Podfile`:
   ```ruby
   pod 'GoogleSignIn'
   ```
2. Run `pod install`

## Step 2: Configure Google Sign-In

1. **Download GoogleService-Info.plist**:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to **Project Settings** → **General**
   - Download the `GoogleService-Info.plist` file
   - Add it to your Xcode project

2. **Configure URL Schemes**:
   - In Xcode, select your project
   - Go to **Info** tab
   - Expand **URL Types**
   - Add a new URL Type with:
     - **Identifier**: `GoogleSignIn`
     - **URL Schemes**: Your `REVERSED_CLIENT_ID` from GoogleService-Info.plist

## Step 3: Enable Google Sign-In in Code

1. **Uncomment the Google Sign-In code** in `AuthManager.swift`:
   - Uncomment the import statement: `import GoogleSignIn`
   - Uncomment the code in `setupGoogleSignIn()` method
   - Uncomment the code in `signInWithGoogle()` method

2. **Update the import statement**:
   ```swift
   import GoogleSignIn
   ```

## Step 4: Test Google Sign-In

1. Build and run the project
2. Try signing in with Google
3. Verify that the authentication works correctly

## Troubleshooting

### Common Issues:
1. **"No such module 'GoogleSignIn'"**: Make sure the SDK is properly added to the project
2. **"GoogleService-Info.plist not found"**: Ensure the file is added to the project bundle
3. **"Invalid client ID"**: Check that the URL scheme is correctly configured
4. **"Sign-in failed"**: Verify that Google Sign-In is enabled in Firebase Console

### Firebase Console Setup:
1. Go to **Authentication** → **Sign-in method**
2. Enable **Google** provider
3. Add your app's bundle identifier
4. Download the updated `GoogleService-Info.plist`

## Current Status
- ✅ Firebase Authentication configured
- ✅ Email/Password authentication working
- ✅ Demo mode available
- ⏳ Google Sign-In (requires SDK installation)
- ✅ Apple Sign-In ready (if needed)

## Alternative: Use Demo Mode
Until Google Sign-In is configured, users can use the **Demo Mode** feature to test the application functionality without requiring authentication.

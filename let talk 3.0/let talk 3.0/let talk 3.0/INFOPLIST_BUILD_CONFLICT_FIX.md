# Info.plist Build Conflict Fix

## Issue
Multiple commands produce Info.plist error occurs when Xcode tries to generate its own Info.plist while a manual one exists.

## Solution
Configure the Info.plist settings directly in Xcode project settings instead of using a manual file.

## Steps to Fix

### 1. Clean Build Folder
1. In Xcode: **Product** → **Clean Build Folder** (Cmd+Shift+K)
2. Close Xcode completely
3. Delete DerivedData folder:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/let_talk_3.0-*
   ```

### 2. Configure Info.plist in Xcode Project Settings

#### A. Open Project Settings
1. Open your project in Xcode
2. Select the project file (top-level item)
3. Select your app target
4. Go to **Info** tab

#### B. Add Required Keys
Add these keys to your Info.plist in Xcode:

**Bundle Identifier:**
- Key: `CFBundleIdentifier`
- Value: `merchant.com.upappllc.Let-s-Talk-`

**Privacy Usage Descriptions:**
- Key: `NSCameraUsageDescription`
- Value: `This app needs camera access to capture images for text translation and document scanning.`

- Key: `NSMicrophoneUsageDescription`
- Value: `This app needs microphone access for voice recognition and speech-to-text translation.`

- Key: `NSSpeechRecognitionUsageDescription`
- Value: `This app uses speech recognition to convert your voice to text for translation.`

- Key: `NSPhotoLibraryUsageDescription`
- Value: `This app needs photo library access to select images for text translation.`

- Key: `NSLocationWhenInUseUsageDescription`
- Value: `This app may use location to provide location-based translation services.`

- Key: `NSContactsUsageDescription`
- Value: `This app needs contacts access to manage your contact list for calling and messaging.`

- Key: `NSDocumentsFolderUsageDescription`
- Value: `This app needs document folder access to save and import translation files.`

**Background Modes:**
- Key: `UIBackgroundModes`
- Type: Array
- Values:
  - `audio`
  - `voip`
  - `background-processing`
  - `remote-notification`

**Firebase Configuration:**
- Key: `FirebaseAppDelegateProxyEnabled`
- Type: Boolean
- Value: `NO`

**Push Notifications:**
- Key: `aps-environment`
- Value: `development`

**URL Schemes (for Google Sign-In):**
- Key: `CFBundleURLTypes`
- Type: Array
- Item 0:
  - `CFBundleURLName`: `GoogleSignIn`
  - `CFBundleURLSchemes`: Array with `com.googleusercontent.apps.362064879308-f6auunetuvajncl8ddf4kks7gcplnf5i`

**Network Security:**
- Key: `NSAppTransportSecurity`
- Type: Dictionary
- `NSAllowsArbitraryLoads`: Boolean `YES`

### 3. Alternative: Use Build Settings

If the Info tab doesn't work, you can add these as build settings:

1. Go to **Build Settings** tab
2. Search for "Info.plist"
3. Set **Info.plist File** to your target's Info.plist
4. Add custom build settings for each key

### 4. Verify Configuration

#### Check Bundle ID Match
- **GoogleService-Info.plist**: `merchant.com.upappllc.Let-s-Talk-`
- **Xcode Bundle Identifier**: `merchant.com.upappllc.Let-s-Talk-`

#### Test Build
1. **Product** → **Build** (Cmd+B)
2. Should build without Info.plist conflicts
3. Check that all permissions are properly configured

### 5. If Still Having Issues

#### Option A: Reset Info.plist
1. Delete any manual Info.plist files
2. Let Xcode generate a new one
3. Configure settings in project settings only

#### Option B: Check Target Settings
1. Make sure only one target is selected
2. Verify Info.plist file path is correct
3. Check for duplicate targets

#### Option C: Manual Info.plist (Last Resort)
If you must use a manual Info.plist:
1. Create it in the project root
2. Set **Info.plist File** in build settings to point to it
3. Make sure it's added to the target
4. Don't let Xcode auto-generate one

## Verification
After following these steps:
- ✅ No more "Multiple commands produce Info.plist" error
- ✅ App builds successfully
- ✅ All permissions properly configured
- ✅ Firebase integration works
- ✅ Push notifications enabled

## Troubleshooting

### If Error Persists
1. Check for multiple Info.plist files in project
2. Verify build settings point to correct file
3. Clean build folder and rebuild
4. Check for duplicate targets or schemes

### If Permissions Don't Work
1. Verify keys are spelled correctly
2. Check that values are properly set
3. Test on device (not simulator for some permissions)
4. Check iOS version compatibility

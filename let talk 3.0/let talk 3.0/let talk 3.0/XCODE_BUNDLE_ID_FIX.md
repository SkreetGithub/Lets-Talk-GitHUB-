# Xcode Bundle ID Configuration Fix

## Issue
The app's Bundle ID needs to match the Bundle ID in GoogleService-Info.plist: `merchant.com.upappllc.Let-s-Talk-`

## Steps to Fix Bundle ID in Xcode

### 1. Open Xcode Project
1. Open your project in Xcode
2. Select the project file in the navigator (top-level item)

### 2. Update Bundle Identifier
1. Select your app target in the project settings
2. Go to the **General** tab
3. Find **Bundle Identifier** field
4. Change it to: `merchant.com.upappllc.Let-s-Talk-`

### 3. Update Info.plist (if needed)
1. In the project navigator, find `Info.plist`
2. Make sure the `CFBundleIdentifier` key is set to: `merchant.com.upappllc.Let-s-Talk-`

### 4. Clean and Rebuild
1. In Xcode menu: **Product** → **Clean Build Folder** (Cmd+Shift+K)
2. **Product** → **Build** (Cmd+B)

## Verify Configuration

### Check Bundle ID Match
- **GoogleService-Info.plist**: `merchant.com.upappllc.Let-s-Talk-`
- **Xcode Bundle Identifier**: `merchant.com.upappllc.Let-s-Talk-`
- **Info.plist CFBundleIdentifier**: `merchant.com.upappllc.Let-s-Talk-`

All three should match exactly.

## Additional Xcode Settings

### 1. Enable Push Notifications
1. Select your app target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **Push Notifications**

### 2. Enable Background Modes
1. In **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add **Background Modes**
4. Check the following options:
   - ✅ Audio, AirPlay, and Picture in Picture
   - ✅ Voice over IP
   - ✅ Background processing
   - ✅ Remote notifications

### 3. Enable Google Sign-In (Optional)
1. In **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add **Google Sign-In**

## Troubleshooting

### If Bundle ID Still Doesn't Match
1. Check for multiple targets in your project
2. Ensure you're editing the correct target
3. Verify the Info.plist is assigned to the correct target
4. Clean build folder and rebuild

### If Firebase Still Shows Bundle ID Mismatch
1. Double-check the Bundle ID in GoogleService-Info.plist
2. Make sure there are no extra spaces or characters
3. Restart Xcode and clean build folder
4. Check if you have multiple GoogleService-Info.plist files

## Verification
After making these changes, the Firebase error about Bundle ID mismatch should disappear, and your app should connect to Firebase properly.

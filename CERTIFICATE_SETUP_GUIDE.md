# Certificate Setup Guide

## Step 1: Create a Certificate Signing Request (CSR) on Your Mac

1. **Open Keychain Access**
   - Press `Cmd + Space` to open Spotlight
   - Type "Keychain Access" and press Enter
   - Or go to Applications → Utilities → Keychain Access

2. **Create the CSR**
   - In the menu bar, click **Keychain Access** → **Certificate Assistant** → **Request a Certificate From a Certificate Authority...**
   
3. **Fill in the Certificate Information**
   - **User Email Address**: Enter your email (e.g., waliexchangece0@gmail.com)
   - **Common Name**: Enter your name or company name (e.g., "Demetrius Hollins" or "Wali Exchange LLC")
   - **CA Email Address**: Leave this **empty**
   - **Request is**: Select **"Saved to disk"**
   - Click **Continue**

4. **Save the CSR File**
   - Choose a location to save (Desktop is fine)
   - Name it something like "CertificateSigningRequest.certSigningRequest"
   - Click **Save**
   - Click **Done**

## Step 2: Upload CSR to Apple Developer Portal

1. **Go back to the Apple Developer Portal** (the page you were on)
   - You should be on the "Create a New Certificate" page
   - Select **"Apple Development"** (radio button)
   - Click **Continue**

2. **Upload Your CSR**
   - On the next page, you'll see "Upload CSR file"
   - Click **Choose File** or **Browse**
   - Navigate to where you saved the CSR file (likely Desktop)
   - Select the `.certSigningRequest` file
   - Click **Continue**

3. **Download the Certificate**
   - Apple will generate your certificate
   - Click **Download** to save the certificate file (`.cer` file)
   - The file will be named something like `development.cer`

## Step 3: Install the Certificate on Your Mac

1. **Double-click the downloaded `.cer` file**
   - It should automatically open in Keychain Access
   - Or manually open Keychain Access and drag the `.cer` file into it

2. **Verify Installation**
   - In Keychain Access, select **"login"** keychain (left sidebar)
   - Click on **"My Certificates"** category
   - You should see your new certificate listed
   - It should show your name/email and "Apple Development: ..."

3. **Verify in Xcode**
   - Open Xcode
   - Go to **Xcode** → **Settings** (or **Preferences**)
   - Click **Accounts** tab
   - Select your Apple ID
   - Click **Manage Certificates...**
   - You should see your certificate listed there

## Alternative: Let Xcode Do It Automatically (Easier!)

Since you have "Automatically manage signing" enabled, you can skip all of the above:

1. **Just build your project in Xcode**
   - Xcode will automatically:
     - Create the certificate
     - Create the App ID
     - Create the provisioning profile
     - Install everything

2. **If you get an error**, try:
   - **Product** → **Clean Build Folder** (Shift+Cmd+K)
   - **Product** → **Build** (Cmd+B)
   - Xcode will prompt you to sign in and create certificates automatically

## Troubleshooting

### If Xcode says "No accounts with App Store Connect access"
- Make sure you're signed in with the correct Apple ID in Xcode
- Go to **Xcode** → **Settings** → **Accounts**
- Click the **+** button and add your Apple ID
- Make sure the team "Wali Exchange LLC" is selected

### If certificate creation fails
- Make sure you're using the correct Apple ID that has access to the team
- Check that your Apple Developer account is active
- Try creating the certificate through Xcode instead (automatic signing)


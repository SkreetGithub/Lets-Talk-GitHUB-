# Let Talk 3.0

A comprehensive AI-powered communication platform that enables real-time translation, secure messaging, and global connectivity.

## Features

- 🔐 **Authentication & Security** - Email/Password, Biometric Auth, Phone Verification
- 🌍 **Translation Services** - Real-time translation for 40+ languages
- 💬 **Communication** - Secure messaging, Voice & Video calls, Group chats
- 🎨 **Modern UI** - Splash screen, Onboarding flow, Theme support

## Requirements

- iOS 18.2+
- Xcode 16.2+
- Swift 5.0+

## Setup

1. Open `Let Talk 3.0.xcodeproj` in Xcode
2. Configure API keys in `Info.plist`:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `OPENAI_API_KEY` (optional)
   - `GOOGLE_TRANSLATE_API_KEY` (optional)
3. Add Swift Package dependencies:
   - Supabase iOS SDK
   - WebRTC iOS SDK
4. Build and run

## Project Structure

- `Let Talk 3.0/` - Main app source files
  - Views: Splash, Onboarding, Auth, MainTabView
  - Managers: AuthManager, SettingsManager, NotificationManager
  - Services: WebRTC, Translation, Network monitoring

## License

Copyright © 2025


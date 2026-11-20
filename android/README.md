# Let Talk — Android (UI shell)

The Android version of Let Talk, built with Kotlin + Jetpack Compose.

**Status:** every screen built with sample data. It is NOT connected to the Let Talk server yet,
so nothing here can affect the live iPhone app or the backend.

Screens: Sign In, Sign Up (name, translated voice, email, password), Get Your Let Talk Number
(state → area code → 5 numbers → hold to lock in), Chats, Chat (translated bubbles with Show
Original, block/report), Calls (long-press menu), Contacts (long-press menu), Add Contact,
New Message, Translator, Settings (menu with arrows, language, My Let Talk Number, delete
account), and the Call screen (ringing → connected, translated subtitles, camera box only after
connecting).

## Build
- GitHub builds a test app automatically on every push to an `android/*` branch
  (Actions → "Android build" → artifact `LetTalk-android-test` → `app-debug.apk`).
- Or open this `android/` folder in Android Studio (JDK 17) and press Run.

## Next
1. Supabase sign-in / profiles / chats / contacts (same backend as iPhone, additive changes only).
2. Calls: WebRTC + ConnectionService + Firebase push for ringing when the app is closed.
3. Live translation (speech recognition → translate → speak) and the 12 app languages.

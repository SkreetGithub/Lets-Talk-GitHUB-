# App Review Notes — Let Talk (com.upappllc.lettalk)

Let Talk is a real-time video-call translator. Calls use WebRTC; speech is recognized on-device and the text is translated by our server (Supabase Edge Function) and shown as live subtitles.

## Demo account (no SMS needed)
- Email: reviewer@lettalk.app
- Password: (set in Supabase Auth when the account is created; paste it here before submitting)
- The profile for this account has a verified phone, so phone verification is skipped.
- A first-run consent sheet explains that text is sent to Google Translate / OpenAI; tap "I Agree".

## Where things are
- Report / block: chat header menu (…) and user profile.
- Delete account: Settings > Delete Account (calls a server function that removes the auth user and all data).
- Privacy Policy / Terms / Support: sign-in screen, Settings > Legal, paywall.
- Subscriptions: StoreKit 2, monthly and yearly, Restore Purchases on the paywall.
- Moderation: reports are reviewed within 24 hours.

## Testing a call
Calls need two devices/accounts. Sign in on a second device with a second account, add each other as contacts, start a video call.

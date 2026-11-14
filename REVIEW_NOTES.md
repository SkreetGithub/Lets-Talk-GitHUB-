# App Review Notes — Let Talk (com.upappllc.lettalk)

Paste the "Notes" section below into App Store Connect → App Review Information → Notes.
Put the sign-in details in the "Sign-in required" fields there, NOT in this file (this file is in git).

---

## Notes (paste into App Store Connect)

Let Talk lets two people who speak different languages talk to each other. You can make voice and video calls with live translated subtitles and translated speech, send messages that are translated automatically, and hold group audio calls with up to 4 people. Let Talk is a paid app ($4.99) with no in-app purchases and no subscription.

DEMO ACCOUNTS (sign in with email and password; no SMS code is needed)
- Account A: reviewer@lettalk.app (password is in the Sign-in fields)
- Account B: reviewer2@lettalk.app (password: [TYPE ACCOUNT B PASSWORD HERE IN APP STORE CONNECT ONLY])
The two accounts are already contacts of each other, so you can call between them right away.

TESTING A CALL
Calls need two devices. Sign in to Account A on one device and Account B on the other. On A, go to Contacts → "App Reviewer B" → tap the phone or video icon. B will ring; answer it. To test translation, set a different language in Settings → Language on each device. The first time translation runs, a consent sheet explains what is sent to the translation providers; tap "I Agree".

TRANSLATION AND PRIVACY
Speech is turned into text by Apple's speech recognition. That text is then translated by our server (a Supabase Edge Function), which uses Google Cloud Translation and OpenAI. Call audio and video are peer-to-peer (WebRTC, DTLS-SRTP) and are never recorded.

WHERE THINGS ARE
- Add a contact by QR code: Settings → My QR Code (show your code); Contacts → Add Contact → Scan QR Code. "Scan from Photo" also reads a screenshot of a code.
- Voice for translated speech: Settings → Voice Settings.
- Block / report a user: the chat's ⋯ menu, or the user's profile. We review reports within 24 hours.
- Delete account: Settings → Delete Account. This permanently deletes the account and all of its data on our server.
- Privacy Policy, Terms of Service, Support: Settings → Legal, and the sign-in screen.

PERMISSIONS
Microphone and camera (calls), Speech Recognition (live translation), Contacts (optional; shows which friends use Let Talk), Notifications (incoming calls and messages).

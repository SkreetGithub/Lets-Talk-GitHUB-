# App Review Notes — Let Talk (com.upappllc.lettalk)

Paste the "Notes" section below into App Store Connect → App Review Information → Notes.
Put the sign-in details in the "Sign-in required" fields there, NOT in this file (this file is in git).

---

## Notes (paste into App Store Connect)

Let Talk lets two people who speak different languages talk to each other. You can make one-to-one voice and video calls with live translated subtitles and translated speech (switch between voice and video during a call), and send messages that are translated automatically. The whole app can be shown in 12 languages. Let Talk is a paid app ($4.99) with no in-app purchases and no subscription.

DEMO ACCOUNTS (sign in with email and password; no SMS code is needed)
- Account A: reviewer@lettalk.app (password is in the Sign-in fields)
- Account B: reviewer2@lettalk.app (password: [TYPE ACCOUNT B PASSWORD HERE IN APP STORE CONNECT ONLY])
The two accounts are already contacts of each other, so you can call between them right away.

TESTING A CALL
Calls need two devices. Sign in to Account A on one device and Account B on the other. On A, go to Contacts → "App Reviewer B" → tap the phone or video icon. B will ring; answer it. To test translation, set a different language on each device in Settings → Language & Translation → My Language (the whole app switches to that language). The first time translation runs, a consent sheet explains what is sent to the translation providers; tap "I Agree".

TRANSLATION AND PRIVACY
Speech is turned into text by Apple's speech recognition. That text is then translated by our server (a Supabase Edge Function), which uses Google Cloud Translation and OpenAI. Call audio and video are peer-to-peer (WebRTC, DTLS-SRTP) and are never recorded.

WHERE THINGS ARE
- Your Let Talk number: chosen when you sign up; shown in Settings → My Let Talk Number (it can be changed once a year).
- Start a chat: Chats → compose button → pick a contact, or type a Let Talk number or email.
- Add a contact: Contacts → + → Scan QR Code, From My iPhone Contacts, or Enter Manually. Your own code: Settings → My QR Code. "Scan from Photo" also reads a screenshot of a code.
- Voice for translated speech: Settings → Audio & Video → Translated Voice.
- Block / report a user: the chat's ⋯ menu, or the user's profile. We review reports within 24 hours.
- Delete account: Settings → Delete Account (bottom of Settings). This permanently deletes the account and all of its data on our server.
- Privacy Policy, Terms of Service, Support: Settings → Help & Legal, and the sign-in screen.
- Blocked users list: Settings → Privacy & Safety → Blocked Users.

PERMISSIONS
Microphone and camera (calls), Speech Recognition (live translation), Contacts (optional; shows which friends use Let Talk), Notifications (incoming calls and messages).

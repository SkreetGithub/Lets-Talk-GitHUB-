# Backend setup checklist (one-time, needs your Supabase access)

1. Put the real anon key in Secrets.xcconfig (SUPABASE_ANON_KEY). Never use the service_role key in the app.
2. Run supabase_migration_v2_appstore.sql in the Supabase SQL editor (after supabase_schema.sql).
3. Deploy functions: `supabase functions deploy translate detect-language delete-account send-voip-push`
4. Set secrets: `supabase secrets set GOOGLE_TRANSLATE_API_KEY=... OPENAI_API_KEY=... APNS_KEY_P8=... APNS_KEY_ID=... APNS_TEAM_ID=... APNS_BUNDLE_ID=com.upappllc.lettalk APNS_ENV=production`
5. Create reviewer@lettalk.app in Auth and run the commented reviewer SQL at the bottom of the migration.
6. Rotate the OpenAI key that was exposed in the original zip.
7. App Store Connect: create subscriptions com.upappllc.lettalk.premium.monthly / .yearly; host https://lettalk.app/privacy, /terms, /support.
8. Add a 1024x1024 icon PNG to Assets.xcassets/AppIcon.appiconset.
9. Register the bundle ID with Push, Sign in with Apple, and VoIP; upload the APNs key.

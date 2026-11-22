-- App Review demo accounts: run AFTER creating reviewer@lettalk.app and reviewer2@lettalk.app
-- in Authentication → Users → Add user (with "Auto Confirm User" checked).
-- Gives both a profile with a phone number (so the phone step is skipped) and makes them
-- contacts of each other. Safe to run more than once.

WITH r AS (
  SELECT id::text AS id, email,
         CASE email WHEN 'reviewer@lettalk.app' THEN 'App Reviewer A' ELSE 'App Reviewer B' END AS name,
         CASE email WHEN 'reviewer@lettalk.app' THEN '(555) 010-0101' ELSE '(555) 010-0102' END AS phone
  FROM auth.users
  WHERE email IN ('reviewer@lettalk.app', 'reviewer2@lettalk.app')
)
INSERT INTO profiles (id, email, name, phone, gender, voice_id)
SELECT id, email, name, phone,
       CASE WHEN name = 'App Reviewer A' THEN 'male' ELSE 'female' END,
       CASE WHEN name = 'App Reviewer A' THEN 'male-1' ELSE 'female-1' END
FROM r
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, phone = EXCLUDED.phone,
  gender = COALESCE(profiles.gender, EXCLUDED.gender),
  voice_id = COALESCE(profiles.voice_id, EXCLUDED.voice_id);

INSERT INTO contacts (id, owner_id, name, phone, email, contact_user_id)
SELECT gen_random_uuid()::text, a.id, b.name, b.phone, b.email, b.id
FROM profiles a
JOIN profiles b ON a.id <> b.id
WHERE a.email IN ('reviewer@lettalk.app', 'reviewer2@lettalk.app')
  AND b.email IN ('reviewer@lettalk.app', 'reviewer2@lettalk.app')
ON CONFLICT (owner_id, contact_user_id) DO NOTHING;

-- Check: expect 2 profiles and 2 contacts.
SELECT 'profile' AS kind, email, name, phone FROM profiles
WHERE email IN ('reviewer@lettalk.app', 'reviewer2@lettalk.app')
UNION ALL
SELECT 'contact', p.email || ' → ' || c.name, c.contact_user_id, c.phone
FROM contacts c JOIN profiles p ON p.id = c.owner_id
WHERE p.email IN ('reviewer@lettalk.app', 'reviewer2@lettalk.app');

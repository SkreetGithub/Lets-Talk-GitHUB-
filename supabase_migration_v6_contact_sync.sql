-- Let Talk v6: contact sync (Feature 4). Safe to run more than once.
-- phone_hash = SHA-256 of the last 10 digits of profiles.phone, the same normalization the app
-- applies to address-book numbers (PhoneHash in ContactSync.swift). Kept up to date by
-- Postgres automatically (generated column), indexed for the match-contacts lookup.
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_hash TEXT GENERATED ALWAYS AS (
    CASE WHEN length(regexp_replace(coalesce(phone, ''), '\D', '', 'g')) >= 7
         THEN encode(extensions.digest(right(regexp_replace(phone, '\D', '', 'g'), 10), 'sha256'), 'hex')
    END
) STORED;

CREATE INDEX IF NOT EXISTS profiles_phone_hash_idx ON profiles (phone_hash);

NOTIFY pgrst, 'reload schema';

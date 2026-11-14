-- Let Talk v4: translation voice (Feature 1). Safe to run more than once.
-- gender:   which kind of voice others hear for this user's translated speech.
-- voice_id: the chosen voice, "<male|female>-<1..8>"; the listener's phone plays that voice
--           in the listener's own language.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS voice_id TEXT;

DO $$ BEGIN
  ALTER TABLE profiles ADD CONSTRAINT profiles_gender_check
    CHECK (gender IS NULL OR gender IN ('male', 'female'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE profiles ADD CONSTRAINT profiles_voice_id_check
    CHECK (voice_id IS NULL OR voice_id ~ '^(male|female)-[1-8]$');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

NOTIFY pgrst, 'reload schema';

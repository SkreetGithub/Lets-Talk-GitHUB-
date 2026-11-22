-- Let Talk v5: auto-translated messages (Feature 3). Safe to run more than once.
-- Messages keep ONLY the sender's original text; the sender's language travels in
-- messages.metadata ({"lang":"es"}), and each receiver's phone translates on display.
-- profiles.language is the receiver's language, used to translate the notification text.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS language TEXT;

DO $$ BEGIN
  ALTER TABLE profiles ADD CONSTRAINT profiles_language_check
    CHECK (language IS NULL OR language ~ '^[a-z]{2}(-[A-Za-z]{2,4})?$');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

NOTIFY pgrst, 'reload schema';

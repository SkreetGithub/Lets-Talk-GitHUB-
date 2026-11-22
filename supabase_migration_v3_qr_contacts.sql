-- Let Talk v3: link a saved contact to the Let Talk account it belongs to (QR add, contact sync).
-- Safe to run more than once. Run in Supabase → SQL Editor.

ALTER TABLE contacts ADD COLUMN IF NOT EXISTS contact_user_id TEXT REFERENCES profiles(id) ON DELETE CASCADE;

-- One saved contact per (owner, Let Talk user); scanning the same code twice adds nothing.
-- Rows without a linked account (contact_user_id NULL) are unaffected: NULLs never conflict.
CREATE UNIQUE INDEX IF NOT EXISTS contacts_owner_contact_user_key
    ON contacts (owner_id, contact_user_id);

-- Make the API see the new column immediately.
NOTIFY pgrst, 'reload schema';

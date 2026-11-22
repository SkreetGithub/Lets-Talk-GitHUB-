-- Let Talk 3.0 — App Store compliance migration (run AFTER supabase_schema.sql)
-- Adds: blocks, reports, push_tokens, call translation columns, delete_my_data().

-- 1. BLOCKS (Guideline 1.2)
CREATE TABLE IF NOT EXISTS blocks (
    blocker_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    blocked_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id)
);
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "own blocks select" ON blocks;
DROP POLICY IF EXISTS "own blocks insert" ON blocks;
DROP POLICY IF EXISTS "own blocks delete" ON blocks;
CREATE POLICY "own blocks select" ON blocks FOR SELECT USING (auth.uid()::text = blocker_id);
CREATE POLICY "own blocks insert" ON blocks FOR INSERT WITH CHECK (auth.uid()::text = blocker_id);
CREATE POLICY "own blocks delete" ON blocks FOR DELETE USING (auth.uid()::text = blocker_id);

-- 2. REPORTS (Guideline 1.2) — write-only for users; review in the dashboard
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reported_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    message_id TEXT,
    reason TEXT NOT NULL,
    details TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "file reports" ON reports;
CREATE POLICY "file reports" ON reports FOR INSERT WITH CHECK (auth.uid()::text = reporter_id);

-- 3. PUSH TOKENS (APNs + PushKit VoIP)
CREATE TABLE IF NOT EXISTS push_tokens (
    user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('apns','voip')),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, kind)
);
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "own tokens" ON push_tokens;
CREATE POLICY "own tokens" ON push_tokens FOR ALL
    USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id);

-- 4. CALL HISTORY translation columns
ALTER TABLE calls ADD COLUMN IF NOT EXISTS language_a TEXT;
ALTER TABLE calls ADD COLUMN IF NOT EXISTS language_b TEXT;
DROP POLICY IF EXISTS "own calls select" ON calls;
DROP POLICY IF EXISTS "own calls insert" ON calls;
DROP POLICY IF EXISTS "own calls update" ON calls;
CREATE POLICY "own calls select" ON calls FOR SELECT
    USING (auth.uid()::text = caller_id OR auth.uid()::text = callee_id);
CREATE POLICY "own calls insert" ON calls FOR INSERT WITH CHECK (auth.uid()::text = caller_id);
CREATE POLICY "own calls update" ON calls FOR UPDATE
    USING (auth.uid()::text = caller_id OR auth.uid()::text = callee_id);

-- 5. Hide blocked users' messages from the blocker
DROP POLICY IF EXISTS "Users can view messages in their chats" ON messages;
CREATE POLICY "Users can view messages in their chats" ON messages FOR SELECT
USING (
    (auth.uid()::text = sender_id OR auth.uid()::text = receiver_id)
    AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE b.blocker_id = auth.uid()::text
          AND b.blocked_id IN (sender_id, receiver_id)
          AND b.blocked_id <> auth.uid()::text
    )
);

-- 6. Reviewer demo account (create the auth user in Dashboard > Authentication first:
--    email reviewer@lettalk.app, a strong password, "Auto confirm"). Then run:
-- INSERT INTO profiles (id, email, name, phone)
-- SELECT id::text, 'reviewer@lettalk.app', 'App Reviewer', '+15555550100'
-- FROM auth.users WHERE email = 'reviewer@lettalk.app'
-- ON CONFLICT (id) DO UPDATE SET phone = EXCLUDED.phone;
-- (A non-empty phone makes the app skip SMS verification for this account.)

-- 7. ALIGN `calls` WITH WHAT THE APP INSERTS (is_video, participants, rejected_at) + SIGNALING TABLE
ALTER TABLE calls ADD COLUMN IF NOT EXISTS is_video BOOLEAN DEFAULT FALSE;
ALTER TABLE calls ADD COLUMN IF NOT EXISTS participants TEXT[] DEFAULT ARRAY[]::TEXT[];
ALTER TABLE calls ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ;
ALTER TABLE calls ALTER COLUMN direction DROP NOT NULL;

CREATE TABLE IF NOT EXISTS call_signals (
    id TEXT PRIMARY KEY,
    call_id TEXT NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    sender_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    sdp TEXT,
    candidate TEXT,
    sdp_mline_index INTEGER,
    sdp_mid TEXT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_call_signals_call ON call_signals(call_id, timestamp);
ALTER TABLE call_signals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "signals select" ON call_signals;
DROP POLICY IF EXISTS "signals insert" ON call_signals;
CREATE POLICY "signals select" ON call_signals FOR SELECT USING (
    EXISTS (SELECT 1 FROM calls c WHERE c.id = call_id
            AND (c.caller_id = auth.uid()::text OR c.callee_id = auth.uid()::text)));
CREATE POLICY "signals insert" ON call_signals FOR INSERT WITH CHECK (
    sender_id = auth.uid()::text AND EXISTS (SELECT 1 FROM calls c WHERE c.id = call_id
            AND (c.caller_id = auth.uid()::text OR c.callee_id = auth.uid()::text)));

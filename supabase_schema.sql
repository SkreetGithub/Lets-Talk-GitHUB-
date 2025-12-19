-- ============================================
-- Let Talk 3.0 - Supabase Database Schema
-- ============================================
-- This file contains all the SQL needed to set up your Supabase database
-- Run this in your Supabase SQL Editor or via migrations
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For fuzzy text search (trigram indexes)

-- ============================================
-- 1. PROFILES TABLE (User Profiles)
-- ============================================
-- Note: id is TEXT to match app's use of UUID.uuidString
-- The app converts Supabase auth.users UUID to string format
CREATE TABLE IF NOT EXISTS profiles (
    id TEXT PRIMARY KEY, -- Stored as string (UUID.uuidString from auth.users.id)
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    phone TEXT,
    photo_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen TIMESTAMPTZ,
    is_online BOOLEAN DEFAULT FALSE,
    device_tokens TEXT[] DEFAULT ARRAY[]::TEXT[],
    settings JSONB DEFAULT '{}'::JSONB,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for profiles
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON profiles(phone);
CREATE INDEX IF NOT EXISTS idx_profiles_name ON profiles USING gin(name gin_trgm_ops);

-- ============================================
-- 2. MESSAGES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL,
    sender_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    receiver_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    type TEXT NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image', 'video', 'audio', 'file', 'location', 'contact', 'system')),
    status TEXT NOT NULL DEFAULT 'sending' CHECK (status IN ('sending', 'sent', 'delivered', 'read', 'failed')),
    is_encrypted BOOLEAN DEFAULT TRUE,
    translation TEXT,
    attachments JSONB,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for messages
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_messages_chat_timestamp ON messages(chat_id, timestamp DESC);

-- ============================================
-- 3. CHATS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS chats (
    id TEXT PRIMARY KEY,
    participants TEXT[] NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    is_pinned BOOLEAN DEFAULT FALSE,
    image_url TEXT,
    unread_count INTEGER DEFAULT 0,
    last_message JSONB
);

-- Indexes for chats
CREATE INDEX IF NOT EXISTS idx_chats_participants ON chats USING gin(participants);
CREATE INDEX IF NOT EXISTS idx_chats_last_updated ON chats(last_updated DESC);
CREATE INDEX IF NOT EXISTS idx_chats_is_pinned ON chats(is_pinned) WHERE is_pinned = TRUE;

-- ============================================
-- 4. CONTACTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS contacts (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT,
    last_message TEXT,
    image_url TEXT,
    last_seen TIMESTAMPTZ,
    is_online BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for contacts
CREATE INDEX IF NOT EXISTS idx_contacts_owner_id ON contacts(owner_id);
CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone);
CREATE INDEX IF NOT EXISTS idx_contacts_name ON contacts(name);

-- ============================================
-- 5. CALLS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS calls (
    id TEXT PRIMARY KEY,
    caller_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    callee_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'audio' CHECK (type IN ('audio', 'video')),
    direction TEXT NOT NULL CHECK (direction IN ('incoming', 'outgoing')),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration INTEGER DEFAULT 0, -- Duration in seconds
    is_missed BOOLEAN DEFAULT FALSE,
    status TEXT NOT NULL DEFAULT 'initiated' CHECK (status IN ('initiated', 'ringing', 'answered', 'ended', 'rejected', 'missed')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    answered_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ
);

-- Indexes for calls
CREATE INDEX IF NOT EXISTS idx_calls_caller_id ON calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_calls_callee_id ON calls(callee_id);
CREATE INDEX IF NOT EXISTS idx_calls_timestamp ON calls(timestamp DESC);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE calls ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view their own profile"
    ON profiles FOR SELECT
    USING (auth.uid()::text = id);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid()::text = id);

CREATE POLICY "Users can view other profiles"
    ON profiles FOR SELECT
    USING (true);

-- Messages policies
CREATE POLICY "Users can view messages in their chats"
    ON messages FOR SELECT
    USING (
        auth.uid()::text = sender_id OR 
        auth.uid()::text = receiver_id
    );

CREATE POLICY "Users can insert their own messages"
    ON messages FOR INSERT
    WITH CHECK (auth.uid()::text = sender_id);

CREATE POLICY "Users can update their own messages"
    ON messages FOR UPDATE
    USING (auth.uid()::text = sender_id);

-- Chats policies
CREATE POLICY "Users can view chats they participate in"
    ON chats FOR SELECT
    USING (
        auth.uid()::text = ANY(participants)
    );

CREATE POLICY "Users can create chats"
    ON chats FOR INSERT
    WITH CHECK (
        auth.uid()::text = ANY(participants)
    );

CREATE POLICY "Users can update chats they participate in"
    ON chats FOR UPDATE
    USING (
        auth.uid()::text = ANY(participants)
    );

CREATE POLICY "Users can delete chats they participate in"
    ON chats FOR DELETE
    USING (
        auth.uid()::text = ANY(participants)
    );

-- Contacts policies
CREATE POLICY "Users can view their own contacts"
    ON contacts FOR SELECT
    USING (auth.uid()::text = owner_id);

CREATE POLICY "Users can insert their own contacts"
    ON contacts FOR INSERT
    WITH CHECK (auth.uid()::text = owner_id);

CREATE POLICY "Users can update their own contacts"
    ON contacts FOR UPDATE
    USING (auth.uid()::text = owner_id);

CREATE POLICY "Users can delete their own contacts"
    ON contacts FOR DELETE
    USING (auth.uid()::text = owner_id);

-- Calls policies
CREATE POLICY "Users can view calls they participated in"
    ON calls FOR SELECT
    USING (
        auth.uid()::text = caller_id OR 
        auth.uid()::text = callee_id
    );

CREATE POLICY "Users can insert their own calls"
    ON calls FOR INSERT
    WITH CHECK (auth.uid()::text = caller_id);

CREATE POLICY "Users can update calls they participated in"
    ON calls FOR UPDATE
    USING (
        auth.uid()::text = caller_id OR 
        auth.uid()::text = callee_id
    );

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for profiles updated_at
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically create profile when user signs up
-- Converts UUID to string format to match app expectations
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, name, phone)
    VALUES (
        NEW.id::text, -- Convert UUID to TEXT
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
        COALESCE(NEW.raw_user_meta_data->>'phone', '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Function to update chat last_updated when message is inserted
CREATE OR REPLACE FUNCTION update_chat_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chats
    SET 
        last_updated = NEW.timestamp,
        last_message = jsonb_build_object(
            'content', NEW.content,
            'sender_id', NEW.sender_id,
            'timestamp', NEW.timestamp,
            'type', NEW.type,
            'is_read', CASE WHEN NEW.status = 'read' THEN true ELSE false END
        )
    WHERE id = NEW.chat_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update chat when message is inserted
CREATE TRIGGER update_chat_on_message_insert
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_last_message();

-- ============================================
-- COMMENTS (Documentation)
-- ============================================
COMMENT ON TABLE profiles IS 'User profiles linked to auth.users';
COMMENT ON TABLE messages IS 'Chat messages between users';
COMMENT ON TABLE chats IS 'Chat conversations between participants';
COMMENT ON TABLE contacts IS 'User contacts/address book';
COMMENT ON TABLE calls IS 'Call history records';

COMMENT ON COLUMN profiles.device_tokens IS 'Array of push notification device tokens';
COMMENT ON COLUMN profiles.settings IS 'User settings stored as JSON';
COMMENT ON COLUMN messages.attachments IS 'Message attachments stored as JSON array';
COMMENT ON COLUMN messages.metadata IS 'Additional message metadata as JSON';
COMMENT ON COLUMN chats.last_message IS 'Last message in chat stored as JSON object';
COMMENT ON COLUMN chats.participants IS 'Array of user IDs participating in the chat';


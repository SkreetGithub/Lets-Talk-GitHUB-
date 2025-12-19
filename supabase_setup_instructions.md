# Supabase Database Setup Instructions

This guide will help you set up your Supabase database for Let Talk 3.0.

## Quick Setup

1. **Open Supabase Dashboard**
   - Go to your Supabase project dashboard
   - Navigate to the SQL Editor

2. **Run the Schema File**
   - Copy the contents of `supabase_schema.sql`
   - Paste it into the SQL Editor
   - Click "Run" to execute

3. **Verify Tables**
   - Go to Table Editor in Supabase
   - You should see these tables:
     - `profiles`
     - `messages`
     - `chats`
     - `contacts`
     - `calls`

## What's Included

### Tables Created

1. **profiles** - User profiles (linked to Supabase Auth)
2. **messages** - Chat messages between users
3. **chats** - Chat conversations
4. **contacts** - User contacts/address book
5. **calls** - Call history records

### Security Features

- **Row Level Security (RLS)** enabled on all tables
- Policies ensure users can only access their own data
- Users can view messages/chats they participate in
- Contacts are private to each user

### Automatic Features

- **Auto Profile Creation**: When a user signs up via Supabase Auth, a profile is automatically created
- **Chat Updates**: When a message is inserted, the chat's `last_message` and `last_updated` are automatically updated
- **Timestamps**: `updated_at` fields are automatically maintained

## Manual Setup Steps (Alternative)

If you prefer to set up tables manually:

### 1. Create Profiles Table
```sql
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    phone TEXT,
    photo_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen TIMESTAMPTZ,
    is_online BOOLEAN DEFAULT FALSE,
    device_tokens TEXT[] DEFAULT ARRAY[]::TEXT[],
    settings JSONB DEFAULT '{}'::JSONB
);
```

### 2. Enable RLS
```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
```

### 3. Create Policies
```sql
CREATE POLICY "Users can view their own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);
```

(Repeat for other tables - see `supabase_schema.sql` for complete policies)

## Testing

After setup, you can test by:

1. **Creating a test user** via Supabase Auth
2. **Verifying profile creation** - Check that a profile was automatically created
3. **Inserting test data** - Use the Supabase Table Editor to add test messages/chats

## Troubleshooting

### Error: "extension uuid-ossp does not exist"
- This is usually enabled by default in Supabase
- If not, run: `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`

### RLS Policies Not Working
- Make sure RLS is enabled: `ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;`
- Check that policies are created correctly
- Verify user is authenticated: `SELECT auth.uid();`

### Profile Not Created on Signup
- Check that the trigger `on_auth_user_created` exists
- Verify the function `handle_new_user()` is created
- Check Supabase logs for errors

## Next Steps

1. Configure your app's `Info.plist` with:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

2. Test authentication in your app

3. Test message sending/receiving

4. Verify contacts functionality

## Additional Notes

- The schema uses `TEXT` for IDs (not UUID) to match your Swift code
- JSONB columns are used for flexible data (attachments, metadata, settings)
- Arrays are used for participants and device_tokens
- All timestamps use `TIMESTAMPTZ` for timezone support


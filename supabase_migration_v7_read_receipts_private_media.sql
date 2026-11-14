-- Let Talk 3.0 — read receipts, private chat media, per-user delete (2026-11-14)
-- Applied to project tbjsaubpwyloyjpiibbr through the SQL editor.

-------------------------------------------------------------------------------
-- 1. READ RECEIPTS
-------------------------------------------------------------------------------
alter table public.messages add column if not exists read_at timestamptz;

-- The receiver marks a message read. Only read_at/status change; only the receiver can do it.
create or replace function public.mark_message_read(p_message_id text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.messages
     set read_at = coalesce(read_at, now()),
         status  = 'read'
   where id = p_message_id
     and lower(receiver_id) = auth.uid()::text;
$$;

-- Same thing for every message the chat screen shows at once (one call per refresh).
create or replace function public.mark_messages_read(p_message_ids text[])
returns void
language sql
security definer
set search_path = public
as $$
  update public.messages
     set read_at = coalesce(read_at, now()),
         status  = 'read'
   where id = any(p_message_ids)
     and lower(receiver_id) = auth.uid()::text
     and read_at is null;
$$;

revoke all on function public.mark_message_read(text) from public, anon;
revoke all on function public.mark_messages_read(text[]) from public, anon;
grant execute on function public.mark_message_read(text) to authenticated;
grant execute on function public.mark_messages_read(text[]) to authenticated;

-- RLS: the receiver may update their incoming messages...
drop policy if exists "Receiver can mark messages read" on public.messages;
create policy "Receiver can mark messages read" on public.messages
  for update to authenticated
  using (auth.uid()::text = lower(receiver_id))
  with check (auth.uid()::text = lower(receiver_id));

-- ...but RLS can't limit columns, so this trigger does: a receiver can change only
-- read_at/status (to delivered/read), and a sender can't fake a read receipt.
create or replace function public.messages_guard_update()
returns trigger
language plpgsql
as $$
declare
  me text := auth.uid()::text;
begin
  if me is null then
    return new;   -- service role / server code
  end if;
  if me = lower(old.receiver_id) and me <> lower(old.sender_id) then
    if (to_jsonb(new) - 'read_at' - 'status') is distinct from (to_jsonb(old) - 'read_at' - 'status') then
      raise exception 'Only read_at can be changed by the receiver';
    end if;
    if new.status not in ('delivered', 'read') then
      raise exception 'Receiver can only set status to delivered or read';
    end if;
  elsif me = lower(old.sender_id) and new.read_at is distinct from old.read_at then
    raise exception 'Only the receiver can mark a message read';
  end if;
  return new;
end;
$$;

drop trigger if exists messages_guard_update on public.messages;
create trigger messages_guard_update
  before update on public.messages
  for each row execute function public.messages_guard_update();

-------------------------------------------------------------------------------
-- 2. PRIVATE CHAT MEDIA
-- Photos/files go to the private `chat-files` bucket, voice messages to `chat-audio`,
-- at <chat_id>/<message_id>.<ext>. Only the two people in that chat can read them
-- (the app opens them through 1-hour signed URLs).
-------------------------------------------------------------------------------
create or replace function public.is_chat_participant(p_chat_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.chats c
     where c.id = p_chat_id
       and auth.uid()::text = any (select lower(p) from unnest(c.participants) p)
  );
$$;
revoke all on function public.is_chat_participant(text) from public, anon;
grant execute on function public.is_chat_participant(text) to authenticated;

-- Replace the old "any signed-in user can read/write everything" policies.
drop policy if exists "Users can upload chat files"   on storage.objects;
drop policy if exists "Users can view chat files"     on storage.objects;
drop policy if exists "Users can update chat files"   on storage.objects;
drop policy if exists "Users can delete chat files"   on storage.objects;
drop policy if exists "Users can upload voice messages" on storage.objects;
drop policy if exists "Users can view voice messages"   on storage.objects;
drop policy if exists "Users can update voice messages" on storage.objects;
drop policy if exists "Users can delete voice messages" on storage.objects;

create policy "Chat members upload chat media" on storage.objects
  for insert to authenticated
  with check (bucket_id in ('chat-files', 'chat-audio')
              and public.is_chat_participant((storage.foldername(name))[1]));

create policy "Chat members view chat media" on storage.objects
  for select to authenticated
  using (bucket_id in ('chat-files', 'chat-audio')
         and public.is_chat_participant((storage.foldername(name))[1]));

create policy "Uploader updates own chat media" on storage.objects
  for update to authenticated
  using (bucket_id in ('chat-files', 'chat-audio') and owner = auth.uid());

create policy "Uploader deletes own chat media" on storage.objects
  for delete to authenticated
  using (bucket_id in ('chat-files', 'chat-audio') and owner = auth.uid());

-- Public bucket: anyone signed in could overwrite or delete ANYONE's profile photo.
-- Now you can only write your own profile_images/<your id>.jpg (photos stay publicly viewable).
drop policy if exists "Users can upload their own profile images" on storage.objects;
drop policy if exists "Users can update their own profile images" on storage.objects;
drop policy if exists "Users can delete their own profile images" on storage.objects;

create policy "Users can upload their own profile images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'public' and lower(name) = 'profile_images/' || auth.uid()::text || '.jpg');

create policy "Users can update their own profile images" on storage.objects
  for update to authenticated
  using (bucket_id = 'public' and lower(name) = 'profile_images/' || auth.uid()::text || '.jpg');

create policy "Users can delete their own profile images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'public' and lower(name) = 'profile_images/' || auth.uid()::text || '.jpg');

-------------------------------------------------------------------------------
-- 3. DELETE = HIDE FOR ME
-- Deleting a chat or call hides it for that person only; the other person keeps it.
-------------------------------------------------------------------------------
alter table public.chats add column if not exists hidden_for text[] not null default '{}';
alter table public.calls add column if not exists hidden_for text[] not null default '{}';

create or replace function public.hide_chat(p_chat_id text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.chats
     set hidden_for = array_append(array_remove(hidden_for, auth.uid()::text), auth.uid()::text)
   where id = p_chat_id
     and auth.uid()::text = any (select lower(p) from unnest(participants) p);
$$;

create or replace function public.hide_call(p_call_id text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.calls
     set hidden_for = array_append(array_remove(hidden_for, auth.uid()::text), auth.uid()::text)
   where id = p_call_id
     and auth.uid()::text in (lower(caller_id), lower(callee_id));
$$;

revoke all on function public.hide_chat(text) from public, anon;
revoke all on function public.hide_call(text) from public, anon;
grant execute on function public.hide_chat(text) to authenticated;
grant execute on function public.hide_call(text) to authenticated;

-- A client can no longer delete a chat row for both people.
drop policy if exists "Users can delete chats they participate in" on public.chats;

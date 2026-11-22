-- v8: Private bucket for profile photos.
--
-- Photos live at profile-photos/<user id>/<timestamp>.jpg. A new upload gets a new file name,
-- so every phone's cache picks up the change. profiles.photo_url stores a reference
-- ("lettalk-media://profile-photos/<path>") that the app opens through a 1-hour signed URL.
--
-- Who can do what:
--   * any signed-in user can VIEW profile photos (so callers, chats and contacts show them);
--     people who are not signed in cannot.
--   * you can only add, replace or delete files in YOUR OWN folder.
-- Safe to run more than once.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', false, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Signed-in users view profile photos" on storage.objects;
create policy "Signed-in users view profile photos"
  on storage.objects for select to authenticated
  using (bucket_id = 'profile-photos');

drop policy if exists "Users upload own profile photo" on storage.objects;
create policy "Users upload own profile photo"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users replace own profile photo" on storage.objects;
create policy "Users replace own profile photo"
  on storage.objects for update to authenticated
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users delete own profile photo" on storage.objects;
create policy "Users delete own profile photo"
  on storage.objects for delete to authenticated
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);

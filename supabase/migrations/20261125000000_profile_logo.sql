-- Store logo shown on the profile completion screen.
-- The path is relative to the public "images" bucket, e.g. "<uid>/logo.png".
alter table if exists public.profiles
  add column if not exists business_logo text;

-- Public bucket for store logos and product images. Writes are restricted to
-- the signed-in user's own "<uid>/..." folder by the policies below.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('images', 'images', true, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists images_select_own on storage.objects;
create policy images_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists images_insert_own on storage.objects;
create policy images_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists images_update_own on storage.objects;
create policy images_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists images_delete_own on storage.objects;
create policy images_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

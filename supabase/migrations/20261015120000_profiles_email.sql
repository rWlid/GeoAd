-- Email for the sign up screen. Optional, so existing profiles keep working,
-- but two profiles can't share the same email.
-- Paste this into the Supabase SQL editor.

alter table public.profiles add column email text;

create unique index profiles_email_key on public.profiles (email)
  where email is not null;

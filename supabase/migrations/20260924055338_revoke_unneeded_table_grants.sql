revoke truncate, trigger, references, maintain on all tables in schema public from authenticated;

revoke insert, update, delete on public.categories from authenticated;

alter default privileges for role postgres in schema public
  revoke truncate, trigger, references, maintain on tables from authenticated;

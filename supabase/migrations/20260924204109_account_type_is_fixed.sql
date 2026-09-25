-- name can't be cleared either, or a client could flip the type
create or replace function public.prevent_profile_identity_change()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.id is distinct from old.id then
    raise exception 'profiles.id cannot be changed';
  end if;

  if new.phone is distinct from old.phone then
    raise exception 'profiles.phone cannot be changed (D-01: the login identity is derived from it)';
  end if;

  if old.name is not null and new.name is null then
    raise exception 'profiles.name cannot be cleared once set (D-34)';
  end if;

  if old.name is not null and new.is_business is distinct from old.is_business then
    raise exception 'profiles.is_business cannot be changed after sign-up (D-34)';
  end if;

  return new;
end;
$$;

comment on function public.prevent_profile_identity_change is
  'Rejects updates that change profiles.id or profiles.phone (D-01), clear '
  'profiles.name, or change profiles.is_business once the name is set (D-34).';

revoke all on function public.prevent_profile_identity_change() from public, anon, authenticated;

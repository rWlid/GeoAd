create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_phone text := new.raw_user_meta_data ->> 'phone';
begin
  if v_phone is null then
    raise exception 'sign up requires a phone in raw_user_meta_data (D-01)';
  end if;

  insert into public.profiles (id, phone)
  values (new.id, v_phone);

  return new;
end;
$$;

comment on function public.handle_new_user is
  'Creates the profiles row for a new auth user; phone comes from user metadata (D-02).';

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

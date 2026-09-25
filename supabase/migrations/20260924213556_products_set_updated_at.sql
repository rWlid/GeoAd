-- don't copy to locations/ads, their rpcs set updated_at on purpose

create or replace function public.set_products_timestamps()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
  else
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.set_products_timestamps is
  'Sets products.created_at at insert and updated_at on every write (D-10).';

revoke all on function public.set_products_timestamps() from public, anon, authenticated;

create trigger products_set_timestamps
  before insert or update on public.products
  for each row
  execute function public.set_products_timestamps();

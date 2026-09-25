create policy categories_select on public.categories
  for select to authenticated
  using (true);

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

-- no insert policy on purpose: a client could claim a phone
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy locations_select_own on public.locations
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy locations_insert_own on public.locations
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy locations_update_own on public.locations
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy locations_delete_own on public.locations
  for delete to authenticated
  using (user_id = (select auth.uid()));

create policy products_select_own on public.products
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy products_insert_own on public.products
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy products_update_own on public.products
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy products_delete_own on public.products
  for delete to authenticated
  using (user_id = (select auth.uid()));

create policy ads_select_own on public.ads
  for select to authenticated
  using (seller_id = (select auth.uid()));

create policy ads_insert_own on public.ads
  for insert to authenticated
  with check (seller_id = (select auth.uid()));

create policy ads_update_own on public.ads
  for update to authenticated
  using (seller_id = (select auth.uid()))
  with check (seller_id = (select auth.uid()));

create policy ads_delete_own on public.ads
  for delete to authenticated
  using (seller_id = (select auth.uid()));

create policy ad_products_select_own on public.ad_products
  for select to authenticated
  using (
    exists (
      select 1 from public.ads a
      where a.id = ad_id and a.seller_id = (select auth.uid())
    )
  );

create policy ad_products_insert_own on public.ad_products
  for insert to authenticated
  with check (
    exists (
      select 1 from public.ads a
      where a.id = ad_id and a.seller_id = (select auth.uid())
    )
    and exists (
      select 1 from public.products p
      where p.id = product_id and p.user_id = (select auth.uid())
    )
  );

create policy ad_products_update_own on public.ad_products
  for update to authenticated
  using (
    exists (
      select 1 from public.ads a
      where a.id = ad_id and a.seller_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.ads a
      where a.id = ad_id and a.seller_id = (select auth.uid())
    )
    and exists (
      select 1 from public.products p
      where p.id = product_id and p.user_id = (select auth.uid())
    )
  );

create policy ad_products_delete_own on public.ad_products
  for delete to authenticated
  using (
    exists (
      select 1 from public.ads a
      where a.id = ad_id and a.seller_id = (select auth.uid())
    )
  );

create policy ad_locations_select_own on public.ad_locations
  for select to authenticated
  using (
    exists (
      select 1 from public.ads a
      where a.id = ad_id and a.seller_id = (select auth.uid())
    )
  );

create policy ad_locations_insert_own on public.ad_locations
  for insert to authenticated
  with check (
    exists (
      select 1 from public.ads a
      where a.id = ad_id and a.seller_id = (select auth.uid())
    )
    and exists (
      select 1 from public.locations l
      where l.id = location_id and l.user_id = (select auth.uid())
    )
  );

create policy ad_locations_update_own on public.ad_locations
  for update to authenticated
  using (
    exists (
      select 1 from public.ads a
      where a.id = ad_id and a.seller_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.ads a
      where a.id = ad_id and a.seller_id = (select auth.uid())
    )
    and exists (
      select 1 from public.locations l
      where l.id = location_id and l.user_id = (select auth.uid())
    )
  );

create policy ad_locations_delete_own on public.ad_locations
  for delete to authenticated
  using (
    exists (
      select 1 from public.ads a
      where a.id = ad_id and a.seller_id = (select auth.uid())
    )
  );

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

  return new;
end;
$$;

comment on function public.prevent_profile_identity_change is
  'Rejects updates that change profiles.id or profiles.phone (D-01).';

revoke all on function public.prevent_profile_identity_change() from public, anon, authenticated;

create trigger profiles_identity_is_immutable
  before update on public.profiles
  for each row
  execute function public.prevent_profile_identity_change();

revoke all on all tables in schema public from anon;

alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke execute on functions from anon;

alter default privileges revoke execute on functions from public;

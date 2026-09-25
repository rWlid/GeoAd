-- lock the ad row before counting its links, or deletes can race

create or replace function public.save_ad(
  p_ad_id uuid,
  p_product_ids uuid[],
  p_location_ids uuid[],
  p_is_active boolean
)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_ad_id uuid;
  v_product_ids uuid[];
  v_location_ids uuid[];
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_is_active is null
     or coalesce(cardinality(p_product_ids), 0) = 0
     or coalesce(cardinality(p_location_ids), 0) = 0
     or array_position(p_product_ids, null) is not null
     or array_position(p_location_ids, null) is not null then
    raise exception 'save_ad needs p_is_active and non-empty product and location lists'
      using errcode = '22023';
  end if;

  v_product_ids := array(select distinct unnest(p_product_ids));
  v_location_ids := array(select distinct unnest(p_location_ids));

  if (select count(*) from (
        select 1 from products
        where id = any(v_product_ids) and user_id = v_uid
        for key share) own) <> cardinality(v_product_ids) then
    raise exception 'save_ad: product not found' using errcode = '42501';
  end if;

  if (select count(*) from (
        select 1 from locations
        where id = any(v_location_ids) and user_id = v_uid
        for key share) own) <> cardinality(v_location_ids) then
    raise exception 'save_ad: location not found' using errcode = '42501';
  end if;

  if p_ad_id is null then
    insert into ads (seller_id, is_active)
    values (v_uid, p_is_active)
    returning id into v_ad_id;
  else
    update ads
    set is_active = p_is_active, updated_at = now()
    where id = p_ad_id and seller_id = v_uid
    returning id into v_ad_id;

    if v_ad_id is null then
      raise exception 'save_ad: ad not found' using errcode = '42501';
    end if;

    delete from ad_products where ad_id = v_ad_id;
    delete from ad_locations where ad_id = v_ad_id;
  end if;

  insert into ad_products (ad_id, product_id)
  select v_ad_id, unnest(v_product_ids);

  insert into ad_locations (ad_id, location_id)
  select v_ad_id, unnest(v_location_ids);

  update locations
  set updated_at = now()
  where id = any(v_location_ids) and user_id = v_uid and type = 'fixed';

  return v_ad_id;
end;
$$;

comment on function public.save_ad(uuid, uuid[], uuid[], boolean) is
  'Creates (p_ad_id null) or replaces an ad and all its links in one transaction (D-06, D-09).';

create or replace function public.set_ad_active(p_ad_id uuid, p_active boolean)
returns void
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_ad_id is null or p_active is null then
    raise exception 'set_ad_active needs p_ad_id and p_active' using errcode = '22023';
  end if;

  perform 1 from ads where id = p_ad_id and seller_id = v_uid for update;
  if not found then
    raise exception 'set_ad_active: ad not found' using errcode = '42501';
  end if;

  if p_active and (
       not exists (select 1 from ad_products where ad_id = p_ad_id)
       or not exists (select 1 from ad_locations where ad_id = p_ad_id)) then
    raise exception 'an ad needs at least one product and one location to be active (D-06)'
      using errcode = '22023';
  end if;

  update ads
  set is_active = p_active, updated_at = now()
  where id = p_ad_id;
end;
$$;

comment on function public.set_ad_active(uuid, boolean) is
  'Activates or pauses an ad; refuses to activate one with no products or no locations (D-06).';

create or replace function public.delete_product(p_id uuid)
returns int
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_ad_ids uuid[];
  v_deactivated int;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_id is null then
    raise exception 'delete_product needs p_id' using errcode = '22023';
  end if;

  perform 1 from products where id = p_id and user_id = v_uid for update;
  if not found then
    raise exception 'delete_product: product not found' using errcode = '42501';
  end if;

  select coalesce(array_agg(ad_id order by ad_id), '{}')
  into v_ad_ids
  from ad_products
  where product_id = p_id;

  perform 1 from ads where id = any(v_ad_ids) order by id for update;

  delete from products where id = p_id;

  select count(*)
  into v_deactivated
  from ads a
  where a.id = any(v_ad_ids)
    and a.is_active
    and not exists (select 1 from ad_products ap where ap.ad_id = a.id);

  update ads a
  set updated_at = now(),
      is_active = a.is_active
                  and exists (select 1 from ad_products ap where ap.ad_id = a.id)
  where a.id = any(v_ad_ids);

  return v_deactivated;
end;
$$;

comment on function public.delete_product(uuid) is
  'Deletes a product and pauses ads left with no products; returns how many were paused (D-06).';

create or replace function public.delete_location(p_id uuid)
returns int
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_type text;
  v_ad_ids uuid[];
  v_deactivated int;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_id is null then
    raise exception 'delete_location needs p_id' using errcode = '22023';
  end if;

  select type
  into v_type
  from locations
  where id = p_id and user_id = v_uid
  for update;

  if not found then
    raise exception 'delete_location: location not found' using errcode = '42501';
  end if;

  if v_type = 'live' then
    raise exception 'the live location is managed by heartbeat_live_location and stop_live_location'
      using errcode = '22023';
  end if;

  select coalesce(array_agg(ad_id order by ad_id), '{}')
  into v_ad_ids
  from ad_locations
  where location_id = p_id;

  perform 1 from ads where id = any(v_ad_ids) order by id for update;

  delete from locations where id = p_id;

  select count(*)
  into v_deactivated
  from ads a
  where a.id = any(v_ad_ids)
    and a.is_active
    and not exists (select 1 from ad_locations al where al.ad_id = a.id);

  update ads a
  set updated_at = now(),
      is_active = a.is_active
                  and exists (select 1 from ad_locations al where al.ad_id = a.id)
  where a.id = any(v_ad_ids);

  return v_deactivated;
end;
$$;

comment on function public.delete_location(uuid) is
  'Deletes a fixed location and pauses ads left with no locations; returns how many were paused (D-06).';

create or replace function public.heartbeat_live_location(
  p_lat double precision,
  p_lng double precision
)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_lat is null or p_lng is null then
    raise exception 'heartbeat_live_location needs p_lat and p_lng' using errcode = '22023';
  end if;

  insert into locations (user_id, lat, lng, type)
  values (v_uid, p_lat, p_lng, 'live')
  on conflict (user_id) where type = 'live'
  do update set lat = excluded.lat,
                lng = excluded.lng,
                updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

comment on function public.heartbeat_live_location(double precision, double precision) is
  'Upserts the caller''s single live location with updated_at = now(); returns its id (D-09, D-21).';

create or replace function public.stop_live_location()
returns void
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  update locations
  set updated_at = now() - interval '1 day'
  where user_id = v_uid and type = 'live';
end;
$$;

comment on function public.stop_live_location() is
  'Marks the caller''s live location stale so it leaves the map on the next poll (D-10, D-22).';

revoke all on function public.save_ad(uuid, uuid[], uuid[], boolean) from public, anon;
revoke all on function public.set_ad_active(uuid, boolean) from public, anon;
revoke all on function public.delete_product(uuid) from public, anon;
revoke all on function public.delete_location(uuid) from public, anon;
revoke all on function public.heartbeat_live_location(double precision, double precision) from public, anon;
revoke all on function public.stop_live_location() from public, anon;

grant execute on function public.save_ad(uuid, uuid[], uuid[], boolean) to authenticated;
grant execute on function public.set_ad_active(uuid, boolean) to authenticated;
grant execute on function public.delete_product(uuid) to authenticated;
grant execute on function public.delete_location(uuid) to authenticated;
grant execute on function public.heartbeat_live_location(double precision, double precision) to authenticated;
grant execute on function public.stop_live_location() to authenticated;

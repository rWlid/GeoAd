-- lock links by id then the ad, same as deletes, or it can deadlock

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
        order by id
        for key share) own) <> cardinality(v_product_ids) then
    raise exception 'save_ad: product not found' using errcode = '42501';
  end if;

  if (select count(*) from (
        select 1 from locations
        where id = any(v_location_ids) and user_id = v_uid
        order by id
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

  perform 1 from locations
  where id = any(v_location_ids) and user_id = v_uid and type = 'fixed'
  order by id
  for no key update;

  update locations
  set updated_at = now()
  where id = any(v_location_ids) and user_id = v_uid and type = 'fixed';

  return v_ad_id;
end;
$$;

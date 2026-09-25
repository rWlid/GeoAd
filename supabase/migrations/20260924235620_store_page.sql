create or replace function public.store_page(p_seller_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with seller as (
    select pf.id, pf.business_name, pf.logo_path, pf.phone
    from profiles pf
    where pf.id = p_seller_id
      and pf.is_business
  ),
  offered as (
    select pr.id, pr.name, pr.price, pr.description, pr.category_id,
           pr.image_paths
    from products pr
    join seller s on s.id = pr.user_id
    where pr.is_available
  ),
  ad_rows as (
    select a.id, a.updated_at,
           array(select o.id
                 from ad_products ap
                 join offered o on o.id = ap.product_id
                 where ap.ad_id = a.id
                 order by o.name, o.id) as product_ids,
           array(select l.id
                 from ad_locations al
                 join locations l on l.id = al.location_id
                 where al.ad_id = a.id
                   and l.user_id = s.id
                   and l.type = 'fixed'
                 order by l.name nulls last, l.id) as location_ids
    from ads a
    join seller s on s.id = a.seller_id
    where a.is_active
  ),
  listed_ads as (
    select * from ad_rows where cardinality(product_ids) > 0
  ),
  -- only locations used by listed ads, others may be a home address
  branches as (
    select l.id, l.name, l.lat, l.lng
    from locations l
    where l.type = 'fixed'
      and l.id in (select unnest(location_ids) from listed_ads)
  )
  select jsonb_build_object(
    'seller_id', s.id,
    'business_name', s.business_name,
    'logo_path', s.logo_path,
    'phone', s.phone,
    'branches', coalesce(
      (select jsonb_agg(jsonb_build_object(
                'id', b.id, 'name', b.name, 'lat', b.lat, 'lng', b.lng)
              order by b.name nulls last, b.id)
       from branches b),
      '[]'::jsonb),
    'products', coalesce(
      (select jsonb_agg(jsonb_build_object(
                'id', o.id, 'name', o.name, 'price', o.price,
                'description', o.description, 'category_id', o.category_id,
                'image_paths', o.image_paths)
              order by o.name, o.id)
       from offered o),
      '[]'::jsonb),
    'ads', coalesce(
      (select jsonb_agg(jsonb_build_object(
                'id', la.id,
                'product_ids', to_jsonb(la.product_ids),
                'location_ids', to_jsonb(la.location_ids))
              order by la.updated_at desc, la.id)
       from listed_ads la),
      '[]'::jsonb)
  )
  from seller s;
$$;

comment on function public.store_page(uuid) is
  'Public store page (US-12, D-36): null unless the seller is a business. '
  'Security definer: the store''s only read path besides nearby_ads (D-29).';

revoke all on function public.store_page(uuid) from public, anon;
grant execute on function public.store_page(uuid) to authenticated;

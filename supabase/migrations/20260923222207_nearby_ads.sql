create or replace function public.normalize_ar(t text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select translate(
    regexp_replace(lower(coalesce(t, '')), '[ً-ْـ]', '', 'g'),
    'أإآىةؤئ', 'ااايهوي')
$$;

comment on function public.normalize_ar(text) is
  'Lower-cases, strips tashkeel/tatweel and folds أإآ→ا ى→ي ة→ه ؤ→و ئ→ي (D-12).';

revoke all on function public.normalize_ar(text) from public, anon, authenticated;

-- must stay security definer, invoker silently shows only own ads
create or replace function public.nearby_ads(
  p_lat double precision,
  p_lng double precision,
  p_category_ids int[] default null,
  p_keyword text default null,
  p_radius_m int default 5000
)
returns table (
  ad_id uuid, location_id uuid, lat double precision, lng double precision,
  is_live boolean, distance_m double precision, seller_id uuid,
  display_name text, is_business boolean, logo_path text, phone text,
  products jsonb
)
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  with keyword as (
    select trim(normalize_ar(p_keyword)) as normalized
  ),
  params as (
    select
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography as center,
      least(greatest(coalesce(p_radius_m, 5000), 0), 5000) as radius_m,
      case when char_length(keyword.normalized) >= 2 then
        replace(replace(replace(keyword.normalized,
          '\', '\\'), '%', '\%'), '_', '\_')
      end as kw,
      array(select c.id from categories c
            where c.id = any(p_category_ids)
               or c.parent_id = any(p_category_ids)) as cat_ids
    from keyword
  ),
  matching as (
    select ap.ad_id,
           jsonb_agg(jsonb_build_object(
             'id', pr.id, 'name', pr.name, 'price', pr.price,
             'description', pr.description, 'category_id', pr.category_id,
             'image_paths', pr.image_paths) order by pr.name) as products
    from ad_products ap
    join products pr on pr.id = ap.product_id
    cross join params
    where pr.is_available
      and (p_category_ids is null or cardinality(p_category_ids) = 0
           or pr.category_id = any(params.cat_ids))
      and (params.kw is null
           or normalize_ar(pr.name || ' ' || coalesce(pr.description, ''))
              like '%' || params.kw || '%' escape '\')
    group by ap.ad_id
  )
  select a.id as ad_id,
         l.id as location_id,
         l.lat,
         l.lng,
         l.type = 'live' as is_live,
         st_distance(st_setsrid(st_makepoint(l.lng, l.lat), 4326)::geography,
                     params.center) as distance_m,
         a.seller_id,
         case when pf.is_business then pf.business_name else pf.name end
           as display_name,
         pf.is_business,
         case when pf.is_business then pf.logo_path end as logo_path,
         pf.phone,
         m.products
  from ads a
  join matching m      on m.ad_id = a.id
  join ad_locations al on al.ad_id = a.id
  join locations l     on l.id = al.location_id
  join profiles pf     on pf.id = a.seller_id
  cross join params
  where a.is_active
    and (l.type = 'fixed' or l.updated_at > now() - interval '30 seconds')
    and st_dwithin(st_setsrid(st_makepoint(l.lng, l.lat), 4326)::geography,
                   params.center, params.radius_m)
  order by distance_m, a.id, l.id
  limit 200;
$$;

comment on function public.nearby_ads(double precision, double precision, int[], text, int) is
  'Map pins within 5 km (D-11). Security definer: the only public read path (D-29).';

revoke all on function public.nearby_ads(double precision, double precision, int[], text, int)
  from public, anon;
grant execute on function public.nearby_ads(double precision, double precision, int[], text, int)
  to authenticated;

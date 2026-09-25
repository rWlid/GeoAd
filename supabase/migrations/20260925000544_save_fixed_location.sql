create or replace function public.save_fixed_location(
  p_lat double precision,
  p_lng double precision
)
returns uuid
language plpgsql
security invoker
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_point geography;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_lat is null or p_lng is null then
    raise exception 'save_fixed_location needs p_lat and p_lng' using errcode = '22023';
  end if;

  if not (p_lat between -90 and 90 and p_lng between -180 and 180) then
    raise exception 'save_fixed_location: lat/lng out of range' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  v_point := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;

  select l.id
  into v_id
  from locations l
  where l.user_id = v_uid
    and l.type = 'fixed'
    and st_dwithin(st_setsrid(st_makepoint(l.lng, l.lat), 4326)::geography, v_point, 50)
  order by st_distance(st_setsrid(st_makepoint(l.lng, l.lat), 4326)::geography, v_point),
           l.id
  limit 1;

  if v_id is null then
    insert into locations (user_id, lat, lng, type)
    values (v_uid, p_lat, p_lng, 'fixed')
    returning id into v_id;
  end if;

  return v_id;
end;
$$;

revoke all on function public.save_fixed_location(double precision, double precision) from public, anon;
grant execute on function public.save_fixed_location(double precision, double precision) to authenticated;

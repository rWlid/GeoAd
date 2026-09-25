begin;

create temp table _results (
  n int primary key,
  test text not null,
  ok boolean,
  detail text
) on commit drop;
grant insert, select on _results to authenticated, anon;

with f(f) as (
  values ('public.save_fixed_location(double precision,double precision)'::regprocedure)
)
insert into _results (n, test, ok)
select 1, 'security invoker (D-09)', not p.prosecdef
from f join pg_proc p on p.oid = f.f
union all
select 2, 'search_path is set',
       exists (select 1 from unnest(p.proconfig) cfg where cfg like 'search_path=%')
from f join pg_proc p on p.oid = f.f
union all
select 3, 'executable by authenticated', has_function_privilege('authenticated', f.f, 'execute')
from f
union all
select 4, 'not executable by PUBLIC or anon',
       not has_function_privilege('public', f.f, 'execute')
       and not has_function_privilege('anon', f.f, 'execute')
from f;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000a001', 'test-a@save-fixed-location.test', '{"phone":"966599990001"}'),
  ('00000000-0000-4000-8000-00000000b001', 'test-b@save-fixed-location.test', '{"phone":"966599990002"}');

do $$
declare
  v_a constant uuid := '00000000-0000-4000-8000-00000000a001';
  v_b constant uuid := '00000000-0000-4000-8000-00000000b001';
  v_x_lat constant double precision := 24.80;
  v_x_lng constant double precision := 46.60;
  v_n49_lat double precision; v_n49_lng double precision;
  v_s51_lat double precision; v_s51_lng double precision;
  v_s30_lat double precision; v_s30_lng double precision;
  v_e1k_lat double precision; v_e1k_lng double precision;
  v_d text;
  v_ok boolean;
  v_state text;
  v_n int;
  v_id uuid;
  v_l1 uuid; v_l2 uuid; v_live uuid; v_lb uuid;
  v_row record;
begin
  perform set_config('search_path', 'public, extensions, pg_temp', true);

  select st_y(g::geometry), st_x(g::geometry) into v_n49_lat, v_n49_lng
  from st_project(st_setsrid(st_makepoint(v_x_lng, v_x_lat), 4326)::geography, 49, radians(0)) g;
  select st_y(g::geometry), st_x(g::geometry) into v_s51_lat, v_s51_lng
  from st_project(st_setsrid(st_makepoint(v_x_lng, v_x_lat), 4326)::geography, 51, radians(180)) g;
  select st_y(g::geometry), st_x(g::geometry) into v_s30_lat, v_s30_lng
  from st_project(st_setsrid(st_makepoint(v_x_lng, v_x_lat), 4326)::geography, 30, radians(180)) g;
  select st_y(g::geometry), st_x(g::geometry) into v_e1k_lat, v_e1k_lng
  from st_project(st_setsrid(st_makepoint(v_x_lng, v_x_lat), 4326)::geography, 1000, radians(90)) g;

  select string_agg(round(m.d::numeric, 2)::text, ' / ' order by p.k),
         bool_and(abs(m.d - p.want) < 0.5)
  into v_d, v_ok
  from (values (1, v_n49_lat, v_n49_lng, 49), (2, v_s51_lat, v_s51_lng, 51),
               (3, v_s30_lat, v_s30_lng, 30)) p(k, lat, lng, want),
       lateral (select st_distance(st_setsrid(st_makepoint(p.lng, p.lat), 4326)::geography,
                                   st_setsrid(st_makepoint(v_x_lng, v_x_lat), 4326)::geography) d) m;
  insert into _results values (5, 'test points: 49 / 51 / 30 m from X (±0.5 m)', v_ok, v_d);

  set local role authenticated;

  perform set_config('request.jwt.claims', '{"role":"authenticated"}', true);
  begin
    perform public.save_fixed_location(v_x_lat, v_x_lng); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (10, 'no auth.uid() → 42501', v_state = '42501', v_state);

  perform set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  begin
    perform public.save_fixed_location(null, v_x_lng); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (11, 'null p_lat → 22023', v_state = '22023', v_state);

  begin
    perform public.save_fixed_location(v_x_lat, null); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (12, 'null p_lng → 22023', v_state = '22023', v_state);

  begin
    perform public.save_fixed_location(90.5, v_x_lng); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (13, 'lat 90.5 → 22023', v_state = '22023', v_state);

  begin
    perform public.save_fixed_location(v_x_lat, -180.5); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (14, 'lng -180.5 → 22023', v_state = '22023', v_state);

  begin
    perform public.save_fixed_location('NaN'::double precision, v_x_lng); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  select count(*) into v_n from locations;
  insert into _results values (15, 'lat NaN → 22023; A still has no locations',
    v_state = '22023' and v_n = 0, v_state || ', rows=' || v_n);

  v_l1 := public.save_fixed_location(v_x_lat, v_x_lng);
  select * into v_row from locations where id = v_l1;
  insert into _results values (20, 'first call inserts a fixed row owned by A at exactly X',
    v_row.user_id = v_a and v_row.type = 'fixed' and v_row.name is null
      and v_row.lat = v_x_lat and v_row.lng = v_x_lng
      and v_row.created_at = now() and v_row.updated_at = now(),
    v_row.type || ' ' || v_row.lat || ',' || v_row.lng);

  update locations set updated_at = now() - interval '1 hour' where id = v_l1;

  v_id := public.save_fixed_location(v_n49_lat, v_n49_lng);
  select * into v_row from locations where id = v_l1;
  select count(*) into v_n from locations;
  insert into _results values (21, '49 m away → L1 again; no new row; L1 lat/lng/updated_at unchanged (D-10)',
    v_id = v_l1 and v_n = 1 and v_row.lat = v_x_lat and v_row.lng = v_x_lng
      and v_row.updated_at = now() - interval '1 hour',
    'same=' || (v_id = v_l1) || ', rows=' || v_n);

  v_l2 := public.save_fixed_location(v_s51_lat, v_s51_lng);
  select * into v_row from locations where id = v_l2;
  select count(*) into v_n from locations;
  insert into _results values (22, '51 m away → a new fixed row L2 at exactly that point',
    v_l2 <> v_l1 and v_n = 2 and v_row.type = 'fixed'
      and v_row.lat = v_s51_lat and v_row.lng = v_s51_lng,
    'rows=' || v_n);

  update locations set updated_at = now() - interval '2 hours' where id = v_l2;
  v_id := public.save_fixed_location(v_s30_lat, v_s30_lng);
  select count(*) into v_n from locations;
  insert into _results values (23, '30 m from L1, 21 m from L2 (older) → L2; no new row',
    v_id = v_l2 and v_n = 2,
    case when v_id = v_l2 then 'L2' when v_id = v_l1 then 'L1' else 'other' end || ', rows=' || v_n);

  v_live := public.heartbeat_live_location(v_e1k_lat, v_e1k_lng);
  v_id := public.save_fixed_location(v_e1k_lat, v_e1k_lng);
  select * into v_row from locations where id = v_id;
  insert into _results values (24, 'live row at the same point → a new fixed row, live row untouched',
    v_id <> v_live and v_row.type = 'fixed'
      and (select type = 'live' from locations where id = v_live),
    v_row.type);

  perform set_config('request.jwt.claims', json_build_object('sub', v_b, 'role', 'authenticated')::text, true);
  v_lb := public.save_fixed_location(v_x_lat, v_x_lng);
  select * into v_row from locations where id = v_lb;
  insert into _results values (25, 'B at X → B''s own new row, not A''s L1',
    v_lb <> v_l1 and v_row.user_id = v_b and v_row.type = 'fixed',
    coalesce(v_row.user_id::text, 'row not visible to B'));

  v_lb := public.save_fixed_location(v_e1k_lat + 0.01, v_e1k_lng);
  perform set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  select count(*) into v_n from locations;
  v_id := public.save_fixed_location(v_e1k_lat + 0.01, v_e1k_lng);
  insert into _results values (26, 'A at B''s point → A''s own new row',
    v_id <> v_lb and (select count(*) from locations) = v_n + 1
      and (select user_id = v_a from locations where id = v_id),
    'rows ' || v_n || ' → ' || (select count(*) from locations));

  set local role anon;
  begin
    perform public.save_fixed_location(v_x_lat, v_x_lng); v_state := 'no error';
  exception when others then v_state := sqlstate || ' ' || sqlerrm; end;
  insert into _results values (30, 'anon: refused with "permission denied for function"',
    v_state like '42501 permission denied for function%', v_state);

  reset role;
end $$;

select case when ok is true then 'PASS' else 'FAIL' end as result, n, test, detail
from _results
order by n;

rollback;

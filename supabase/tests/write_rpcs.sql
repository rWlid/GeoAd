begin;

create temp table _results (
  n int primary key,
  test text not null,
  ok boolean,
  detail text
) on commit drop;
grant insert, select on _results to authenticated, anon;

with fns(f) as (
  values ('public.save_ad(uuid,uuid[],uuid[],boolean)'::regprocedure),
         ('public.set_ad_active(uuid,boolean)'::regprocedure),
         ('public.delete_product(uuid)'::regprocedure),
         ('public.delete_location(uuid)'::regprocedure),
         ('public.heartbeat_live_location(double precision,double precision)'::regprocedure),
         ('public.stop_live_location()'::regprocedure)
)
insert into _results (n, test, ok)
select 1, 'all six: security invoker (D-09)', bool_and(not p.prosecdef)
from fns join pg_proc p on p.oid = fns.f
union all
select 2, 'all six: search_path is set',
       bool_and(exists (select 1 from unnest(p.proconfig) cfg where cfg like 'search_path=%'))
from fns join pg_proc p on p.oid = fns.f
union all
select 3, 'all six: executable by authenticated',
       bool_and(has_function_privilege('authenticated', fns.f, 'execute'))
from fns
union all
select 4, 'all six: not executable by PUBLIC or anon',
       bool_and(not has_function_privilege('public', fns.f, 'execute')
                and not has_function_privilege('anon', fns.f, 'execute'))
from fns;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000a001', 'test-a@write-rpcs.test', '{"phone":"966599990001"}'),
  ('00000000-0000-4000-8000-00000000b001', 'test-b@write-rpcs.test', '{"phone":"966599990002"}');

do $$
declare
  v_a constant uuid := '00000000-0000-4000-8000-00000000a001';
  v_b constant uuid := '00000000-0000-4000-8000-00000000b001';
  v_state text;
  v_ok boolean;
  v_n int;
  v_sql text;
  v_pa1 uuid; v_pa2 uuid; v_px uuid;
  v_la1 uuid; v_la2 uuid; v_lx uuid;
  v_live uuid; v_live2 uuid;
  v_ad uuid; v_ad_x uuid; v_ad_y uuid; v_ad_z uuid; v_empty uuid;
  v_pb uuid; v_lb uuid;
begin
  set local role authenticated;

  perform set_config('request.jwt.claims', json_build_object('sub', v_b, 'role', 'authenticated')::text, true);
  insert into products (user_id, name, price, category_id, image_paths)
  values (v_b, 'منتج ب', 10, 101, array['b/1.jpg']) returning id into v_pb;
  insert into locations (user_id, lat, lng, type)
  values (v_b, 24.70, 46.70, 'fixed') returning id into v_lb;

  perform set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  insert into products (user_id, name, price, category_id, image_paths)
  values (v_a, 'منتج أ1', 10, 101, array['a/1.jpg']) returning id into v_pa1;
  insert into products (user_id, name, price, category_id, image_paths)
  values (v_a, 'منتج أ2', 20, 101, array['a/2.jpg']) returning id into v_pa2;
  insert into products (user_id, name, price, category_id, image_paths)
  values (v_a, 'منتج أx', 30, 101, array['a/x.jpg']) returning id into v_px;
  insert into locations (user_id, lat, lng, type, updated_at)
  values (v_a, 24.71, 46.67, 'fixed', now() - interval '1 hour') returning id into v_la1;
  insert into locations (user_id, lat, lng, type)
  values (v_a, 24.72, 46.68, 'fixed') returning id into v_la2;
  insert into locations (user_id, lat, lng, type)
  values (v_a, 24.73, 46.69, 'fixed') returning id into v_lx;

  begin
    perform public.save_ad(null, '{}', array[v_la1], true); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (10, 'save_ad: empty product list → 22023', v_state = '22023', v_state);

  begin
    perform public.save_ad(null, array[v_pa1], null, true); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (11, 'save_ad: null location list → 22023', v_state = '22023', v_state);

  begin
    perform public.save_ad(null, array[v_pa1], array[v_la1], null); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (12, 'save_ad: null p_is_active → 22023', v_state = '22023', v_state);

  begin
    perform public.save_ad(null, array[v_pa1, null], array[v_la1], true); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (13, 'save_ad: null element in a list → 22023', v_state = '22023', v_state);

  begin
    perform public.save_ad(null, array[v_pa1, v_pb], array[v_la1], true); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  select count(*) into v_n from ads;
  insert into _results values (14, 'save_ad as A with B''s product → 42501, no ad created',
    v_state = '42501' and v_n = 0, v_state || ', ads=' || v_n);

  begin
    perform public.save_ad(null, array[v_pa1], array[v_lb], true); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  select count(*) into v_n from ads;
  insert into _results values (15, 'save_ad as A with B''s location → 42501, no ad created',
    v_state = '42501' and v_n = 0, v_state || ', ads=' || v_n);

  begin
    perform public.save_ad(gen_random_uuid(), array[v_pa1], array[v_la1], true); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  select count(*) into v_n from ads;
  insert into _results values (16, 'save_ad with an unknown p_ad_id → 42501, nothing created',
    v_state = '42501' and v_n = 0, v_state || ', ads=' || v_n);

  v_ad := public.save_ad(null, array[v_pa1, v_pa1, v_pa2], array[v_la1], true);
  insert into _results values (17, 'save_ad create: active, duplicate ids collapsed (2 products, 1 location)',
    (select is_active from ads where id = v_ad)
    and (select count(*) from ad_products where ad_id = v_ad) = 2
    and (select count(*) from ad_locations where ad_id = v_ad) = 1,
    null);

  insert into _results values (18, 'save_ad: touches updated_at of linked fixed locations (D-07)',
    (select updated_at = now() from locations where id = v_la1), null);

  update ads set updated_at = now() - interval '1 hour' where id = v_ad;
  perform public.save_ad(v_ad, array[v_pa2], array[v_la2], true);
  insert into _results values (19, 'save_ad update: replaces all links and sets updated_at',
    (select array_agg(product_id) from ad_products where ad_id = v_ad) = array[v_pa2]
    and (select array_agg(location_id) from ad_locations where ad_id = v_ad) = array[v_la2]
    and (select updated_at = now() from ads where id = v_ad),
    null);

  perform set_config('request.jwt.claims', json_build_object('sub', v_b, 'role', 'authenticated')::text, true);
  begin
    perform public.save_ad(v_ad, array[v_pb], array[v_lb], true); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (20, 'save_ad as B on A''s ad → 42501', v_state = '42501', v_state);

  begin
    perform public.set_ad_active(v_ad, false); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (21, 'set_ad_active as B on A''s ad → 42501', v_state = '42501', v_state);

  begin
    perform public.delete_product(v_pa1); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (22, 'delete_product as B with A''s product → 42501', v_state = '42501', v_state);

  begin
    perform public.delete_location(v_la1); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (23, 'delete_location as B with A''s location → 42501', v_state = '42501', v_state);

  begin
    perform public.stop_live_location(); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  select count(*) into v_n from locations;
  insert into _results values (24, 'stop_live_location with no live row: no error, nothing changed',
    v_state = 'no error' and v_n = 1, v_state || ', B locations=' || v_n);

  perform set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  insert into _results values (25, 'after B''s attempts: A''s ad, product and location are unchanged',
    (select is_active from ads where id = v_ad)
    and (select array_agg(product_id) from ad_products where ad_id = v_ad) = array[v_pa2]
    and (select array_agg(location_id) from ad_locations where ad_id = v_ad) = array[v_la2]
    and exists (select 1 from products where id = v_pa1)
    and exists (select 1 from locations where id = v_la1),
    null);

  update ads set updated_at = now() - interval '1 hour' where id = v_ad;
  perform public.set_ad_active(v_ad, false);
  v_ok := (select not is_active and updated_at = now() from ads where id = v_ad);
  perform public.set_ad_active(v_ad, true);
  insert into _results values (26, 'set_ad_active: pauses and reactivates, sets updated_at',
    v_ok and (select is_active from ads where id = v_ad), null);

  insert into ads (seller_id, is_active) values (v_a, false) returning id into v_empty;
  begin
    perform public.set_ad_active(v_empty, true); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (27, 'set_ad_active: refuses to activate an ad with no links → 22023 (D-06)',
    v_state = '22023' and not (select is_active from ads where id = v_empty), v_state);

  begin
    perform public.set_ad_active(v_ad, null); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (28, 'set_ad_active: null p_active → 22023', v_state = '22023', v_state);

  v_ad_x := public.save_ad(null, array[v_px], array[v_la1], true);
  v_ad_y := public.save_ad(null, array[v_px, v_pa2], array[v_la1], true);
  v_ad_z := public.save_ad(null, array[v_px], array[v_la1], false);
  update ads set updated_at = now() - interval '1 hour' where id in (v_ad_x, v_ad_y, v_ad_z);

  v_n := public.delete_product(v_px);
  insert into _results values (29, 'delete_product: returns 1 (only the active ad left empty)',
    v_n = 1, 'returned ' || v_n);
  insert into _results values (30, 'delete_product: X paused, Y active, Z paused; product gone',
    not (select is_active from ads where id = v_ad_x)
    and (select is_active from ads where id = v_ad_y)
    and not (select is_active from ads where id = v_ad_z)
    and not exists (select 1 from products where id = v_px),
    null);
  insert into _results values (31, 'delete_product: every ad that lost a link has updated_at = now()',
    (select bool_and(updated_at = now()) from ads where id in (v_ad_x, v_ad_y, v_ad_z)), null);

  begin
    perform public.delete_product(null); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (32, 'delete_product: null p_id → 22023', v_state = '22023', v_state);

  v_ad_x := public.save_ad(null, array[v_pa1], array[v_lx], true);
  v_ad_y := public.save_ad(null, array[v_pa1], array[v_lx, v_la2], true);
  update ads set updated_at = now() - interval '1 hour' where id in (v_ad_x, v_ad_y);

  v_n := public.delete_location(v_lx);
  insert into _results values (33, 'delete_location: returns 1; X paused, Y active; location gone',
    v_n = 1
    and not (select is_active from ads where id = v_ad_x)
    and (select is_active from ads where id = v_ad_y)
    and not exists (select 1 from locations where id = v_lx),
    'returned ' || v_n);
  insert into _results values (34, 'delete_location: every ad that lost a link has updated_at = now()',
    (select bool_and(updated_at = now()) from ads where id in (v_ad_x, v_ad_y)), null);

  v_live := public.heartbeat_live_location(24.74, 46.70);
  insert into _results values (35, 'heartbeat: creates the live row with updated_at = now()',
    (select type = 'live' and user_id = v_a and updated_at = now() from locations where id = v_live),
    null);

  v_live2 := public.heartbeat_live_location(24.75, 46.71);
  insert into _results values (36, 'heartbeat again: same id, new position, still one live row',
    v_live2 = v_live
    and (select lat = 24.75 and lng = 46.71 from locations where id = v_live)
    and (select count(*) from locations where type = 'live') = 1,
    null);

  begin
    perform public.heartbeat_live_location(null, 46.70); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (37, 'heartbeat: null p_lat → 22023', v_state = '22023', v_state);

  begin
    perform public.heartbeat_live_location(91, 46.70); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (38, 'heartbeat: lat out of range → 23514', v_state = '23514', v_state);

  perform public.stop_live_location();
  insert into _results values (39, 'stop_live_location: updated_at = now() - 1 day, row kept (D-10)',
    (select updated_at = now() - interval '1 day' from locations where id = v_live), null);

  v_ad := public.save_ad(null, array[v_pa1], array[v_live, v_la1], true);
  insert into _results values (40, 'save_ad linking the live row leaves its updated_at alone (D-10)',
    (select updated_at = now() - interval '1 day' from locations where id = v_live), null);

  begin
    perform public.delete_location(v_live); v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (41, 'delete_location on the live row → 22023, row kept',
    v_state = '22023' and exists (select 1 from locations where id = v_live), v_state);

  set local role anon;
  v_n := 0;
  foreach v_sql in array array[
    'select public.save_ad(null, null, null, null)',
    'select public.set_ad_active(null, null)',
    'select public.delete_product(null)',
    'select public.delete_location(null)',
    'select public.heartbeat_live_location(null, null)',
    'select public.stop_live_location()'
  ] loop
    begin
      execute v_sql;
    exception when others then
      if sqlstate = '42501' and sqlerrm like 'permission denied for function%' then
        v_n := v_n + 1;
      end if;
    end;
  end loop;
  insert into _results values (42, 'anon: all six calls refused with "permission denied for function"',
    v_n = 6, v_n || ' of 6 refused');

  reset role;
end $$;

select case when ok is true then 'PASS' else 'FAIL' end as result, n, test, detail
from _results
order by n;

rollback;

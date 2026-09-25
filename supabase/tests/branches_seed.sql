begin;

create temp table _results (
  n int primary key,
  test text not null,
  ok boolean,
  detail text
) on commit drop;
grant insert, select on _results to authenticated;

insert into _results (n, test, ok, detail)
select 1, 'seed: A has five named fixed branches and no live row',
       count(*) = 5 and bool_and(type = 'fixed' and name is not null),
       count(*) || ' row(s)'
from public.locations
where user_id = '5eed0000-0000-4000-8000-00000000000a';

do $$
declare
  v_a constant uuid := '5eed0000-0000-4000-8000-00000000000a';
  v_b constant uuid := '5eed0000-0000-4000-8000-00000000000b';
  v_la1 constant uuid := '5eed0002-0000-4000-8000-0000000000a1';
  v_la3 constant uuid := '5eed0002-0000-4000-8000-0000000000a3';
  v_lb1 constant uuid := '5eed0002-0000-4000-8000-0000000000b1';
  v_ad5 constant uuid := '5eed0003-0000-4000-8000-000000000005';
  v_state text;
  v_n int;
  v_ads int;
  v_stop int;
  v_id uuid;
  v_live uuid;
  v_names text[];
  v_before timestamptz;
  v_after timestamptz;
begin
  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  select array_agg(name order by name nulls last, id) into v_names
  from public.locations where user_id = v_a and type = 'fixed';
  insert into _results values (2, 'list as A: five branches, all A''s own',
    cardinality(v_names) = 5
    and not exists (select 1 from public.locations where user_id <> v_a),
    v_names::text);

  select count(*), count(*) filter (
           where a.is_active
             and (select count(*) from public.ad_locations x
                  where x.ad_id = a.id) = 1)
  into v_ads, v_stop
  from public.locations l
  join public.ad_locations al on al.location_id = l.id
  join public.ads a on a.id = al.ad_id
  where l.id = v_la1 and l.type = 'fixed';
  insert into _results values (3, 'usage of LA1 as A: 3 ads, 2 stop',
    v_ads = 3 and v_stop = 2, v_ads || ' ads, ' || v_stop || ' stop');

  select count(*), count(*) filter (
           where a.is_active
             and (select count(*) from public.ad_locations x
                  where x.ad_id = a.id) = 1)
  into v_ads, v_stop
  from public.locations l
  join public.ad_locations al on al.location_id = l.id
  join public.ads a on a.id = al.ad_id
  where l.id = v_la3 and l.type = 'fixed';
  insert into _results values (4, 'usage of LA3 as A: 1 ad, 0 stop (AD3 keeps LA4)',
    v_ads = 1 and v_stop = 0, v_ads || ' ads, ' || v_stop || ' stop');

  insert into public.locations (user_id, name, lat, lng, type)
  values (v_a, 'فرع التجربة', 24.7, 46.7, 'fixed')
  returning id into v_id;
  insert into _results values (5, 'A inserts a named fixed branch',
    v_id is not null, v_id::text);

  begin
    insert into public.locations (user_id, name, lat, lng, type)
    values (v_a, '', 24.7, 46.7, 'fixed');
    v_state := 'no error';
  exception when others then v_state := sqlstate;
  end;
  insert into _results values (6, 'empty name → 23514', v_state = '23514', v_state);

  begin
    insert into public.locations (user_id, name, lat, lng, type)
    values (v_a, repeat('ف', 41), 24.7, 46.7, 'fixed');
    v_state := 'no error';
  exception when others then v_state := sqlstate;
  end;
  insert into _results values (7, '41-character name → 23514', v_state = '23514', v_state);

  begin
    insert into public.locations (user_id, name, lat, lng, type)
    values (v_a, repeat('ف', 40), 24.7, 46.7, 'fixed');
    v_state := 'ok';
  exception when others then v_state := sqlstate;
  end;
  insert into _results values (8, '40-character Arabic name is accepted', v_state = 'ok', v_state);

  begin
    insert into public.locations (user_id, name, lat, lng, type)
    values (v_b, 'ليس لي', 24.7, 46.7, 'fixed');
    v_state := 'no error';
  exception when others then v_state := sqlstate;
  end;
  insert into _results values (9, 'A inserts a row for B → 42501 (RLS)', v_state = '42501', v_state);

  select updated_at into v_before from public.locations where id = v_la3;
  update public.locations
  set name = 'فرع الجنوب الجديد', lat = 24.668, lng = 46.676
  where id = v_la3 and type = 'fixed'
  returning updated_at into v_after;
  get diagnostics v_n = row_count;
  insert into _results values (10, 'A edits LA3 → 1 row, updated_at unchanged (D-10)',
    v_n = 1 and v_after = v_before, v_n || ' row(s), ' || v_before || ' → ' || v_after);

  update public.locations set name = 'مسروق' where id = v_lb1 and type = 'fixed';
  get diagnostics v_n = row_count;
  insert into _results values (11, 'A edits B''s LB1 → 0 rows', v_n = 0, v_n || ' row(s)');

  v_live := public.heartbeat_live_location(24.72, 46.67);
  insert into public.ad_locations (ad_id, location_id) values (v_ad5, v_live);

  select count(*), count(*) filter (
           where a.is_active
             and (select count(*) from public.ad_locations x
                  where x.ad_id = a.id) = 1)
  into v_ads, v_stop
  from public.locations l
  join public.ad_locations al on al.location_id = l.id
  join public.ads a on a.id = al.ad_id
  where l.id = v_la1 and l.type = 'fixed';
  insert into _results values (12, 'usage of LA1 with a live link on AD5: 3 ads, 1 stops',
    v_ads = 3 and v_stop = 1, v_ads || ' ads, ' || v_stop || ' stop');

  update public.locations set name = 'حي' where id = v_live and type = 'fixed';
  get diagnostics v_n = row_count;
  insert into _results values (13, 'the edit filter never touches the live row',
    v_n = 0, v_n || ' row(s)');

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_b, 'role', 'authenticated')::text, true);
  select count(*) into v_n
  from public.locations l
  left join public.ad_locations al on al.location_id = l.id
  where l.id = v_la1;
  insert into _results values (14, 'B reads LA1 and its links → 0 rows', v_n = 0, v_n || ' row(s)');

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  v_n := public.delete_location(v_la1);
  insert into _results values (15, 'delete_location(LA1) returns 1, as forecast in test 12',
    v_n = 1 and not exists (select 1 from public.locations where id = v_la1),
    v_n::text);

  reset role;
end $$;

select case when ok is true then 'PASS' else 'FAIL' end as result, n, test, detail
from _results
order by n;

rollback;

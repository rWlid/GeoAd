begin;

create temp table _results (
  n int primary key,
  test text not null,
  ok boolean,
  detail text
) on commit drop;
grant insert, select on _results to authenticated;

insert into _results (n, test, ok, detail)
select 1, 'seed: A''s p01 is available and AD1, AD6 are active',
       count(*) = 1 and bool_and(pr.is_available)
       and (select count(*) from public.ads
            where id in ('5eed0003-0000-4000-8000-000000000001',
                         '5eed0003-0000-4000-8000-000000000006')
              and is_active) = 2,
       null
from public.products pr
where pr.id = '5eed0001-0000-4000-8000-000000000001'
  and pr.user_id = '5eed0000-0000-4000-8000-00000000000a';

do $$
declare
  v_a constant uuid := '5eed0000-0000-4000-8000-00000000000a';
  v_b constant uuid := '5eed0000-0000-4000-8000-00000000000b';
  v_p01 constant uuid := '5eed0001-0000-4000-8000-000000000001';
  v_ad1 constant uuid := '5eed0003-0000-4000-8000-000000000001';
  v_ad6 constant uuid := '5eed0003-0000-4000-8000-000000000006';
  v_n int;
  v_ads uuid[];
  v_updated timestamptz;
begin
  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  insert into public.ad_products (ad_id, product_id) values (v_ad6, v_p01);

  select array_agg(distinct x.ad_id order by x.ad_id) into v_ads
  from public.nearby_ads(24.7136, 46.6753) x
  where x.products @> jsonb_build_array(jsonb_build_object('id', v_p01));
  insert into _results values (2, 'available: p01 shows in both AD1 and AD6',
    v_ads = array[v_ad1, v_ad6], v_ads::text);

  update public.products set is_available = false where id = v_p01
  returning updated_at into v_updated;
  get diagnostics v_n = row_count;
  insert into _results values (3, 'A stops p01 → 1 row, updated_at = now()',
    v_n = 1 and v_updated = now(), v_n || ' row(s), ' || v_updated);

  select count(*) into v_n
  from public.nearby_ads(24.7136, 46.6753) x
  where x.products @> jsonb_build_array(jsonb_build_object('id', v_p01));
  insert into _results values (4, 'stopped: p01 is in no pin at all',
    v_n = 0, v_n || ' pin(s)');

  select array_agg(distinct x.ad_id order by x.ad_id) into v_ads
  from public.nearby_ads(24.7136, 46.6753) x
  where x.ad_id in (v_ad1, v_ad6);
  insert into _results values (5, 'stopped: AD1 and AD6 still show with their other products',
    v_ads = array[v_ad1, v_ad6], coalesce(v_ads::text, 'none'));

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_b, 'role', 'authenticated')::text, true);
  update public.products set is_available = true where id = v_p01;
  get diagnostics v_n = row_count;
  insert into _results values (6, 'B turns A''s p01 back on → 0 rows',
    v_n = 0, v_n || ' row(s)');

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);
  update public.products set is_available = true where id = v_p01;
  get diagnostics v_n = row_count;
  select array_agg(distinct x.ad_id order by x.ad_id) into v_ads
  from public.nearby_ads(24.7136, 46.6753) x
  where x.products @> jsonb_build_array(jsonb_build_object('id', v_p01));
  insert into _results values (7, 'A turns p01 back on → in both ads again',
    v_n = 1 and v_ads = array[v_ad1, v_ad6], v_ads::text);

  reset role;
end $$;

select case when ok is true then 'PASS' else 'FAIL' end as result, n, test, detail
from _results
order by n;

rollback;

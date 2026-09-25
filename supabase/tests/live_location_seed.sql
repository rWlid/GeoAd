begin;

create temp table _results (
  n int primary key,
  test text not null,
  ok boolean,
  detail text,
  info boolean not null default false
) on commit drop;

create function pg_temp.t(p_n int, p_test text, p_ok boolean, p_detail text default null)
returns jsonb language sql immutable as $$
  select jsonb_build_object('n', p_n, 'test', p_test, 'ok', p_ok, 'detail', p_detail, 'info', false)
$$;

create function pg_temp.info(p_n int, p_test text, p_detail text)
returns jsonb language sql immutable as $$
  select jsonb_build_object('n', p_n, 'test', p_test, 'ok', null, 'detail', p_detail, 'info', true)
$$;

create temp view _seed_problems as
with
exp_profiles as (
  select ('5eed0000-0000-4000-8000-00000000000' || u)::uuid as id, phone, name,
         is_business, business_name,
         '5eed0000-0000-4000-8000-00000000000' || u || '/seed-missing-logo.png' as logo_path
  from (values ('a', '966511110001', 'خالد', true,  'متجر النخبة'),
               ('b', '966511110002', 'سعد',  false, 'بسطة سعد')
       ) v(u, phone, name, is_business, business_name)
),
act_profiles as (
  select id, phone, name, is_business, business_name, logo_path
  from public.profiles
  where id in ('5eed0000-0000-4000-8000-00000000000a', '5eed0000-0000-4000-8000-00000000000b')
),
exp_locations as (
  select ('5eed0002-0000-4000-8000-0000000000' || l)::uuid as id,
         ('5eed0000-0000-4000-8000-00000000000' || left(l, 1))::uuid as user_id,
         lat::float8 as lat, lng::float8 as lng, 'fixed' as type
  from (values ('a1', 24.722628, 46.675300), ('a2', 24.713592, 46.723727),
               ('a3', 24.667558, 46.675300), ('a4', 24.713579, 46.596235),
               ('a5', 24.729558, 46.692773), ('b1', 24.694448, 46.696262),
               ('b2', 24.699555, 46.659927), ('b3', 24.720370, 46.662461)
       ) v(l, lat, lng)
),
act_locations as (
  select id, user_id, lat, lng, type
  from public.locations
  where user_id in ('5eed0000-0000-4000-8000-00000000000a', '5eed0000-0000-4000-8000-00000000000b')
),
exp_products as (
  select ('5eed0001-0000-4000-8000-0000000000' || p)::uuid as id,
         ('5eed0000-0000-4000-8000-00000000000' || u)::uuid as user_id,
         name, price::numeric as price, description, category_id, is_available
  from (values
    ('01', 'a', 'جوال سامسونج جالكسي A55', 1299, 'مستعمل نظيف، 256 جيجا مع الكرتون', 101, true),
    ('02', 'a', 'سماعات بلوتوث لاسلكية', 149, null, 108, true),
    ('03', 'a', 'شاحن سريع 65 واط', 89, 'منفذين USB-C', 102, true),
    ('04', 'a', 'لابتوب لينوفو ثينك باد', 2100, 'معالج i7 وذاكرة 16 جيجا', 103, true),
    ('05', 'a', 'شاشة ألعاب 27 بوصة', 950, null, 107, true),
    ('06', 'a', 'كنب ثلاثي رمادي', 700, 'مستعمل سنة واحدة', 201, false),
    ('07', 'a', 'طاولة طعام خشب', 850, 'تكفي ستة أشخاص', 203, true),
    ('08', 'a', 'كرسي مكتب طبي', 450, null, 203, false),
    ('09', 'a', 'تابلت آيباد الجيل التاسع', 1100, null, 105, true),
    ('10', 'a', 'أباجورة مكتب', 120, null, 208, true),
    ('11', 'b', 'دراجة هوائية جبلية', 600, 'مقاس 26', 602, true),
    ('12', 'b', 'كرة قدم أديداس', 90, null, 601, true),
    ('13', 'b', 'خيمة رحلات لأربعة أشخاص', 0, 'مجانًا لمن يحتاجها', 603, true),
    ('14', 'b', 'عباية سوداء كلوش', 250, 'مقاس 54', 303, true),
    ('15', 'b', 'ساعة يد رجالية', 400, 'ستانلس ستيل، مقاومة للماء', 307, true),
    ('16', 'b', 'شماغ أحمر', 120, null, 301, true)
  ) v(p, u, name, price, description, category_id, is_available)
),
act_products as (
  select id, user_id, name, price, description, category_id, is_available
  from public.products
  where user_id in ('5eed0000-0000-4000-8000-00000000000a', '5eed0000-0000-4000-8000-00000000000b')
),
exp_ads as (
  select ('5eed0003-0000-4000-8000-0000000000' || a)::uuid as id,
         ('5eed0000-0000-4000-8000-00000000000' || u)::uuid as seller_id, is_active
  from (values ('01', 'a', true), ('02', 'a', true), ('03', 'a', true), ('04', 'a', false),
               ('05', 'a', true), ('06', 'a', true), ('07', 'b', true), ('08', 'b', true)
       ) v(a, u, is_active)
),
act_ads as (
  select id, seller_id, is_active
  from public.ads
  where seller_id in ('5eed0000-0000-4000-8000-00000000000a', '5eed0000-0000-4000-8000-00000000000b')
),
exp_ad_products as (
  select ('5eed0003-0000-4000-8000-0000000000' || a)::uuid as ad_id,
         ('5eed0001-0000-4000-8000-0000000000' || p)::uuid as product_id
  from (values ('01', '01'), ('01', '02'), ('02', '03'), ('03', '04'), ('04', '05'),
               ('05', '06'), ('06', '07'), ('06', '08'), ('07', '11'), ('07', '12'),
               ('07', '13'), ('08', '14'), ('08', '15'), ('08', '16')
       ) v(a, p)
),
act_ad_products as (
  select ap.ad_id, ap.product_id
  from public.ad_products ap
  where ap.ad_id in (select id from act_ads)
     or ap.product_id in (select id from act_products)
),
exp_ad_locations as (
  select ('5eed0003-0000-4000-8000-0000000000' || a)::uuid as ad_id,
         ('5eed0002-0000-4000-8000-0000000000' || l)::uuid as location_id
  from (values ('01', 'a1'), ('02', 'a2'), ('03', 'a3'), ('03', 'a4'), ('04', 'a1'),
               ('05', 'a1'), ('06', 'a5'), ('07', 'b1'), ('07', 'b2'), ('08', 'b3')
       ) v(a, l)
),
act_ad_locations as (
  select al.ad_id, al.location_id
  from public.ad_locations al
  where al.ad_id in (select id from act_ads)
     or al.location_id in (select id from act_locations)
)
select array_remove(array[
  case when exists (select * from exp_profiles except select * from act_profiles)
         or exists (select * from act_profiles except select * from exp_profiles)
       then 'profiles' end,
  case when exists (select * from exp_locations except select * from act_locations)
         or exists (select * from act_locations except select * from exp_locations)
       then 'locations' end,
  case when exists (select * from exp_products except select * from act_products)
         or exists (select * from act_products except select * from exp_products)
       then 'products' end,
  case when exists (select * from exp_ads except select * from act_ads)
         or exists (select * from act_ads except select * from exp_ads)
       then 'ads' end,
  case when exists (select * from exp_ad_products except select * from act_ad_products)
         or exists (select * from act_ad_products except select * from exp_ad_products)
       then 'ad_products' end,
  case when exists (select * from exp_ad_locations except select * from act_ad_locations)
         or exists (select * from act_ad_locations except select * from exp_ad_locations)
       then 'ad_locations' end,
  case when (select count(*) from public.categories) <> 59 then 'categories' end,
  case when exists (
         select 1 from storage.objects
         where bucket_id = 'product-images'
           and (storage.foldername(name))[1] in ('5eed0000-0000-4000-8000-00000000000a',
                                                 '5eed0000-0000-4000-8000-00000000000b'))
       then 'storage objects' end
], null) as problems;

create temp view _ab_counts as
with ab(id) as (
  values ('5eed0000-0000-4000-8000-00000000000a'::uuid), ('5eed0000-0000-4000-8000-00000000000b'::uuid)
)
select
  (select count(*) from auth.users where id in (select id from ab)) as users,
  (select count(*) from public.profiles where id in (select id from ab)) as profiles,
  (select count(*) from public.locations where user_id in (select id from ab)) as locations,
  (select count(*) from public.products where user_id in (select id from ab)) as products,
  (select count(*) from public.ads where seller_id in (select id from ab)) as ads,
  (select count(*) from public.ad_products ap
   where ap.ad_id in (select a.id from public.ads a where a.seller_id in (select id from ab))
      or ap.product_id in (select p.id from public.products p where p.user_id in (select id from ab)))
    as ad_products,
  (select count(*) from public.ad_locations al
   where al.ad_id in (select a.id from public.ads a where a.seller_id in (select id from ab))
      or al.location_id in (select l.id from public.locations l where l.user_id in (select id from ab)))
    as ad_locations,
  (select count(*) from public.categories) as categories,
  (select count(*) from storage.objects
   where bucket_id = 'product-images'
     and (storage.foldername(name))[1] in (select id::text from ab)) as storage_objects;

create function pg_temp.act_as(p_user uuid)
returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_user, 'role', 'authenticated')::text, true)
$$;

create function pg_temp.lbl(p_ad uuid, p_loc uuid, p_is_live boolean)
returns text language sql immutable as $$
  select case when p_ad::text like '5eed0003-%'
              then 'AD' || ltrim(right(p_ad::text, 2), '0') else 'newAd' end
      || '@'
      || case when p_loc::text like '5eed0002-%' then 'L' || upper(right(p_loc::text, 2))
              when p_is_live then 'live' else 'newLoc' end
$$;

create function pg_temp.pins()
returns text language sql as $$
  select coalesce(string_agg(pg_temp.lbl(x.ad_id, x.location_id, x.is_live), ' ' order by x.ord), '')
  from public.nearby_ads(24.7136, 46.6753)
         with ordinality as x(ad_id, location_id, lat, lng, is_live, distance_m, seller_id,
                              display_name, is_business, logo_path, phone, products, ord)
  where x.seller_id in ('5eed0000-0000-4000-8000-00000000000a', '5eed0000-0000-4000-8000-00000000000b')
$$;

create function pg_temp.prods(p jsonb)
returns text language sql immutable as $$
  select string_agg('p' || right(j.e ->> 'id', 2), ' ' order by j.i)
  from jsonb_array_elements(p) with ordinality as j(e, i)
$$;

grant execute on function pg_temp.t(int, text, boolean, text), pg_temp.info(int, text, text),
  pg_temp.act_as(uuid), pg_temp.lbl(uuid, uuid, boolean), pg_temp.pins(), pg_temp.prods(jsonb)
  to authenticated;

do $$
declare
  v_a constant uuid := '5eed0000-0000-4000-8000-00000000000a';
  v_b constant uuid := '5eed0000-0000-4000-8000-00000000000b';
  v_p09 constant uuid := '5eed0001-0000-4000-8000-000000000009';
  v_p11 constant uuid := '5eed0001-0000-4000-8000-000000000011';
  v_six constant text := 'AD1@LA1 AD8@LB3 AD7@LB2 AD6@LA5 AD7@LB1 AD2@LA2';
  v_seven constant text := 'newAd@live AD1@LA1 AD8@LB3 AD7@LB2 AD6@LA5 AD7@LB1 AD2@LA2';
  v_expected constant int := 12;
  v_problems text[];
  v_before jsonb;
  v_after jsonb;
  r jsonb := '[]';
  v_err text;
  v_live_a uuid;
  v_live_b uuid;
  v_id uuid;
  v_ad_b uuid;
  v_s text;
  v_s2 text;
  v_n int;
  v_ok boolean;
  v_ts timestamptz;
  v_ts2 timestamptz;
begin
  select problems into v_problems from _seed_problems;
  if cardinality(v_problems) > 0 then
    insert into _results (n, test, ok) values (0,
      'seed not intact (' || array_to_string(v_problems, ', ')
      || '): run supabase/seed_remove.sql, then supabase/seed.sql, in the SQL editor', false);
    return;
  end if;

  select to_jsonb(c) into v_before from _ab_counts c;

  begin
    set local role authenticated;

    perform pg_temp.act_as(v_a);
    v_live_a := public.heartbeat_live_location(24.7180, 46.6753);
    perform public.save_ad(null, array[v_p09], array[v_live_a], true);
    r := r || pg_temp.t(1, 'A''s heartbeat creates A''s live row with updated_at = now()',
      (select type = 'live' and user_id = v_a and updated_at = now()
       from public.locations where id = v_live_a),
      null);

    reset role;
    update public.locations set updated_at = now() - interval '10 seconds' where id = v_live_a;
    set local role authenticated;
    perform pg_temp.act_as(v_b);
    v_s := pg_temp.pins();
    select string_agg(x.is_live || ' ' || pg_temp.prods(x.products), ' | ') into v_s2
    from public.nearby_ads(24.7136, 46.6753) x where x.location_id = v_live_a;
    r := r || pg_temp.t(2, 'D-15 #6: live row updated 10 s ago appears for B, first, is_live, with the tablet only',
      v_s = v_seven and v_s2 = 'true p09', v_s || ' | live pin: ' || coalesce(v_s2, 'none'));

    reset role;
    update public.locations set updated_at = now() - interval '40 seconds' where id = v_live_a;
    set local role authenticated;
    v_s := pg_temp.pins();
    r := r || pg_temp.t(3, 'D-15 #6: live row updated 40 s ago does not appear; the six seed pins are unchanged',
      v_s = v_six, v_s);

    perform pg_temp.act_as(v_a);
    v_id := public.heartbeat_live_location(24.7180, 46.6753);
    v_ok := (select updated_at = now() from public.locations where id = v_live_a);
    perform pg_temp.act_as(v_b);
    v_s := pg_temp.pins();
    r := r || pg_temp.t(4, 'heartbeat again: same row id, updated_at = now(), pin back for B',
      v_id = v_live_a and v_ok and v_s = v_seven, v_s);

    v_live_b := public.heartbeat_live_location(24.7100, 46.6700);
    perform pg_temp.act_as(v_a);
    r := r || pg_temp.t(5, 'B''s fresh live row linked to no ad does not appear (called as A)',
      not exists (select 1 from public.nearby_ads(24.7136, 46.6753) x where x.location_id = v_live_b),
      null);

    perform pg_temp.act_as(v_b);
    v_ad_b := public.save_ad(null, array[v_p11], array[v_live_b], false);
    perform pg_temp.act_as(v_a);
    r := r || pg_temp.t(6, 'B''s live row linked only to an inactive ad does not appear',
      not exists (select 1 from public.nearby_ads(24.7136, 46.6753) x where x.location_id = v_live_b),
      null);

    perform pg_temp.act_as(v_b);
    perform public.set_ad_active(v_ad_b, true);
    perform pg_temp.act_as(v_a);
    select string_agg(x.is_live || ' ' || pg_temp.prods(x.products), ' | ') into v_s
    from public.nearby_ads(24.7136, 46.6753) x where x.location_id = v_live_b;
    r := r || pg_temp.t(7, 'control: once that ad is activated, B''s live pin appears (5 and 6 are not vacuous)',
      v_s = 'true p11', coalesce(v_s, 'none'));

    perform pg_temp.act_as(v_b);
    select count(*) into v_n from public.locations where id = v_live_a;
    v_ok := (select array_agg(id) from public.locations where type = 'live') = array[v_live_b];
    r := r || pg_temp.t(8, 'D-15 #8: B cannot read A''s live row directly; B sees only its own live row',
      v_n = 0 and v_ok, 'A''s row visible: ' || v_n || ', only own live row: ' || v_ok);

    update public.locations set updated_at = now() - interval '1 day' where id = v_live_a;
    get diagnostics v_n = row_count;
    reset role;
    select updated_at into v_ts from public.locations where id = v_live_a;
    set local role authenticated;
    r := r || pg_temp.t(9, 'B cannot stale A''s live row by updating it (0 rows, updated_at unchanged)',
      v_n = 0 and v_ts = now(), v_n || ' rows');

    perform public.stop_live_location();
    reset role;
    select updated_at into v_ts from public.locations where id = v_live_a;
    select updated_at into v_ts2 from public.locations where id = v_live_b;
    set local role authenticated;
    v_s := pg_temp.pins();
    r := r || pg_temp.t(10, 'B''s stop_live_location stales only B''s row: A''s pin still shown, B''s gone',
      v_ts = now() and v_ts2 = now() - interval '1 day' and v_s = v_seven, v_s);

    perform pg_temp.act_as(v_a);
    perform public.stop_live_location();
    perform pg_temp.act_as(v_b);
    v_s := pg_temp.pins();
    reset role;
    select updated_at into v_ts from public.locations where id = v_live_a;
    set local role authenticated;
    r := r || pg_temp.t(11, 'A''s stop_live_location: pin gone for B; row kept with updated_at = now() - 1 day',
      v_s = v_six and v_ts = now() - interval '1 day', v_s);

    select count(*), count(distinct x.seller_id)::text into v_n, v_s
    from public.nearby_ads(24.7136, 46.6753) x where x.seller_id not in (v_a, v_b);
    r := r || pg_temp.info(12, 'other users'' pins around P (not checked)',
      v_n || ' pins from ' || v_s || ' other sellers');

    raise exception using errcode = 'GA017', message = 'end of test body';
  exception when others then
    if sqlstate <> 'GA017' then
      v_err := sqlstate || ': ' || sqlerrm;
    end if;
  end;

  reset role;
  select to_jsonb(c) into v_after from _ab_counts c;

  insert into _results (n, test, ok, detail, info)
  select x.n, x.test, x.ok, x.detail, coalesce(x.info, false)
  from jsonb_to_recordset(r) as x(n int, test text, ok boolean, detail text, info boolean);
  if v_err is not null then
    insert into _results (n, test, ok, detail) values (997,
      'unexpected error after case ' || coalesce(r -> -1 ->> 'n', 'none'), false, v_err);
  end if;
  insert into _results (n, test, ok, detail) values (998,
    'all ' || v_expected || ' cases ran', jsonb_array_length(r) = v_expected,
    jsonb_array_length(r) || ' ran');
  insert into _results (n, test, ok, detail) values (999,
    'nothing left behind: A''s and B''s rows and objects, and categories, counted before and after',
    v_after = v_before,
    case when v_after = v_before then v_after::text else v_before::text || ' → ' || v_after::text end);
end $$;

select case when info then 'INFO' when ok is true then 'PASS' else 'FAIL' end as result,
       n, test, detail
from _results
order by n;

rollback;

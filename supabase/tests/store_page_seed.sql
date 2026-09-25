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

create function pg_temp.lbl(p_id text)
returns text language sql immutable as $$
  select case when p_id like '5eed0003-%' then 'AD' || ltrim(right(p_id, 2), '0')
              when p_id like '5eed0001-%' then 'p' || right(p_id, 2)
              when p_id like '5eed0002-%' then 'L' || upper(right(p_id, 2))
              else 'new' end
$$;

create function pg_temp.ids(p jsonb)
returns text language sql immutable as $$
  select coalesce(string_agg(pg_temp.lbl(j.e ->> 'id'), ' ' order by j.i), '')
  from jsonb_array_elements(p) with ordinality as j(e, i)
$$;

create function pg_temp.refs(p jsonb)
returns text language sql immutable as $$
  select coalesce(string_agg(pg_temp.lbl(j.e), ' ' order by j.i), '')
  from jsonb_array_elements_text(p) with ordinality as j(e, i)
$$;

create function pg_temp.ad_list(p_store jsonb)
returns text language sql immutable as $$
  select coalesce(string_agg(pg_temp.lbl(j.e ->> 'id') || ':' || pg_temp.refs(j.e -> 'product_ids')
                             || '@' || pg_temp.refs(j.e -> 'location_ids'), ' | ' order by j.i), '')
  from jsonb_array_elements(p_store -> 'ads') with ordinality as j(e, i)
$$;

create function pg_temp.ad(p_store jsonb, p_id uuid)
returns jsonb language sql immutable as $$
  select e from jsonb_array_elements(p_store -> 'ads') e where e ->> 'id' = p_id::text
$$;

create function pg_temp.keys(p jsonb)
returns text language sql immutable as $$
  select string_agg(k, ' ' order by k) from jsonb_object_keys(p) k
$$;

grant execute on function pg_temp.t(int, text, boolean, text), pg_temp.info(int, text, text),
  pg_temp.act_as(uuid), pg_temp.lbl(text), pg_temp.ids(jsonb), pg_temp.refs(jsonb),
  pg_temp.ad_list(jsonb), pg_temp.ad(jsonb, uuid), pg_temp.keys(jsonb)
  to authenticated;

do $$
declare
  v_a constant uuid := '5eed0000-0000-4000-8000-00000000000a';
  v_b constant uuid := '5eed0000-0000-4000-8000-00000000000b';
  v_ad1 constant uuid := '5eed0003-0000-4000-8000-000000000001';
  v_ad2 constant uuid := '5eed0003-0000-4000-8000-000000000002';
  v_p01 constant uuid := '5eed0001-0000-4000-8000-000000000001';
  v_p09 constant uuid := '5eed0001-0000-4000-8000-000000000009';
  v_p10 constant uuid := '5eed0001-0000-4000-8000-000000000010';
  v_la1 constant uuid := '5eed0002-0000-4000-8000-0000000000a1';
  v_products constant text := 'p10 p09 p01 p02 p03 p05 p07 p04';
  v_ads constant text := 'AD1:p01 p02@LA1 | AD2:p03@LA2 | AD3:p04@LA3 LA4 | AD6:p07@LA5';
  v_branches constant text := 'LA1 LA3 LA2 LA5 LA4';
  v_expected constant int := 20;
  v_problems text[];
  v_before jsonb;
  v_after jsonb;
  r jsonb := '[]';
  v_err text;
  v_state text;
  v_store jsonb;
  v_other jsonb;
  v_live uuid;
  v_new_ad uuid;
  v_new_ad2 uuid;
  v_s text;
  v_ok boolean;
  v_t timestamptz;
  v_runs numeric[];
begin
  select problems into v_problems from _seed_problems;
  if cardinality(v_problems) > 0 then
    insert into _results (n, test, ok) values (0,
      'seed not intact (' || array_to_string(v_problems, ', ')
      || '): run supabase/seed_remove.sql, then supabase/seed.sql, in the SQL editor', false);
    return;
  end if;

  select to_jsonb(c) into v_before from _ab_counts c;

  select p.prosecdef and p.provolatile = 's'
           and p.proconfig = array['search_path=public, pg_temp'],
         'security definer ' || p.prosecdef || ', volatility ' || p.provolatile::text
           || ', config ' || coalesce(array_to_string(p.proconfig, '; '), 'none')
    into v_ok, v_s
  from pg_proc p where p.oid = 'public.store_page(uuid)'::regprocedure;
  r := r || pg_temp.t(1, 'D-29: store_page is security definer and stable, with search_path pinned',
    v_ok, v_s);

  v_ok := has_function_privilege('authenticated', 'public.store_page(uuid)', 'execute')
          and not has_function_privilege('anon', 'public.store_page(uuid)', 'execute')
          and not exists (select 1 from pg_proc p, aclexplode(p.proacl) a
                          where p.oid = 'public.store_page(uuid)'::regprocedure
                            and a.grantee = 0 and a.privilege_type = 'EXECUTE');
  r := r || pg_temp.t(2, 'EXECUTE granted to authenticated only: not anon, not PUBLIC', v_ok,
    (select string_agg(a.grantee::regrole::text, ', ' order by a.grantee::regrole::text)
     from pg_proc p, aclexplode(p.proacl) a
     where p.oid = 'public.store_page(uuid)'::regprocedure and a.grantee <> 0));

  begin
    set local role anon;
    perform public.store_page(v_a);
    v_state := 'no error';
    raise exception using errcode = 'GA018', message = 'undo anon';
  exception when others then
    if sqlstate <> 'GA018' then
      v_state := sqlstate;
    end if;
  end;
  r := r || pg_temp.t(3, 'anon cannot execute store_page (42501)', v_state = '42501', v_state);

  begin
    set local role authenticated;
    perform pg_temp.act_as(v_b);

    v_store := public.store_page(v_a);
    r := r || pg_temp.t(4, 'A (business), called as B: seller id, متجر النخبة, its logo path and phone',
      v_store ->> 'seller_id' = v_a::text
      and v_store ->> 'business_name' = 'متجر النخبة'
      and v_store ->> 'logo_path' = v_a || '/seed-missing-logo.png'
      and v_store ->> 'phone' = '966511110001',
      coalesce(v_store ->> 'business_name', 'null') || ' / ' || coalesce(v_store ->> 'logo_path', 'no logo')
      || ' / ' || coalesce(v_store ->> 'phone', 'no phone'));

    r := r || pg_temp.t(5, 'exactly the keys seller_id, business_name, logo_path, phone, branches, products, ads',
      pg_temp.keys(v_store) = 'ads branches business_name logo_path phone products seller_id',
      pg_temp.keys(v_store));

    v_s := pg_temp.ids(v_store -> 'products');
    r := r || pg_temp.t(6, 'products: every available product of A by name, ' || v_products,
      v_s = v_products, v_s);
    r := r || pg_temp.t(7, 'products: the stopped sofa p06 and chair p08 are not there',
      v_s not like '%p06%' and v_s not like '%p08%', v_s);
    r := r || pg_temp.t(8, 'products: the tablet p09 and lamp p10 (in no ad) and the monitor p05 (inactive AD4 only) are there',
      v_s like '%p09%' and v_s like '%p10%' and v_s like '%p05%', v_s);

    v_other := v_store -> 'products' -> 2;
    r := r || pg_temp.t(9, 'a product has exactly id, name, price, description, category_id, image_paths (p01)',
      pg_temp.keys(v_other) = 'category_id description id image_paths name price'
      and v_other ->> 'name' = 'جوال سامسونج جالكسي A55'
      and (v_other ->> 'price')::numeric = 1299
      and v_other ->> 'description' = 'مستعمل نظيف، 256 جيجا مع الكرتون'
      and (v_other ->> 'category_id')::int = 101
      and v_other -> 'image_paths' = jsonb_build_array(v_a || '/seed-missing-p01.jpg'),
      v_other::text);

    v_s := pg_temp.ad_list(v_store);
    r := r || pg_temp.t(10, 'ads: exactly AD1, AD2, AD3, AD6 with their available products and fixed branches',
      v_s = v_ads, v_s);
    r := r || pg_temp.t(11, 'ads: inactive AD4 and AD5 (its only product is stopped) are not there; AD6 without the chair',
      v_s not like '%AD4:%' and v_s not like '%AD5:%' and v_s like '%AD6:p07@%', v_s);

    v_s := pg_temp.ids(v_store -> 'branches');
    v_other := v_store -> 'branches' -> 0;
    r := r || pg_temp.t(12, 'branches: the fixed locations of the listed ads by name, ' || v_branches
      || '; LA1 has id, name, lat, lng',
      v_s = v_branches
      and pg_temp.keys(v_other) = 'id lat lng name'
      and v_other ->> 'name' = 'الفرع الرئيسي'
      and (v_other ->> 'lat')::float8 = 24.722628 and (v_other ->> 'lng')::float8 = 46.6753,
      v_s || ' | ' || coalesce(v_other::text, 'none'));

    v_s := 'direct reads of A''s rows as B: products '
      || (select count(*) from public.products where user_id = v_a)
      || ', ads ' || (select count(*) from public.ads where seller_id = v_a)
      || ', locations ' || (select count(*) from public.locations where user_id = v_a);
    r := r || pg_temp.t(13, 'D-29: as B, direct reads of A''s rows return nothing, yet store_page returns them',
      v_s = 'direct reads of A''s rows as B: products 0, ads 0, locations 0'
      and jsonb_array_length(v_store -> 'products') = 8, v_s);

    perform pg_temp.act_as(v_a);
    v_other := public.store_page(v_b);
    r := r || pg_temp.t(14, 'B (individual with a hidden business name and logo), called as A: null',
      v_other is null, coalesce(v_other::text, 'null'));

    r := r || pg_temp.t(15, 'an unknown id and a null id: null',
      public.store_page(gen_random_uuid()) is null and public.store_page(null) is null, null);

    v_other := public.store_page(v_a);
    r := r || pg_temp.t(16, 'A sees its own store exactly as B does', v_other = v_store, null);

    update public.products set is_available = false where id = v_p01;
    v_store := public.store_page(v_a);
    r := r || pg_temp.t(17, 'A stops the phone p01: gone from products and from AD1, which stays with p02',
      pg_temp.ids(v_store -> 'products') = 'p10 p09 p02 p03 p05 p07 p04'
      and pg_temp.refs(pg_temp.ad(v_store, v_ad1) -> 'product_ids') = 'p02',
      pg_temp.ids(v_store -> 'products') || ' | ' || pg_temp.ad_list(v_store));

    perform public.set_ad_active(v_ad2, false);
    v_store := public.store_page(v_a);
    r := r || pg_temp.t(18, 'A pauses AD2: AD2 and its only branch LA2 are gone; the charger p03 stays in products',
      pg_temp.ad(v_store, v_ad2) is null
      and pg_temp.ids(v_store -> 'branches') = 'LA1 LA3 LA5 LA4'
      and pg_temp.ids(v_store -> 'products') like '%p03%',
      pg_temp.ad_list(v_store) || ' | branches ' || pg_temp.ids(v_store -> 'branches'));

    v_live := public.heartbeat_live_location(24.7180, 46.6753);
    v_new_ad := public.save_ad(null, array[v_p09], array[v_live], true);
    v_new_ad2 := public.save_ad(null, array[v_p10], array[v_live, v_la1], true);
    v_store := public.store_page(v_a);
    r := r || pg_temp.t(19, 'live never returned: an ad shown only live is listed with no branch, one shown live + LA1 has LA1 only',
      pg_temp.refs(pg_temp.ad(v_store, v_new_ad) -> 'location_ids') = ''
      and pg_temp.refs(pg_temp.ad(v_store, v_new_ad) -> 'product_ids') = 'p09'
      and pg_temp.refs(pg_temp.ad(v_store, v_new_ad2) -> 'location_ids') = 'LA1'
      and pg_temp.ids(v_store -> 'branches') = 'LA1 LA3 LA5 LA4'
      and position(v_live::text in v_store::text) = 0
      and position('24.718' in v_store::text) = 0,
      'new ads: ' || coalesce(pg_temp.ad(v_store, v_new_ad)::text, 'missing') || ', '
      || coalesce(pg_temp.ad(v_store, v_new_ad2)::text, 'missing')
      || ' | branches ' || pg_temp.ids(v_store -> 'branches'));

    perform public.store_page(v_a);
    v_runs := '{}';
    for i in 1..5 loop
      v_t := clock_timestamp();
      perform public.store_page(v_a);
      v_runs := v_runs || round((extract(epoch from clock_timestamp() - v_t) * 1000)::numeric, 1);
    end loop;
    r := r || pg_temp.info(20, 'timing: 5 warm runs after one warm-up',
      'slowest ' || (select max(x) from unnest(v_runs) x) || ' ms; runs '
      || array_to_string(v_runs, ', ') || ' ms');

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

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

grant execute on function pg_temp.t(int, text, boolean, text), pg_temp.info(int, text, text),
  pg_temp.act_as(uuid)
  to authenticated;

do $$
declare
  v_a constant uuid := '5eed0000-0000-4000-8000-00000000000a';
  v_b constant uuid := '5eed0000-0000-4000-8000-00000000000b';
  v_la1 constant uuid := '5eed0002-0000-4000-8000-0000000000a1';
  v_lb1 constant uuid := '5eed0002-0000-4000-8000-0000000000b1';
  v_lb2 constant uuid := '5eed0002-0000-4000-8000-0000000000b2';
  v_p01 constant uuid := '5eed0001-0000-4000-8000-000000000001';
  v_p11 constant uuid := '5eed0001-0000-4000-8000-000000000011';
  v_p12 constant uuid := '5eed0001-0000-4000-8000-000000000012';
  v_p13 constant uuid := '5eed0001-0000-4000-8000-000000000013';
  v_ad1 constant uuid := '5eed0003-0000-4000-8000-000000000001';
  v_ad7 constant uuid := '5eed0003-0000-4000-8000-000000000007';
  v_expected constant int := 60;
  v_problems text[];
  v_before jsonb;
  v_after jsonb;
  r jsonb := '[]';
  v_err text;
  v_state text;
  v_msg text;
  v_n int;
  v_ok boolean;
  v_cat1 text;
  v_u uuid;
  k int;
  v_who text;
  v_s text;
  v_loc uuid; v_prod uuid; v_ad uuid;
  v_other_loc uuid; v_other_prod uuid;
  v_u1 int; v_u2 int; v_u3 int; v_u4 int; v_u5 int;
  v_d1 int; v_d2 int; v_d3 int; v_d4 int; v_d5 int;
  v_r1 boolean; v_r2 boolean; v_r3 boolean; v_r4 boolean; v_r5 boolean;
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
    select name into v_cat1 from public.categories where id = 1;
    set local role authenticated;
    perform pg_temp.act_as(v_b);

    select count(*) into v_n from public.profiles where id = v_a;
    v_ok := (select array_agg(id) from public.profiles) = array[v_b];
    r := r || pg_temp.t(1, 'profiles: B cannot see A''s row; B sees only its own',
      v_n = 0 and v_ok, 'A''s rows visible: ' || v_n);

    update public.profiles set name = 'مخترق' where id = v_a;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := (select name from public.profiles where id = v_a) = 'خالد';
    set local role authenticated;
    r := r || pg_temp.t(2, 'profiles: B''s update of A''s row → 0 rows, unchanged', v_n = 0 and v_ok, v_n || ' rows');

    delete from public.profiles where id = v_a;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := exists (select 1 from public.profiles where id = v_a);
    set local role authenticated;
    r := r || pg_temp.t(3, 'profiles: B''s delete of A''s row → 0 rows, still there', v_n = 0 and v_ok, v_n || ' rows');

    begin
      insert into public.profiles (id, phone, name) values (v_a, '966500000017', 'مخترق');
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    r := r || pg_temp.t(4, 'profiles: B''s insert of a row with A''s id → 42501', v_state = '42501', v_state);

    delete from public.profiles where id = v_b;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := exists (select 1 from public.profiles where id = v_b);
    set local role authenticated;
    r := r || pg_temp.t(5, 'profiles: B cannot delete its own row either (no delete policy) → 0 rows',
      v_n = 0 and v_ok, v_n || ' rows');

    select count(*) into v_n from public.locations where id = v_la1;
    v_s := (select count(*) from public.locations)::text;
    r := r || pg_temp.t(6, 'locations: B cannot see A''s LA1; B sees its own 3',
      v_n = 0 and v_s = '3', 'LA1 visible: ' || v_n || ', own: ' || v_s);

    update public.locations set lat = 24.0 where id = v_la1;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := (select lat = 24.722628 from public.locations where id = v_la1);
    set local role authenticated;
    r := r || pg_temp.t(7, 'locations: B''s update of A''s LA1 → 0 rows, unchanged', v_n = 0 and v_ok, v_n || ' rows');

    delete from public.locations where id = v_la1;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := exists (select 1 from public.locations where id = v_la1);
    set local role authenticated;
    r := r || pg_temp.t(8, 'locations: B''s delete of A''s LA1 → 0 rows, still there', v_n = 0 and v_ok, v_n || ' rows');

    begin
      insert into public.locations (user_id, lat, lng, type) values (v_a, 24.70, 46.70, 'fixed');
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    r := r || pg_temp.t(9, 'locations: B''s insert carrying A''s user_id → 42501', v_state = '42501', v_state);

    begin
      update public.locations set user_id = v_a where id = v_lb1;
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_ok := (select user_id = v_b from public.locations where id = v_lb1);
    set local role authenticated;
    r := r || pg_temp.t(10, 'locations: B cannot hand its own LB1 to A (with check) → 42501, unchanged',
      v_state = '42501' and v_ok, v_state);

    select count(*) into v_n from public.products where id = v_p01;
    v_s := (select count(*) from public.products)::text;
    r := r || pg_temp.t(11, 'products: B cannot see A''s p01; B sees its own 6',
      v_n = 0 and v_s = '6', 'p01 visible: ' || v_n || ', own: ' || v_s);

    update public.products set price = 1 where id = v_p01;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := (select price = 1299 from public.products where id = v_p01);
    set local role authenticated;
    r := r || pg_temp.t(12, 'D-15 #8 products: B''s update of A''s p01 → 0 rows, price unchanged', v_n = 0 and v_ok, v_n || ' rows');

    delete from public.products where id = v_p01;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := exists (select 1 from public.products where id = v_p01);
    set local role authenticated;
    r := r || pg_temp.t(13, 'products: B''s delete of A''s p01 → 0 rows, still there', v_n = 0 and v_ok, v_n || ' rows');

    begin
      insert into public.products (user_id, name, price, category_id, image_paths)
      values (v_a, 'منتج مزيف', 1, 801, array[v_a || '/t17.jpg']);
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    r := r || pg_temp.t(14, 'products: B''s insert carrying A''s user_id → 42501', v_state = '42501', v_state);

    begin
      update public.products set user_id = v_a where id = v_p11;
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_ok := (select user_id = v_b from public.products where id = v_p11);
    set local role authenticated;
    r := r || pg_temp.t(15, 'products: B cannot hand its own p11 to A (with check) → 42501, unchanged',
      v_state = '42501' and v_ok, v_state);

    select count(*) into v_n from public.ads where id = v_ad1;
    v_s := (select count(*) from public.ads)::text;
    r := r || pg_temp.t(16, 'ads: B cannot see A''s AD1; B sees its own 2',
      v_n = 0 and v_s = '2', 'AD1 visible: ' || v_n || ', own: ' || v_s);

    update public.ads set is_active = false where id = v_ad1;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := (select is_active from public.ads where id = v_ad1);
    set local role authenticated;
    r := r || pg_temp.t(17, 'ads: B''s update of A''s AD1 → 0 rows, still active', v_n = 0 and v_ok, v_n || ' rows');

    delete from public.ads where id = v_ad1;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := exists (select 1 from public.ads where id = v_ad1);
    set local role authenticated;
    r := r || pg_temp.t(18, 'ads: B''s delete of A''s AD1 → 0 rows, still there', v_n = 0 and v_ok, v_n || ' rows');

    begin
      insert into public.ads (seller_id, is_active) values (v_a, false);
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    r := r || pg_temp.t(19, 'ads: B''s insert carrying A''s seller_id → 42501', v_state = '42501', v_state);

    begin
      update public.ads set seller_id = v_a where id = v_ad7;
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_ok := (select seller_id = v_b from public.ads where id = v_ad7);
    set local role authenticated;
    r := r || pg_temp.t(20, 'ads: B cannot hand its own AD7 to A (with check) → 42501, unchanged',
      v_state = '42501' and v_ok, v_state);

    select count(*) into v_n from public.ad_products where ad_id = v_ad1;
    v_s := (select count(*) from public.ad_products)::text;
    r := r || pg_temp.t(21, 'ad_products: B cannot see AD1''s links; B sees its own 6',
      v_n = 0 and v_s = '6', 'AD1 links visible: ' || v_n || ', own: ' || v_s);

    update public.ad_products set product_id = v_p11 where ad_id = v_ad1 and product_id = v_p01;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := exists (select 1 from public.ad_products where ad_id = v_ad1 and product_id = v_p01)
            and not exists (select 1 from public.ad_products where ad_id = v_ad1 and product_id = v_p11);
    set local role authenticated;
    r := r || pg_temp.t(22, 'ad_products: B''s update of A''s link (AD1, p01) → 0 rows, unchanged', v_n = 0 and v_ok, v_n || ' rows');

    delete from public.ad_products where ad_id = v_ad1 and product_id = v_p01;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := exists (select 1 from public.ad_products where ad_id = v_ad1 and product_id = v_p01);
    set local role authenticated;
    r := r || pg_temp.t(23, 'ad_products: B''s delete of A''s link (AD1, p01) → 0 rows, still there', v_n = 0 and v_ok, v_n || ' rows');

    begin
      insert into public.ad_products (ad_id, product_id) values (v_ad7, v_p01);
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    r := r || pg_temp.t(24, 'D-15 #8 ad_products: B cannot link A''s p01 into its AD7 by direct insert → 42501',
      v_state = '42501', v_state);

    begin
      insert into public.ad_products (ad_id, product_id) values (v_ad1, v_p11);
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    r := r || pg_temp.t(25, 'ad_products: B cannot add its p11 to A''s AD1 → 42501', v_state = '42501', v_state);

    begin
      update public.ad_products set product_id = v_p01 where ad_id = v_ad7 and product_id = v_p11;
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_ok := exists (select 1 from public.ad_products where ad_id = v_ad7 and product_id = v_p11);
    set local role authenticated;
    r := r || pg_temp.t(26, 'ad_products: B cannot repoint its own link (AD7, p11) to A''s p01 (with check) → 42501, unchanged',
      v_state = '42501' and v_ok, v_state);

    begin
      perform public.save_ad(v_ad7, array[v_p11, v_p12, v_p13, v_p01], array[v_lb1, v_lb2], true);
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_ok := (select array_agg(product_id order by product_id) from public.ad_products where ad_id = v_ad7)
            = array[v_p11, v_p12, v_p13];
    set local role authenticated;
    r := r || pg_temp.t(27, 'D-15 #8 save_ad: B cannot add A''s p01 to its AD7 → 42501, AD7''s products unchanged',
      v_state = '42501' and v_ok, v_state);

    begin
      perform public.save_ad(null, array[v_p01], array[v_lb1], true);
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_n := (select count(*) from public.ads where seller_id = v_b);
    set local role authenticated;
    r := r || pg_temp.t(28, 'save_ad: B cannot create an ad with A''s p01 → 42501, B still has 2 ads',
      v_state = '42501' and v_n = 2, v_state || ', B''s ads: ' || v_n);

    select count(*) into v_n from public.ad_locations where ad_id = v_ad1;
    v_s := (select count(*) from public.ad_locations)::text;
    r := r || pg_temp.t(29, 'ad_locations: B cannot see AD1''s links; B sees its own 3',
      v_n = 0 and v_s = '3', 'AD1 links visible: ' || v_n || ', own: ' || v_s);

    update public.ad_locations set location_id = v_lb1 where ad_id = v_ad1 and location_id = v_la1;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := exists (select 1 from public.ad_locations where ad_id = v_ad1 and location_id = v_la1)
            and not exists (select 1 from public.ad_locations where ad_id = v_ad1 and location_id = v_lb1);
    set local role authenticated;
    r := r || pg_temp.t(30, 'ad_locations: B''s update of A''s link (AD1, LA1) → 0 rows, unchanged', v_n = 0 and v_ok, v_n || ' rows');

    delete from public.ad_locations where ad_id = v_ad1 and location_id = v_la1;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := exists (select 1 from public.ad_locations where ad_id = v_ad1 and location_id = v_la1);
    set local role authenticated;
    r := r || pg_temp.t(31, 'ad_locations: B''s delete of A''s link (AD1, LA1) → 0 rows, still there', v_n = 0 and v_ok, v_n || ' rows');

    begin
      insert into public.ad_locations (ad_id, location_id) values (v_ad7, v_la1);
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    r := r || pg_temp.t(32, 'ad_locations: B cannot link A''s LA1 into its AD7 by direct insert → 42501',
      v_state = '42501', v_state);

    begin
      insert into public.ad_locations (ad_id, location_id) values (v_ad1, v_lb1);
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    r := r || pg_temp.t(33, 'ad_locations: B cannot add its LB1 to A''s AD1 → 42501', v_state = '42501', v_state);

    begin
      update public.ad_locations set location_id = v_la1 where ad_id = v_ad7 and location_id = v_lb1;
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_ok := exists (select 1 from public.ad_locations where ad_id = v_ad7 and location_id = v_lb1);
    set local role authenticated;
    r := r || pg_temp.t(34, 'ad_locations: B cannot repoint its own link (AD7, LB1) to A''s LA1 (with check) → 42501, unchanged',
      v_state = '42501' and v_ok, v_state);

    begin
      perform public.save_ad(v_ad7, array[v_p11, v_p12, v_p13], array[v_lb1, v_lb2, v_la1], true);
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_ok := (select array_agg(location_id order by location_id) from public.ad_locations where ad_id = v_ad7)
            = array[v_lb1, v_lb2];
    set local role authenticated;
    r := r || pg_temp.t(35, 'save_ad: B cannot add A''s LA1 to its AD7 → 42501, AD7''s locations unchanged',
      v_state = '42501' and v_ok, v_state);

    begin
      perform public.save_ad(null, array[v_p11], array[v_la1], true);
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_n := (select count(*) from public.ads where seller_id = v_b);
    set local role authenticated;
    r := r || pg_temp.t(36, 'save_ad: B cannot create an ad at A''s LA1 → 42501, B still has 2 ads',
      v_state = '42501' and v_n = 2, v_state || ', B''s ads: ' || v_n);

    v_n := (select count(*) from public.categories);
    r := r || pg_temp.t(37, 'categories: B reads all 59 rows', v_n = 59, v_n || ' rows');

    begin
      insert into public.categories (id, parent_id, name, sort_order) values (9999, null, 'اختبار', 99);
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    r := r || pg_temp.t(38, 'categories: B''s insert → 42501', v_state = '42501', v_state);

    begin
      update public.categories set name = 'مخترق' where id = 1;
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_ok := (select name from public.categories where id = 1) = v_cat1;
    set local role authenticated;
    r := r || pg_temp.t(39, 'categories: B''s update → 42501, unchanged', v_state = '42501' and v_ok, v_state);

    begin
      delete from public.categories where id = 801;
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_ok := exists (select 1 from public.categories where id = 801);
    set local role authenticated;
    r := r || pg_temp.t(40, 'categories: B''s delete → 42501, still there', v_state = '42501' and v_ok, v_state);

    select count(distinct c.oid),
           string_agg(c.relname || ':' || p.priv, ', ' order by c.relname, p.priv)
             filter (where has_table_privilege('authenticated', c.oid, p.priv))
      into v_n, v_s
    from pg_class c
    cross join unnest(array['TRUNCATE', 'TRIGGER', 'REFERENCES', 'MAINTAIN', 'INSERT', 'UPDATE', 'DELETE']) p(priv)
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
      and (p.priv in ('TRUNCATE', 'TRIGGER', 'REFERENCES', 'MAINTAIN') or c.relname = 'categories');
    r := r || pg_temp.t(41, 'grants: authenticated has no truncate/trigger/references/maintain on any public table, no insert/update/delete on categories',
      v_n >= 7 and v_s is null, coalesce('held: ' || v_s, 'none held') || ', tables checked: ' || v_n);

    select string_agg(a.privilege_type, ', ' order by a.privilege_type) into v_s
    from pg_default_acl d, aclexplode(d.defaclacl) a
    where d.defaclrole = 'postgres'::regrole and d.defaclnamespace = 'public'::regnamespace
      and d.defaclobjtype = 'r' and a.grantee = 'authenticated'::regrole;
    r := r || pg_temp.t(42, 'default privileges: a new postgres-owned table in public gives authenticated only select/insert/update/delete',
      v_s = 'DELETE, INSERT, SELECT, UPDATE', coalesce(v_s, 'no entry'));

    foreach v_u in array array[v_a, v_b] loop
      k := case when v_u = v_a then 100 else 200 end;
      v_who := case when v_u = v_a then 'A' else 'B' end;
      perform pg_temp.act_as(v_u);

      v_s := (select count(*) from public.profiles) || '/' || (select count(*) from public.locations)
          || '/' || (select count(*) from public.products) || '/' || (select count(*) from public.ads)
          || '/' || (select count(*) from public.ad_products) || '/' || (select count(*) from public.ad_locations);
      r := r || pg_temp.t(k + 1, v_who || ': reads all its own rows (profiles/locations/products/ads/ad_products/ad_locations)',
        v_s = case when v_u = v_a then '1/5/10/6/8/7' else '1/3/6/2/6/3' end, v_s);

      update public.profiles set name = 'اسم تجريبي' where id = v_u;
      get diagnostics v_n = row_count;
      v_ok := (select name from public.profiles where id = v_u) = 'اسم تجريبي';
      r := r || pg_temp.t(k + 2, v_who || ': updates its own profile name', v_n = 1 and v_ok, v_n || ' rows');

      begin
        update public.profiles set phone = '966500000017' where id = v_u;
        v_state := 'no error'; v_msg := null;
      exception when others then v_state := sqlstate; v_msg := sqlerrm; end;
      v_ok := (select phone from public.profiles where id = v_u)
              = case when v_u = v_a then '966511110001' else '966511110002' end;
      r := r || pg_temp.t(k + 3, v_who || ': cannot change its own phone (trigger) → P0001, unchanged',
        v_state = 'P0001' and v_msg like 'profiles.phone cannot be changed%' and v_ok,
        v_state || coalesce(': ' || v_msg, ''));

      begin
        update public.profiles set id = gen_random_uuid() where id = v_u;
        v_state := 'no error'; v_msg := null;
      exception when others then v_state := sqlstate; v_msg := sqlerrm; end;
      v_ok := exists (select 1 from public.profiles where id = v_u);
      r := r || pg_temp.t(k + 4, v_who || ': cannot change its own id (trigger) → P0001, unchanged',
        v_state = 'P0001' and v_msg like 'profiles.id cannot be changed%' and v_ok,
        v_state || coalesce(': ' || v_msg, ''));

      insert into public.locations (user_id, name, lat, lng, type)
      values (v_u, 'موقع اختبار', 24.70, 46.70, 'fixed') returning id into v_loc;
      insert into public.products (user_id, name, price, category_id, image_paths)
      values (v_u, 'منتج اختبار', 10, 801, array[v_u || '/t17.jpg']) returning id into v_prod;
      insert into public.ads (seller_id, is_active) values (v_u, false) returning id into v_ad;
      insert into public.ad_products (ad_id, product_id) values (v_ad, v_prod);
      insert into public.ad_locations (ad_id, location_id) values (v_ad, v_loc);
      select id into v_other_prod from public.products where id <> v_prod order by id limit 1;
      select id into v_other_loc from public.locations where id <> v_loc order by id limit 1;

      update public.locations set name = 'موقع معدل' where id = v_loc;
      get diagnostics v_u1 = row_count;
      update public.products set price = 20 where id = v_prod;
      get diagnostics v_u2 = row_count;
      update public.ads set is_active = true where id = v_ad;
      get diagnostics v_u3 = row_count;
      update public.ad_products set product_id = v_other_prod where ad_id = v_ad and product_id = v_prod;
      get diagnostics v_u4 = row_count;
      update public.ad_locations set location_id = v_other_loc where ad_id = v_ad and location_id = v_loc;
      get diagnostics v_u5 = row_count;

      v_r1 := (select name from public.locations where id = v_loc) = 'موقع معدل';
      v_r2 := (select price from public.products where id = v_prod) = 20;
      v_r3 := (select is_active from public.ads where id = v_ad);
      v_r4 := (select array_agg(product_id) from public.ad_products where ad_id = v_ad) = array[v_other_prod];
      v_r5 := (select array_agg(location_id) from public.ad_locations where ad_id = v_ad) = array[v_other_loc];

      delete from public.ad_products where ad_id = v_ad;
      get diagnostics v_d4 = row_count;
      delete from public.ad_locations where ad_id = v_ad;
      get diagnostics v_d5 = row_count;
      delete from public.ads where id = v_ad;
      get diagnostics v_d3 = row_count;
      delete from public.products where id = v_prod;
      get diagnostics v_d2 = row_count;
      delete from public.locations where id = v_loc;
      get diagnostics v_d1 = row_count;

      reset role;
      v_r1 := v_r1 and not exists (select 1 from public.locations where id = v_loc);
      v_r2 := v_r2 and not exists (select 1 from public.products where id = v_prod);
      v_r3 := v_r3 and not exists (select 1 from public.ads where id = v_ad);
      v_r4 := v_r4 and not exists (select 1 from public.ad_products where ad_id = v_ad);
      v_r5 := v_r5 and not exists (select 1 from public.ad_locations where ad_id = v_ad);
      set local role authenticated;

      r := r || pg_temp.t(k + 5, v_who || ': inserts, updates and deletes its own location',
        v_u1 = 1 and v_d1 = 1 and v_r1, 'updated ' || v_u1 || ', deleted ' || v_d1);
      r := r || pg_temp.t(k + 6, v_who || ': inserts, updates and deletes its own product',
        v_u2 = 1 and v_d2 = 1 and v_r2, 'updated ' || v_u2 || ', deleted ' || v_d2);
      r := r || pg_temp.t(k + 7, v_who || ': inserts, updates and deletes its own ad',
        v_u3 = 1 and v_d3 = 1 and v_r3, 'updated ' || v_u3 || ', deleted ' || v_d3);
      r := r || pg_temp.t(k + 8, v_who || ': links its own product to its own ad, repoints and removes the link',
        v_u4 = 1 and v_d4 = 1 and v_r4, 'updated ' || v_u4 || ', deleted ' || v_d4);
      r := r || pg_temp.t(k + 9, v_who || ': links its own location to its own ad, repoints and removes the link',
        v_u5 = 1 and v_d5 = 1 and v_r5, 'updated ' || v_u5 || ', deleted ' || v_d5);
    end loop;

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

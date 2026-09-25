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
  v_obj constant text := '5eed0000-0000-4000-8000-00000000000a/t17-test.jpg';
  v_moved constant text := '5eed0000-0000-4000-8000-00000000000b/t17-moved.jpg';
  v_expected constant int := 11;
  v_problems text[];
  v_before jsonb;
  v_after jsonb;
  r jsonb := '[]';
  v_err text;
  v_state text;
  v_msg text;
  v_n int;
  v_ok boolean;
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
    insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('product-images', v_obj, v_a::text, '{"mimetype": "image/jpeg", "size": 1}');
    get diagnostics v_n = row_count;
    v_ok := (select count(*) from storage.objects where bucket_id = 'product-images' and name = v_obj) = 1;
    r := r || pg_temp.t(1, 'A creates an object in its own folder and can see it', v_n = 1 and v_ok, v_n || ' rows');

    perform pg_temp.act_as(v_b);
    v_ok := (select count(*) from storage.objects
             where bucket_id = 'product-images' and (storage.foldername(name))[1] = v_a::text) = 0;
    r := r || pg_temp.t(2, 'B cannot see (or list) anything in A''s folder', v_ok, null);

    begin
      insert into storage.objects (bucket_id, name, owner_id, metadata)
      values ('product-images', v_a || '/t17-by-b.jpg', v_b::text, '{"mimetype": "image/jpeg", "size": 1}');
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    r := r || pg_temp.t(3, 'B cannot upload into A''s folder → 42501', v_state = '42501', v_state);

    update storage.objects set metadata = '{"mimetype": "image/png", "size": 2}'
    where bucket_id = 'product-images' and name = v_obj;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := (select metadata = '{"mimetype": "image/jpeg", "size": 1}'::jsonb
             from storage.objects where bucket_id = 'product-images' and name = v_obj);
    set local role authenticated;
    r := r || pg_temp.t(4, 'B''s update of A''s object → 0 rows, metadata unchanged', v_n = 0 and v_ok, v_n || ' rows');

    update storage.objects set name = v_moved
    where bucket_id = 'product-images' and name = v_obj;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := exists (select 1 from storage.objects where bucket_id = 'product-images' and name = v_obj)
            and not exists (select 1 from storage.objects where bucket_id = 'product-images' and name = v_moved);
    set local role authenticated;
    r := r || pg_temp.t(5, 'B cannot move A''s object into B''s folder → 0 rows, still in A''s folder',
      v_n = 0 and v_ok, v_n || ' rows');

    begin
      delete from storage.objects where bucket_id = 'product-images' and name = v_obj;
      v_state := 'no error'; v_msg := null;
    exception when others then v_state := sqlstate; v_msg := sqlerrm; end;
    r := r || pg_temp.info(6, 'Supabase guard: a direct delete without storage.allow_delete_query',
      v_state || coalesce(': ' || v_msg, ''));

    perform set_config('storage.allow_delete_query', 'true', true);
    delete from storage.objects where bucket_id = 'product-images' and name = v_obj;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := exists (select 1 from storage.objects where bucket_id = 'product-images' and name = v_obj);
    set local role authenticated;
    r := r || pg_temp.t(7, 'B''s delete of A''s object (with the Storage API''s flag) → 0 rows, still there',
      v_n = 0 and v_ok, v_n || ' rows');

    perform pg_temp.act_as(v_a);
    begin
      update storage.objects set name = v_moved
      where bucket_id = 'product-images' and name = v_obj;
      v_state := 'no error';
    exception when others then v_state := sqlstate; end;
    reset role;
    v_ok := exists (select 1 from storage.objects where bucket_id = 'product-images' and name = v_obj)
            and not exists (select 1 from storage.objects where bucket_id = 'product-images' and name = v_moved);
    set local role authenticated;
    r := r || pg_temp.t(8, 'A cannot move its own object into B''s folder (with check) → 42501, still in A''s folder',
      v_state = '42501' and v_ok, v_state);

    update storage.objects set metadata = '{"mimetype": "image/jpeg", "size": 3}'
    where bucket_id = 'product-images' and name = v_obj;
    get diagnostics v_n = row_count;
    v_ok := (select metadata = '{"mimetype": "image/jpeg", "size": 3}'::jsonb
             from storage.objects where bucket_id = 'product-images' and name = v_obj);
    r := r || pg_temp.t(9, 'A updates its own object', v_n = 1 and v_ok, v_n || ' rows');

    perform pg_temp.act_as(v_b);
    insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('product-images', v_b || '/t17-own.jpg', v_b::text, '{"mimetype": "image/jpeg", "size": 1}');
    get diagnostics v_n = row_count;
    v_ok := (select count(*) from storage.objects
             where bucket_id = 'product-images' and name = v_b || '/t17-own.jpg') = 1;
    r := r || pg_temp.t(10, 'B creates an object in its own folder and can see it', v_n = 1 and v_ok, v_n || ' rows');

    perform pg_temp.act_as(v_a);
    delete from storage.objects where bucket_id = 'product-images' and name = v_obj;
    get diagnostics v_n = row_count;
    reset role;
    v_ok := not exists (select 1 from storage.objects where bucket_id = 'product-images' and name = v_obj);
    set local role authenticated;
    r := r || pg_temp.t(11, 'A deletes its own object (with the Storage API''s flag) → 1 row, gone',
      v_n = 1 and v_ok, v_n || ' rows');

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

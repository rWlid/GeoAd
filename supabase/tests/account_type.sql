begin;

create temp table _results (
  n int primary key,
  test text not null,
  ok boolean,
  detail text
) on commit drop;
grant insert, select on _results to authenticated;

insert into _results (n, test, ok, detail)
select 1, 'seed: A is the business خالد, B the individual سعد',
       count(*) = 2, string_agg(name || '/' || is_business, ', ' order by id)
from public.profiles
where (id = '5eed0000-0000-4000-8000-00000000000a' and name = 'خالد' and is_business)
   or (id = '5eed0000-0000-4000-8000-00000000000b' and name = 'سعد' and not is_business);

insert into _results (n, test, ok, detail)
select 2, 'trigger: before update on profiles, enabled, calls the function',
       count(*) = 1, null
from pg_trigger t
where t.tgrelid = 'public.profiles'::regclass
  and t.tgname = 'profiles_identity_is_immutable'
  and t.tgfoid = 'public.prevent_profile_identity_change()'::regprocedure
  and t.tgenabled = 'O'
  and t.tgtype & (1 | 2 | 16) = (1 | 2 | 16);

insert into _results (n, test, ok, detail)
select 3, 'function: search_path set, not executable by PUBLIC, anon or authenticated',
       exists (select 1 from unnest(p.proconfig) cfg where cfg like 'search_path=%')
       and not has_function_privilege('public', p.oid, 'execute')
       and not has_function_privilege('anon', p.oid, 'execute')
       and not has_function_privilege('authenticated', p.oid, 'execute'),
       null
from pg_proc p
where p.oid = 'public.prevent_profile_identity_change()'::regprocedure;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000a001', 'test-a@account-type.test', '{"phone":"966599990001"}'),
  ('00000000-0000-4000-8000-00000000b001', 'test-b@account-type.test', '{"phone":"966599990002"}');

do $$
declare
  v_store constant uuid := '00000000-0000-4000-8000-00000000a001';
  v_person constant uuid := '00000000-0000-4000-8000-00000000b001';
  v_seed_a constant uuid := '5eed0000-0000-4000-8000-00000000000a';
  v_seed_b constant uuid := '5eed0000-0000-4000-8000-00000000000b';
  v_state text;
  v_msg text;
  v_n int;
  v_row record;
begin
  set local role authenticated;

  perform set_config('request.jwt.claims', json_build_object('sub', v_store, 'role', 'authenticated')::text, true);
  select name, is_business into v_row from profiles where id = v_store;
  insert into _results values (10, 'new user: profile exists, name null, individual by default',
    v_row.name is null and v_row.is_business = false, coalesce(v_row.name, 'null') || '/' || v_row.is_business);

  update profiles
     set name = 'فهد', is_business = true, business_name = 'متجر فهد',
         logo_path = v_store || '/logo.png'
   where id = v_store;
  get diagnostics v_n = row_count;
  select name, is_business, business_name, logo_path into v_row from profiles where id = v_store;
  insert into _results values (11, 'onboarding as a store in one update → 1 row, all four columns saved',
    v_n = 1 and v_row.name = 'فهد' and v_row.is_business and v_row.business_name = 'متجر فهد'
      and v_row.logo_path = v_store || '/logo.png',
    v_n || ' row(s)');

  begin
    update profiles set is_business = false where id = v_store; v_state := 'no error';
  exception when others then v_state := sqlstate; v_msg := sqlerrm; end;
  insert into _results values (12, 'store → individual after onboarding → P0001 naming is_business',
    v_state = 'P0001' and v_msg like '%is_business%'
      and (select is_business from profiles where id = v_store),
    v_state);

  update profiles set business_name = 'متجر فهد للإلكترونيات', logo_path = null where id = v_store;
  get diagnostics v_n = row_count;
  insert into _results values (13, 'store: editing business name and logo still works (D-33)',
    v_n = 1 and (select business_name = 'متجر فهد للإلكترونيات' and logo_path is null
                 from profiles where id = v_store),
    v_n || ' row(s)');

  update profiles set is_business = true, business_name = 'متجر فهد' where id = v_store;
  get diagnostics v_n = row_count;
  insert into _results values (14, 'store: writing the same is_business value is not a change → 1 row',
    v_n = 1, v_n || ' row(s)');

  begin
    update profiles set name = null where id = v_store; v_state := 'no error';
  exception when others then v_state := sqlstate; v_msg := sqlerrm; end;
  insert into _results values (15, 'store: clearing the name → P0001 naming profiles.name',
    v_state = 'P0001' and v_msg like '%profiles.name%'
      and (select name = 'فهد' from profiles where id = v_store),
    v_state);

  perform set_config('request.jwt.claims', json_build_object('sub', v_person, 'role', 'authenticated')::text, true);

  update profiles set is_business = true, business_name = 'تجربة' where id = v_person;
  get diagnostics v_n = row_count;
  insert into _results values (20, 'before onboarding (name null) the type may still change → 1 row',
    v_n = 1, v_n || ' row(s)');

  update profiles set name = 'سارة', is_business = false where id = v_person;
  get diagnostics v_n = row_count;
  insert into _results values (21, 'onboarding as an individual in one update → 1 row',
    v_n = 1 and (select name = 'سارة' and not is_business from profiles where id = v_person),
    v_n || ' row(s)');

  begin
    update profiles set is_business = true, business_name = 'متجر سارة' where id = v_person;
    v_state := 'no error';
  exception when others then v_state := sqlstate; v_msg := sqlerrm; end;
  insert into _results values (22, 'individual → store after onboarding → P0001 naming is_business',
    v_state = 'P0001' and v_msg like '%is_business%'
      and (select not is_business from profiles where id = v_person),
    v_state);

  begin
    update profiles set name = null where id = v_person; v_state := 'no error';
  exception when others then v_state := sqlstate; v_msg := sqlerrm; end;
  insert into _results values (23, 'individual: clearing the name → P0001 (no detour to a free type)',
    v_state = 'P0001' and v_msg like '%profiles.name%', v_state);

  begin
    update profiles set name = null, is_business = true, business_name = 'متجر سارة'
     where id = v_person;
    v_state := 'no error';
  exception when others then v_state := sqlstate; v_msg := sqlerrm; end;
  insert into _results values (24, 'individual: clearing the name and switching in one update → P0001',
    v_state = 'P0001', v_state);

  update profiles set name = 'سارة أحمد' where id = v_person;
  get diagnostics v_n = row_count;
  insert into _results values (25, 'individual: renaming still works → 1 row',
    v_n = 1, v_n || ' row(s)');

  perform set_config('request.jwt.claims', json_build_object('sub', v_seed_a, 'role', 'authenticated')::text, true);
  begin
    update profiles set is_business = false where id = v_seed_a; v_state := 'no error';
  exception when others then v_state := sqlstate; v_msg := sqlerrm; end;
  insert into _results values (30, 'seed A (store) → individual → P0001, still a store',
    v_state = 'P0001' and v_msg like '%is_business%'
      and (select is_business from profiles where id = v_seed_a),
    v_state);

  begin
    update profiles set name = null where id = v_seed_a; v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (31, 'seed A: clearing the name → P0001', v_state = 'P0001', v_state);

  update profiles set business_name = business_name where id = v_seed_a;
  get diagnostics v_n = row_count;
  insert into _results values (32, 'seed A: saving its business name (edit form) → 1 row',
    v_n = 1, v_n || ' row(s)');

  perform set_config('request.jwt.claims', json_build_object('sub', v_seed_b, 'role', 'authenticated')::text, true);
  begin
    update profiles set is_business = true where id = v_seed_b; v_state := 'no error';
  exception when others then v_state := sqlstate; v_msg := sqlerrm; end;
  insert into _results values (33, 'seed B (individual, hidden business data) → store → P0001',
    v_state = 'P0001' and v_msg like '%is_business%'
      and (select not is_business from profiles where id = v_seed_b),
    v_state);

  reset role;
end $$;

select case when ok is true then 'PASS' else 'FAIL' end as result, n, test, detail
from _results
order by n;

rollback;

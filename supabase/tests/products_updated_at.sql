begin;

create temp table _results (
  n int primary key,
  test text not null,
  ok boolean,
  detail text
) on commit drop;
grant insert, select on _results to authenticated;

insert into _results (n, test, ok, detail)
select 1, 'seed: A''s p01 exists and was last written before this transaction',
       count(*) = 1 and bool_and(updated_at < now() and created_at < now()),
       string_agg(updated_at::text, ', ')
from public.products
where id = '5eed0001-0000-4000-8000-000000000001'
  and user_id = '5eed0000-0000-4000-8000-00000000000a';

insert into _results (n, test, ok, detail)
select 2, 'trigger: before insert or update on products, per row, enabled',
       count(*) = 1, null
from pg_trigger t
where t.tgrelid = 'public.products'::regclass
  and t.tgname = 'products_set_timestamps'
  and t.tgfoid = 'public.set_products_timestamps()'::regprocedure
  and t.tgenabled = 'O'
  and t.tgtype & (1 | 2 | 4 | 16) = (1 | 2 | 4 | 16);

insert into _results (n, test, ok, detail)
select 3, 'function: invoker, search_path set, not executable by PUBLIC, anon or authenticated',
       not p.prosecdef
       and exists (select 1 from unnest(p.proconfig) cfg where cfg like 'search_path=%')
       and not has_function_privilege('public', p.oid, 'execute')
       and not has_function_privilege('anon', p.oid, 'execute')
       and not has_function_privilege('authenticated', p.oid, 'execute'),
       null
from pg_proc p
where p.oid = 'public.set_products_timestamps()'::regprocedure;

do $$
declare
  v_a constant uuid := '5eed0000-0000-4000-8000-00000000000a';
  v_b constant uuid := '5eed0000-0000-4000-8000-00000000000b';
  v_p01 constant uuid := '5eed0001-0000-4000-8000-000000000001';
  v_past constant timestamptz := '2000-01-01 00:00:00+00';
  v_before record;
  v_row record;
  v_id uuid;
  v_n int;
  v_state text;
begin
  select created_at, updated_at into v_before from public.products where id = v_p01;

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  insert into public.products (user_id, name, price, category_id, image_paths, created_at, updated_at)
  values (v_a, 'حقيبة ظهر', 80, 801, array[v_a || '/test.jpg'], v_past, v_past)
  returning id, created_at, updated_at into v_row;
  v_id := v_row.id;
  insert into _results values (10, 'insert: client-sent created_at and updated_at are replaced by now()',
    v_row.created_at = now() and v_row.updated_at = now(),
    v_row.created_at || ' / ' || v_row.updated_at);

  update public.products set name = 'جوال سامسونج جالكسي A55 نظيف' where id = v_p01;
  get diagnostics v_n = row_count;
  select created_at, updated_at into v_row from public.products where id = v_p01;
  insert into _results values (11, 'plain edit: updated_at moves from the seed time to now(); created_at kept',
    v_n = 1 and v_row.updated_at = now() and v_row.updated_at > v_before.updated_at
      and v_row.created_at = v_before.created_at,
    v_before.updated_at || ' → ' || v_row.updated_at);

  update public.products set updated_at = v_past, created_at = v_past where id = v_p01;
  select created_at, updated_at into v_row from public.products where id = v_p01;
  insert into _results values (12, 'edit sending timestamps: updated_at = now(), created_at unchanged',
    v_row.updated_at = now() and v_row.created_at = v_before.created_at,
    v_row.created_at || ' / ' || v_row.updated_at);

  update public.products set is_available = not is_available where id = v_p01;
  select updated_at into v_row from public.products where id = v_p01;
  insert into _results values (13, 'the available switch (3.2) is an edit too: updated_at = now()',
    v_row.updated_at = now(), v_row.updated_at::text);

  update public.products set image_paths = array[v_a || '/new.jpg'] where id = v_p01;
  get diagnostics v_n = row_count;
  insert into _results values (14, 'A may replace its own image_paths (edit form) → 1 row',
    v_n = 1, v_n || ' row(s)');

  perform set_config('request.jwt.claims', json_build_object('sub', v_b, 'role', 'authenticated')::text, true);

  update public.products set name = 'مسروق', updated_at = v_past where id = v_id;
  get diagnostics v_n = row_count;
  insert into _results values (20, 'B updates A''s product → 0 rows',
    v_n = 0, v_n || ' row(s)');

  delete from public.products where id = v_id;
  get diagnostics v_n = row_count;
  insert into _results values (21, 'B deletes A''s product → 0 rows',
    v_n = 0, v_n || ' row(s)');

  begin
    insert into public.products (user_id, name, price, category_id, image_paths)
    values (v_a, 'منتج باسم غيري', 1, 801, array[v_a || '/x.jpg']);
    v_state := 'no error';
  exception when others then v_state := sqlstate; end;
  insert into _results values (22, 'B inserts a product owned by A → 42501',
    v_state = '42501', v_state);

  reset role;

  select name, updated_at into v_row from public.products where id = v_id;
  insert into _results values (23, 'A''s product is unchanged after B''s attempts',
    v_row.name = 'حقيبة ظهر' and v_row.updated_at = now(), v_row.name);
end $$;

select case when ok is true then 'PASS' else 'FAIL' end as result, n, test, detail
from _results
order by n;

rollback;

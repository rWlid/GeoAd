-- run by hand only, never list it in config.toml's [db.seed]

begin;

delete from auth.users
where id in ('5eed0000-0000-4000-8000-00000000000a',
             '5eed0000-0000-4000-8000-00000000000b');

with seed_users(id) as (
  values ('5eed0000-0000-4000-8000-00000000000a'::uuid),
         ('5eed0000-0000-4000-8000-00000000000b'::uuid)
)
select 'auth.users' as tbl, count(*) as remaining from auth.users where id in (select id from seed_users)
union all
select 'auth.identities', count(*) from auth.identities where user_id in (select id from seed_users)
union all
select 'auth.sessions', count(*) from auth.sessions where user_id in (select id from seed_users)
union all
select 'auth.refresh_tokens', count(*) from auth.refresh_tokens where user_id in (select id::text from seed_users)
union all
select 'public.profiles', count(*) from public.profiles where id in (select id from seed_users)
union all
select 'public.products', count(*) from public.products where user_id in (select id from seed_users)
union all
select 'public.locations', count(*) from public.locations where user_id in (select id from seed_users)
union all
select 'public.ads', count(*) from public.ads where seller_id in (select id from seed_users);

commit;

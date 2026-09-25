with checks(n, test, ok) as (
  values
  (1,  'normalize_ar: ة → ه (قهوة = قهوه)',
       public.normalize_ar('قهوة') = public.normalize_ar('قهوه')),
  (2,  'normalize_ar: أ إ آ → ا',
       public.normalize_ar('أحمد إبراهيم آمنة') = 'احمد ابراهيم امنه'),
  (3,  'normalize_ar: ى → ي, ؤ → و, ئ → ي',
       public.normalize_ar('مستشفى مؤسسة شاطئ') = 'مستشفي موسسه شاطي'),
  (4,  'normalize_ar: tashkeel removed',
       public.normalize_ar('قَهْوَة') = 'قهوه'),
  (5,  'normalize_ar: every tashkeel mark U+064B–U+0652 and tatweel U+0640 removed',
       public.normalize_ar('ب' || (select string_agg(chr(c), '')
                                   from generate_series(1611, 1618) c)
                               || chr(1600) || 'ب') = 'بب'),
  (6,  'normalize_ar: tatweel removed (قهـــوة = قهوه)',
       public.normalize_ar('قهـــوة') = 'قهوه'),
  (7,  'normalize_ar: Latin lower-cased',
       public.normalize_ar('iPhone') = 'iphone'),
  (8,  'normalize_ar: null → empty string',
       public.normalize_ar(null) = ''),
  (9,  'normalize_ar: LIKE wildcards pass through unchanged (escaped by nearby_ads)',
       public.normalize_ar('50% off_x\') = '50% off_x\'),

  (10, 'normalize_ar: immutable',
       (select provolatile = 'i' from pg_proc
        where oid = 'public.normalize_ar(text)'::regprocedure)),
  (11, 'normalize_ar: search_path is set',
       (select coalesce(bool_or(cfg like 'search_path=%'), false)
        from pg_proc, unnest(proconfig) cfg
        where oid = 'public.normalize_ar(text)'::regprocedure)),
  (12, 'normalize_ar: not executable by PUBLIC, anon or authenticated',
       not has_function_privilege('public', 'public.normalize_ar(text)', 'execute')
       and not has_function_privilege('anon', 'public.normalize_ar(text)', 'execute')
       and not has_function_privilege('authenticated', 'public.normalize_ar(text)', 'execute')),

  (13, 'nearby_ads: security definer (D-29 — the only public read path)',
       (select prosecdef from pg_proc
        where oid = 'public.nearby_ads(double precision,double precision,integer[],text,integer)'::regprocedure)),
  (14, 'nearby_ads: search_path is set',
       (select coalesce(bool_or(cfg like 'search_path=%'), false)
        from pg_proc, unnest(proconfig) cfg
        where oid = 'public.nearby_ads(double precision,double precision,integer[],text,integer)'::regprocedure)),
  (15, 'nearby_ads: stable',
       (select provolatile = 's' from pg_proc
        where oid = 'public.nearby_ads(double precision,double precision,integer[],text,integer)'::regprocedure)),
  (16, 'nearby_ads: executable by authenticated',
       has_function_privilege('authenticated',
         'public.nearby_ads(double precision,double precision,integer[],text,integer)', 'execute')),
  (17, 'nearby_ads: not executable by PUBLIC or anon',
       not has_function_privilege('public',
         'public.nearby_ads(double precision,double precision,integer[],text,integer)', 'execute')
       and not has_function_privilege('anon',
         'public.nearby_ads(double precision,double precision,integer[],text,integer)', 'execute')),
  (18, 'nearby_ads: returns logo_path, not logo_url (D-28)',
       (select r like '%logo_path text%' and r not like '%logo_url%'
        from pg_get_function_result(
          'public.nearby_ads(double precision,double precision,integer[],text,integer)'::regprocedure) r)),

  (19, 'nearby_ads: smoke call with every parameter set',
       (select count(*) >= 0
        from public.nearby_ads(24.7136, 46.6753, array[1, 101], 'قَهْوَة', 3000))),
  (20, 'nearby_ads: smoke call with explicit nulls and a tashkeel-only keyword',
       (select count(*) >= 0
        from public.nearby_ads(24.7136, 46.6753, null, 'ًٌـ', null)))
)
select case when ok is true then 'PASS' else 'FAIL' end as result, n, test
from checks
order by n;

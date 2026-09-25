insert into public.categories (id, parent_id, name, sort_order)
values
  (1, null, 'إلكترونيات وأجهزة', 1),
  (101, 1, 'جوالات', 1),
  (102, 1, 'إكسسوارات جوالات', 2),
  (103, 1, 'كمبيوتر ولابتوب', 3),
  (104, 1, 'قطع كمبيوتر', 4),
  (105, 1, 'تابلت', 5),
  (106, 1, 'ألعاب فيديو وأجهزتها', 6),
  (107, 1, 'شاشات وتلفزيونات', 7),
  (108, 1, 'سماعات وصوتيات', 8),
  (109, 1, 'أجهزة منزلية', 9),
  (110, 1, 'كاميرات', 10),
  (111, 1, 'طابعات وشبكات', 11),
  (112, 1, 'أخرى', 12),
  (2, null, 'أثاث ومنزل', 2),
  (201, 2, 'كنب وجلسات', 1),
  (202, 2, 'غرف نوم', 2),
  (203, 2, 'طاولات وكراسي', 3),
  (204, 2, 'أدوات مطبخ', 4),
  (205, 2, 'ديكور وسجاد', 5),
  (206, 2, 'نباتات وحدائق', 6),
  (207, 2, 'عدد وأدوات', 7),
  (208, 2, 'إضاءة', 8),
  (209, 2, 'أخرى', 9),
  (3, null, 'أزياء وموضة', 3),
  (301, 3, 'ملابس رجالية', 1),
  (302, 3, 'ملابس نسائية', 2),
  (303, 3, 'عبايات', 3),
  (304, 3, 'ملابس أطفال', 4),
  (305, 3, 'أحذية', 5),
  (306, 3, 'شنط', 6),
  (307, 3, 'ساعات', 7),
  (308, 3, 'مجوهرات وإكسسوارات', 8),
  (309, 3, 'أخرى', 9),
  (4, null, 'عطور وتجميل', 4),
  (401, 4, 'عطور', 1),
  (402, 4, 'بخور وعود', 2),
  (403, 4, 'مكياج وعناية', 3),
  (404, 4, 'أخرى', 4),
  (5, null, 'أطفال وألعاب', 5),
  (501, 5, 'مستلزمات مواليد', 1),
  (502, 5, 'عربيات وكراسي أطفال', 2),
  (503, 5, 'ألعاب أطفال', 3),
  (504, 5, 'أخرى', 4),
  (6, null, 'رياضة وهوايات', 6),
  (601, 6, 'أدوات رياضية', 1),
  (602, 6, 'دراجات', 2),
  (603, 6, 'رحلات وتخييم', 3),
  (604, 6, 'كتب', 4),
  (605, 6, 'تحف ومقتنيات', 5),
  (606, 6, 'فنون وأعمال يدوية', 6),
  (607, 6, 'آلات موسيقية', 7),
  (608, 6, 'عملات وطوابع', 8),
  (609, 6, 'أخرى', 9),
  (7, null, 'مستلزمات سيارات', 7),
  (701, 7, 'قطع غيار', 1),
  (702, 7, 'إكسسوارات سيارات', 2),
  (703, 7, 'أخرى', 3),
  (8, null, 'أخرى', 8),
  (801, 8, 'أخرى', 1)
on conflict (id) do update
set parent_id = excluded.parent_id,
    name = excluded.name,
    sort_order = excluded.sort_order;

create or replace function public.enforce_product_category_is_leaf()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
    from public.categories c
    where c.id = new.category_id
      and c.parent_id is not null
  ) then
    raise exception 'category_id % is not a subcategory (D-27)', new.category_id;
  end if;

  return new;
end;
$$;

comment on function public.enforce_product_category_is_leaf is
  'Rejects products whose category_id is a main category (D-27).';

create trigger products_category_is_leaf
  before insert or update of category_id on public.products
  for each row
  execute function public.enforce_product_category_is_leaf();

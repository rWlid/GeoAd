-- منتجات المتجر: الكمية، منتج أو خدمة، وصورة المنتج.

-- 1) أعمدة جديدة في جدول المنتجات
alter table public.products
  add column is_service boolean not null default false,
  add column quantity integer check (quantity >= 0),
  add column image_path text;

-- الخدمة ليس لها كمية
alter table public.products
  add constraint products_service_has_no_quantity
  check (public.products.is_service = false or public.products.quantity is null);

-- 2) الصور تُحفظ في bucket المشترك "images" الذي ينشئه
--    20261125000000_profile_logo.sql، بنفس مسار <user id>/<file>.
--    لا ننشئ bucket منفصلاً للمنتجات.

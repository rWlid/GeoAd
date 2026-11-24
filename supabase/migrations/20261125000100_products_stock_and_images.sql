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

-- 2) مكان حفظ صور المنتجات (عام: أي أحد يقدر يشوف الصورة)
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true);

-- 3) البائع يرفع ويحذف الصور داخل مجلد باسم حسابه فقط
--    مثال للمسار: <user id>/1732500000000.jpg
create policy product_images_insert_own_folder
on storage.objects for insert to authenticated
with check (
  storage.objects.bucket_id = 'product-images'
  and (storage.foldername(storage.objects.name))[1] = auth.uid()::text
);

-- الحذف من التطبيق يحتاج قراءة الملف أولاً
create policy product_images_select_own_folder
on storage.objects for select to authenticated
using (
  storage.objects.bucket_id = 'product-images'
  and (storage.foldername(storage.objects.name))[1] = auth.uid()::text
);

create policy product_images_delete_own_folder
on storage.objects for delete to authenticated
using (
  storage.objects.bucket_id = 'product-images'
  and (storage.foldername(storage.objects.name))[1] = auth.uid()::text
);

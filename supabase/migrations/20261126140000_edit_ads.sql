-- تعديل الإعلان: نحذف روابطه القديمة (المنتجات والفروع) ثم نضيف الجديدة.
-- الحذف مسموح فقط لصاحب الإعلان، وعلى روابط إعلانه هو فقط.
-- (حذف الإعلان كله موجود من قبل، وروابطه تنحذف معه تلقائياً.)

create policy "owners delete ad_products" on ad_products for delete to authenticated
  using (
    exists (select 1 from ads where ads.id = ad_products.ad_id and ads.owner = auth.uid())
  );

create policy "owners delete ad_locations" on ad_locations for delete to authenticated
  using (
    exists (select 1 from ads where ads.id = ad_locations.ad_id and ads.owner = auth.uid())
  );

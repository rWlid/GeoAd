-- مخزون لكل فرع: عدد القطع للمنتج في كل فرع (الملقا 5، النرجس 4).
-- الخدمة ليس لها عدد، فيبقى quantity فارغاً لصفوفها.
alter table public.product_locations
  add column quantity integer check (quantity >= 0);

-- صاحب المنتج والفرع فقط يغيّر العدد (الإضافة والحذف لهم سياسات من قبل)
create policy "owners edit product locations" on public.product_locations
  for update to authenticated
  using (
    exists (select 1 from public.products where public.products.id = public.product_locations.product_id and public.products.owner = auth.uid())
    and exists (select 1 from public.locations where public.locations.id = public.product_locations.location_id and public.locations.owner = auth.uid())
  )
  with check (
    exists (select 1 from public.products where public.products.id = public.product_locations.product_id and public.products.owner = auth.uid())
    and exists (select 1 from public.locations where public.locations.id = public.product_locations.location_id and public.locations.owner = auth.uid())
  );

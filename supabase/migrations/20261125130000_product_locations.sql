-- المنتج المتوفر في فروع معينة. المنتج الذي ليس له صفوف هنا = متوفر في كل الفروع،
-- فإضافة فرع جديد لا تحتاج تعديل المنتجات.
create table product_locations (
  product_id bigint not null references products(id) on delete cascade,
  location_id bigint not null references locations(id) on delete cascade,
  primary key (product_id, location_id)
);
alter table product_locations enable row level security;

create policy "signed-in users read product locations" on product_locations for select to authenticated
  using (true);

-- المالك فقط، وبشرط أن المنتج والفرع كلاهما ملكه
create policy "owners add product locations" on product_locations for insert to authenticated
  with check (
    exists (select 1 from products where products.id = product_locations.product_id and products.owner = auth.uid())
    and exists (select 1 from locations where locations.id = product_locations.location_id and locations.owner = auth.uid())
  );

create policy "owners delete product locations" on product_locations for delete to authenticated
  using (
    exists (select 1 from products where products.id = product_locations.product_id and products.owner = auth.uid())
    and exists (select 1 from locations where locations.id = product_locations.location_id and locations.owner = auth.uid())
  );

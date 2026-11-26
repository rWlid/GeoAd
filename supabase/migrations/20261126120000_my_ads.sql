-- إعلاناتي: صلاحيات الإعلانات.
-- القراءة: أي مستخدم مسجّل (العملاء) يقرأ فقط.
-- الكتابة: صاحب الإعلان فقط، وعلى منتجاته وفروعه هو فقط.

-- ads: صاحب حساب المتجر يضيف إعلانه، ويشغّله/يوقفه، ويحذفه (الحذف للتنظيف إذا فشل الحفظ).
create policy "owners add their ads" on ads for insert to authenticated
  with check (
    owner = auth.uid()
    and exists (select 1 from profiles where profiles.id = auth.uid() and profiles.is_business)
  );
create policy "owners edit their ads" on ads for update to authenticated
  using (owner = auth.uid())
  with check (owner = auth.uid());
create policy "owners delete their ads" on ads for delete to authenticated
  using (owner = auth.uid());

-- ad_products: الكل يقرأ، والإضافة فقط لإعلاني ومنتجاتي.
create policy "signed-in users read ad_products" on ad_products for select to authenticated
  using (true);
create policy "owners add ad_products" on ad_products for insert to authenticated
  with check (
    exists (select 1 from ads where ads.id = ad_products.ad_id and ads.owner = auth.uid())
    and exists (select 1 from products where products.id = ad_products.product_id and products.owner = auth.uid())
  );

-- ad_locations: القراءة موجودة مسبقاً، والإضافة فقط لإعلاني وفروعي.
create policy "owners add ad_locations" on ad_locations for insert to authenticated
  with check (
    exists (select 1 from ads where ads.id = ad_locations.ad_id and ads.owner = auth.uid())
    and exists (select 1 from locations where locations.id = ad_locations.location_id and locations.owner = auth.uid())
  );

-- products: العميل يقرأ المنتج فقط إذا كان داخل إعلان مفعّل (عشان يظهر في الخريطة).
create policy "signed-in users read products in active ads" on products for select to authenticated
  using (
    exists (
      select 1
      from ad_products, ads
      where ad_products.product_id = products.id
        and ads.id = ad_products.ad_id
        and ads.is_active
    )
  );

-- نفس شروط الطول التي في التطبيق.
alter table ads add constraint ads_title_length check (char_length(title) between 2 and 60);
alter table ads add constraint ads_description_length check (description is null or char_length(description) <= 500);

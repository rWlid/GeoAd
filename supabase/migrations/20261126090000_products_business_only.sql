-- إضافة المنتجات لحسابات المتاجر فقط، بنفس شرط إضافة الفروع.
-- السائق (حساب فردي) لا يستطيع إضافة منتجات حتى لو تجاوز التطبيق.
-- المنتجات الموجودة لا تتأثر: الشرط على الإضافة الجديدة فقط.
drop policy "sellers add their own products" on products;
create policy "sellers add their own products" on products for insert to authenticated
  with check (
    owner = auth.uid()
    and exists (select 1 from profiles where profiles.id = auth.uid() and profiles.is_business)
  );

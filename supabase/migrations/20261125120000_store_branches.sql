-- فروع المتجر: فرع ثابت (مكان واحد + دوام) أو فرع متنقل (موقعه من جوال السائق).
-- جدول locations الموجود صار هو جدول الفروع.

-- 1) locations تصبح فروعاً: النوع fixed أو mobile
alter table locations drop constraint locations_type_check;
drop index locations_one_live_per_owner;
update locations set type = 'mobile' where type = 'live';

alter table locations
  alter column lat drop not null, -- الفرع المتنقل ليس له مكان قبل أول مشاركة
  alter column lng drop not null,
  add column phone text check (phone ~ '^05[0-9]{8}$'),
  add column address text check (char_length(address) <= 120),
  add column driver_phone text check (driver_phone ~ '^05[0-9]{8}$'),
  add column is_sharing boolean not null default false,
  add column shared_at timestamptz, -- آخر مرة أرسل فيها السائق موقعه
  add constraint locations_type_check check (type in ('fixed', 'mobile')),
  add constraint locations_fixed_has_place check (type = 'mobile' or (lat is not null and lng is not null)),
  add constraint locations_driver_only_mobile check (type = 'mobile' or driver_phone is null);

-- 2) صاحب المتجر يدير فروعه فقط (والإضافة لحسابات المتاجر فقط)
create policy "owners add their branches" on locations for insert to authenticated
  with check (owner = auth.uid()
    and exists (select 1 from profiles where profiles.id = auth.uid() and profiles.is_business));
create policy "owners edit their branches" on locations for update to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid());
create policy "owners delete their branches" on locations for delete to authenticated
  using (owner = auth.uid());

-- 3) الدوام: صف لكل يوم مفتوح، 0 = الأحد … 6 = السبت. لا يوجد صف = مغلق.
--    إذا closes_at أصغر من opens_at فالفرع يغلق بعد منتصف الليل.
create table branch_hours (
  location_id bigint not null references locations(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  opens_at time not null,
  closes_at time not null,
  primary key (location_id, day_of_week)
);
alter table branch_hours enable row level security;
create policy "signed-in users read branch hours" on branch_hours for select to authenticated
  using (true);
create policy "owners manage their branch hours" on branch_hours for all to authenticated
  using (exists (select 1 from locations where locations.id = branch_hours.location_id and locations.owner = auth.uid()))
  with check (exists (select 1 from locations where locations.id = branch_hours.location_id and locations.owner = auth.uid()));

-- 4) الطريق الوحيد للسائق للكتابة: الموقع والمشاركة لفرعه المتنقل فقط.
--    RLS لا تحدد الأعمدة، لذلك دالة تعدّل هذه الأعمدة الأربعة فقط.
create function share_location(branch_id bigint, new_lat double precision, new_lng double precision, sharing boolean)
returns void language sql security definer set search_path = public as $$
  update locations
  set lat = coalesce(new_lat, locations.lat),
      lng = coalesce(new_lng, locations.lng),
      is_sharing = sharing,
      shared_at = now()
  where locations.id = branch_id
    and locations.type = 'mobile'
    and locations.driver_phone = (select profiles.phone from profiles where profiles.id = auth.uid());
$$;
revoke execute on function share_location from public, anon;
grant execute on function share_location to authenticated;

-- بيانات التجربة (أرقام وعناوين ودوام الفروع 1–3) أُضيفت مباشرة في قاعدة GeoAD
-- وليست هنا، لأنها مرتبطة بأرقام صفوف موجودة في تلك القاعدة فقط.

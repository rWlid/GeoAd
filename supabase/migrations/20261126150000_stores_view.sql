-- The map shows each branch's store name and logo to customers.
-- profiles only lets a user read their own row (it has phone and email),
-- so this view shows just the three safe columns, for stores only.
create view public.stores as
select profiles.id, profiles.business_name, profiles.business_logo
from profiles
where profiles.is_business;

grant select on public.stores to authenticated;
revoke select on public.stores from anon;

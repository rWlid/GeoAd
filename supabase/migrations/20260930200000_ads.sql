-- The whole database for the learning version: one table of ads.
-- Paste this into the Supabase SQL editor, or run `supabase db reset` locally.

create table ads (
  id bigint generated always as identity primary key,
  title text not null,
  description text,
  lat double precision not null,
  lng double precision not null
);

-- Row Level Security: nobody can read ads unless this policy allows it.
alter table ads enable row level security;

create policy "signed-in users read ads" on ads
  for select to authenticated using (true);

insert into ads (title, description, lat, lng) values
  ('Coffee 20% off', 'Olaya St', 24.7136, 46.6753),
  ('Shawarma deal', 'King Fahd Rd', 24.7236, 46.6853),
  ('Phone repair', 'Tahlia St', 24.6950, 46.6850),
  ('Gym open day', 'Al Malqa', 24.8050, 46.6100),
  ('Book fair', 'Diriyah', 24.7340, 46.5750);

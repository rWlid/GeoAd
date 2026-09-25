create extension if not exists postgis with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text check (char_length(name) between 2 and 40),
  phone text not null unique check (phone ~ '^9665[0-9]{8}$'),
  is_business boolean not null default false,
  business_name text,
  logo_path text,
  created_at timestamptz not null default now(),
  constraint profiles_business_name_required check (
    not is_business
    or (business_name is not null and char_length(business_name) between 2 and 50)
  )
);

comment on column public.profiles.phone is 'Normalized to 9665XXXXXXXX (D-03); displayed as 05XXXXXXXX.';

create table public.categories (
  id int primary key,
  parent_id int references public.categories (id),
  name text not null check (char_length(name) between 1 and 40),
  sort_order int not null default 0,
  constraint categories_unique_name unique nulls not distinct (parent_id, name)
);

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text check (char_length(name) between 1 and 40),
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  type text not null check (type in ('fixed', 'live')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index locations_one_live_per_user
  on public.locations (user_id)
  where type = 'live';

create table public.products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (char_length(name) between 2 and 60),
  price numeric(10, 2) not null check (price >= 0),
  description text check (char_length(description) <= 500),
  category_id int not null references public.categories (id) on delete restrict,
  image_paths text[] not null check (cardinality(image_paths) between 1 and 5),
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ads (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles (id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ad_products (
  ad_id uuid not null references public.ads (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  primary key (ad_id, product_id)
);

create table public.ad_locations (
  ad_id uuid not null references public.ads (id) on delete cascade,
  location_id uuid not null references public.locations (id) on delete cascade,
  primary key (ad_id, location_id)
);

create index locations_user_id_idx on public.locations (user_id);
create index products_user_id_idx on public.products (user_id);
create index products_category_id_idx on public.products (category_id);
create index ads_seller_id_idx on public.ads (seller_id);
create index ads_updated_at_idx on public.ads (updated_at desc);
create index categories_parent_id_idx on public.categories (parent_id);
create index ad_products_product_id_idx on public.ad_products (product_id);
create index ad_locations_location_id_idx on public.ad_locations (location_id);

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.locations enable row level security;
alter table public.products enable row level security;
alter table public.ads enable row level security;
alter table public.ad_products enable row level security;
alter table public.ad_locations enable row level security;

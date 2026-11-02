-- ==========================================================================
-- RUN_ALL.sql — every migration through 011, concatenated in order.
-- Safe to run this whole file any number of times: every statement in it
-- is idempotent (IF NOT EXISTS / DROP ... IF EXISTS / CREATE OR REPLACE).
-- ==========================================================================

-- ---------- 001_init.sql ----------
-- ============================================================================
-- Agricast Livestock LITE — new Supabase project
-- 001: extensions + profiles (farmer accounts only, no staff/admin/vet roles)
-- ============================================================================

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  full_name text,
  phone text,
  location text,
  created_at timestamptz not null default now()
);

comment on table public.profiles is
  'One row per farmer, mirrors auth.users. Created automatically on signup by the trigger below.';

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_select_own" on public.profiles for select
  using (auth.uid() = id);

create policy "profiles_insert_own" on public.profiles for insert
  with check (auth.uid() = id);

create policy "profiles_update_own" on public.profiles for update
  using (auth.uid() = id) with check (auth.uid() = id);

-- Auto-create a profile row whenever someone signs up through Supabase Auth.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, phone)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'phone'
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Shared updated_at trigger function, reused by 002_marketplace.sql
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

grant select, insert, update on public.profiles to authenticated;

-- ---------- 002_marketplace.sql ----------
-- ============================================================================
-- Agricast Livestock LITE — 002: marketplace only
-- ============================================================================
-- Deliberately self-contained: no farms/animals registers from the original
-- app. A listing carries its own animal description directly, so the whole
-- marketplace feature works without any other module existing.
-- ============================================================================

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,

  title text not null,
  species text not null,
  breed text,
  sex text check (sex in ('male', 'female', 'mixed')),
  quantity integer not null default 1 check (quantity > 0),
  age_months integer,

  asking_price numeric not null check (asking_price >= 0),
  price_unit text not null default 'per_head' check (price_unit in ('per_head', 'per_kg')),
  status text not null default 'active' check (status in ('active', 'sold', 'withdrawn')),
  description text,
  location text,
  photo_urls text[] not null default '{}',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.listings is 'An animal (or group of animals) offered for sale by a farmer.';

create index if not exists listings_owner_id_idx on public.listings (owner_id);
create index if not exists listings_status_idx on public.listings (status);
create index if not exists listings_created_at_idx on public.listings (created_at desc);

alter table public.listings enable row level security;

drop policy if exists "listings_select_active" on public.listings;
drop policy if exists "listings_select_own" on public.listings;
drop policy if exists "listings_insert_own" on public.listings;
drop policy if exists "listings_update_own" on public.listings;
drop policy if exists "listings_delete_own" on public.listings;

-- Anyone — including unauthenticated guests browsing via the anon key —
-- can see active listings. This is the marketplace itself.
create policy "listings_select_active" on public.listings for select
  using (status = 'active');

-- A farmer can always see their own listings, including sold/withdrawn.
create policy "listings_select_own" on public.listings for select
  using (auth.uid() = owner_id);

create policy "listings_insert_own" on public.listings for insert
  to authenticated with check (auth.uid() = owner_id);

create policy "listings_update_own" on public.listings for update
  using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

create policy "listings_delete_own" on public.listings for delete
  using (auth.uid() = owner_id);

drop trigger if exists trg_listings_updated_at on public.listings;
create trigger trg_listings_updated_at before update on public.listings
  for each row execute function public.set_updated_at();

grant select, insert, update, delete on public.listings to authenticated;
grant select on public.listings to anon;


-- ----------------------------------------------------------------------------
-- Listing offers — a buyer's expression of interest on a listing
-- ----------------------------------------------------------------------------

create table if not exists public.listing_offers (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  buyer_id uuid not null references auth.users (id) on delete cascade,

  buyer_name text,
  buyer_phone text,
  offer_price numeric,
  message text,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'withdrawn')),

  created_at timestamptz not null default now()
);

comment on table public.listing_offers is
  'A buyer''s offer on a listing. Visible to the buyer who made it and the farmer who owns the listing.';

create index if not exists listing_offers_listing_id_idx on public.listing_offers (listing_id);
create index if not exists listing_offers_buyer_id_idx on public.listing_offers (buyer_id);

alter table public.listing_offers enable row level security;

drop policy if exists "offers_select_buyer" on public.listing_offers;
drop policy if exists "offers_select_listing_owner" on public.listing_offers;
drop policy if exists "offers_insert_buyer" on public.listing_offers;
drop policy if exists "offers_update_buyer" on public.listing_offers;
drop policy if exists "offers_update_listing_owner" on public.listing_offers;

create policy "offers_select_buyer" on public.listing_offers for select
  using (auth.uid() = buyer_id);

create policy "offers_select_listing_owner" on public.listing_offers for select
  using (exists (
    select 1 from public.listings
    where listings.id = listing_offers.listing_id
      and listings.owner_id = auth.uid()
  ));

create policy "offers_insert_buyer" on public.listing_offers for insert
  to authenticated with check (auth.uid() = buyer_id);

create policy "offers_update_buyer" on public.listing_offers for update
  using (auth.uid() = buyer_id) with check (auth.uid() = buyer_id);

create policy "offers_update_listing_owner" on public.listing_offers for update
  using (exists (
    select 1 from public.listings
    where listings.id = listing_offers.listing_id
      and listings.owner_id = auth.uid()
  ));

grant select, insert, update on public.listing_offers to authenticated;

-- Storage bucket for listing photos (create via dashboard or the line below
-- if you run this with the service role / SQL editor, which can write to
-- storage.buckets).
insert into storage.buckets (id, name, public)
values ('listing-photos', 'listing-photos', true)
on conflict (id) do nothing;

drop policy if exists "listing_photos_public_read" on storage.objects;
drop policy if exists "listing_photos_auth_upload" on storage.objects;

create policy "listing_photos_public_read" on storage.objects for select
  using (bucket_id = 'listing-photos');

create policy "listing_photos_auth_upload" on storage.objects for insert
  to authenticated with check (bucket_id = 'listing-photos');

-- ---------- 003_fix_anon_grants.sql ----------
-- Run this in the Supabase SQL Editor if the Marketplace browse screen
-- shows "No active listings yet" for listings that DO show up under
-- "My listings" for their owner. That symptom means the `anon` role is
-- missing SELECT privilege on the table (RLS policy alone isn't enough --
-- Postgres checks table-level GRANTs first). Safe to run any number of
-- times.

grant usage on schema public to anon, authenticated;
grant select on public.listings to anon;
grant select, insert, update, delete on public.listings to authenticated;
grant select, insert, update on public.listing_offers to authenticated;
grant select, insert, update on public.profiles to authenticated;

-- Sanity check: run this and confirm at least one row has status = 'active'
-- select id, title, status, owner_id from public.listings order by created_at desc limit 10;

-- ---------- 004_finance.sql ----------
-- Adds the ability to record what a listing actually sold for, separate
-- from its asking_price (a farmer might sell for more or less than asked).
-- The finance summary endpoint sums sold_price across a farmer's own
-- 'sold' listings to compute total revenue.

alter table public.listings
  add column if not exists sold_price numeric,
  add column if not exists sold_at timestamptz;

comment on column public.listings.sold_price is
  'What the listing actually sold for. Set when a farmer marks a listing as sold; falls back to asking_price if left blank.';
comment on column public.listings.sold_at is
  'When the listing was marked sold. Set automatically by the API, not the client.';

-- No RLS changes needed: the existing "listings_update_own" policy already
-- lets an owner update any column on their own row, these two included.

-- Force PostgREST to pick up the new column(s)/table immediately.
notify pgrst, 'reload schema';

-- ---------- 005_roles.sql ----------
-- Single-farmer model: exactly one account can publish/manage listings
-- ("farmer"); everyone else who signs up is a "buyer" who can browse and
-- make offers but never create, edit, or delete listings.

alter table public.profiles
  add column if not exists role text not null default 'buyer' check (role in ('farmer', 'buyer'));

comment on column public.profiles.role is
  'farmer: the one account allowed to publish/manage listings. buyer: everyone else (default for all new signups).';

-- Replace the write policies on listings so they also require the caller's
-- profile to have role = 'farmer' — this is enforced by Postgres itself,
-- not just hidden in the app UI, so a buyer calling the API directly still
-- can't create/edit/delete a listing.
drop policy if exists "listings_insert_own" on public.listings;
create policy "listings_insert_own" on public.listings for insert
  to authenticated with check (
    auth.uid() = owner_id
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'farmer')
  );

drop policy if exists "listings_update_own" on public.listings;
create policy "listings_update_own" on public.listings for update
  using (auth.uid() = owner_id)
  with check (
    auth.uid() = owner_id
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'farmer')
  );

drop policy if exists "listings_delete_own" on public.listings;
create policy "listings_delete_own" on public.listings for delete
  using (
    auth.uid() = owner_id
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'farmer')
  );

-- ---------------------------------------------------------------------
-- ONE-TIME STEP — do this part yourself:
-- Your farmer account already exists from before this migration, so it
-- defaults to 'buyer' like everyone else until you promote it manually.
-- Replace the email below with the one you registered as a farmer with,
-- then run just this one line:
--
--   update public.profiles set role = 'farmer' where email = 'YOUR_FARMER_EMAIL_HERE';
--
-- Every other signup from now on is a buyer automatically — there is no
-- way to become the farmer through the app itself, only through this
-- manual SQL update, since this app is designed for exactly one farmer.
-- ---------------------------------------------------------------------

-- Force PostgREST to pick up the new column(s)/table immediately.
notify pgrst, 'reload schema';

-- ---------- 006_geo.sql ----------
-- Optional latitude/longitude on a listing, set when the farmer drops a
-- pin on the map while creating it. Nullable — a listing with just a
-- typed "location" text still works fine without coordinates.

alter table public.listings
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

comment on column public.listings.latitude is 'Optional pin dropped on the map when creating the listing.';
comment on column public.listings.longitude is 'Optional pin dropped on the map when creating the listing.';

-- PostgREST caches the table schema and usually picks up new columns
-- automatically, but this forces an immediate refresh so a newly added
-- column is never blocked by a stale cache (the exact "column not found
-- in schema cache" error this migration exists to prevent).
notify pgrst, 'reload schema';

-- ---------- 007_payments.sql ----------
-- Tracks whether an accepted offer has been paid via Yoco, and which Yoco
-- checkout session it belongs to (so a confirmation call can look it up).

alter table public.listing_offers
  add column if not exists payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'paid')),
  add column if not exists yoco_checkout_id text;

comment on column public.listing_offers.payment_status is
  'unpaid until the buyer completes a Yoco checkout for this accepted offer.';

-- Force PostgREST to pick up the new column(s)/table immediately.
notify pgrst, 'reload schema';

-- ---------- 008_auto_sold_on_payment.sql ----------
-- The moment an offer's payment_status flips to 'paid', automatically mark
-- its listing sold and record the sale price — this is what makes
-- "buyer pays" -> "farmer's listing shows sold" -> "shows up in Finance"
-- happen atomically, without the buyer's own token needing write access
-- to a listing they don't own.
--
-- Why this works under RLS: a buyer updating payment_status on THEIR OWN
-- offer is already allowed (offers_update_buyer policy). This trigger runs
-- as SECURITY DEFINER, owned by the role that runs this migration
-- (normally a superuser in the Supabase SQL editor), so the listings
-- update inside it bypasses RLS instead of needing the buyer to somehow
-- have farmer-level write access.

create or replace function public.handle_offer_paid()
returns trigger as $$
begin
  if new.payment_status = 'paid' and (old.payment_status is distinct from 'paid') then
    update public.listings
    set status = 'sold',
        sold_price = coalesce(new.offer_price, listings.asking_price),
        sold_at = now()
    where id = new.listing_id
      and status <> 'sold';
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_offer_paid on public.listing_offers;
create trigger trg_offer_paid
  after update on public.listing_offers
  for each row execute function public.handle_offer_paid();

-- ---------- 009_deliveries.sql ----------
-- One delivery arrangement per paid offer: either the buyer collects the
-- livestock themselves, or the farmer delivers it — in which case the
-- farmer's live position is tracked here while a delivery is in transit.

create table if not exists public.deliveries (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null unique references public.listing_offers (id) on delete cascade,
  listing_id uuid not null references public.listings (id) on delete cascade,
  farmer_id uuid not null references auth.users (id) on delete cascade,
  buyer_id uuid not null references auth.users (id) on delete cascade,

  method text not null check (method in ('pickup', 'delivery')),

  buyer_latitude double precision,
  buyer_longitude double precision,
  -- Farmer's current position — for 'pickup' this is just the farm/listing
  -- location once; for 'delivery' this gets updated repeatedly while en
  -- route, which is what powers the live tracking map.
  farmer_latitude double precision,
  farmer_longitude double precision,

  distance_km numeric,
  eta_minutes integer,
  status text not null default 'pending' check (status in ('pending', 'in_transit', 'delivered')),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.deliveries is
  'One row per paid offer, tracking how the livestock gets from farmer to buyer.';

create index if not exists deliveries_offer_id_idx on public.deliveries (offer_id);
create index if not exists deliveries_farmer_id_idx on public.deliveries (farmer_id);
create index if not exists deliveries_buyer_id_idx on public.deliveries (buyer_id);

alter table public.deliveries enable row level security;

drop policy if exists "deliveries_select_participant" on public.deliveries;
drop policy if exists "deliveries_insert_participant" on public.deliveries;
drop policy if exists "deliveries_update_participant" on public.deliveries;

create policy "deliveries_select_participant" on public.deliveries for select
  using (auth.uid() = farmer_id or auth.uid() = buyer_id);

create policy "deliveries_insert_participant" on public.deliveries for insert
  to authenticated with check (auth.uid() = farmer_id or auth.uid() = buyer_id);

-- Either side can update: the buyer sets their own pickup/delivery address
-- once, the farmer updates their live position repeatedly and marks it
-- delivered at the end.
create policy "deliveries_update_participant" on public.deliveries for update
  using (auth.uid() = farmer_id or auth.uid() = buyer_id);

drop trigger if exists trg_deliveries_updated_at on public.deliveries;
create trigger trg_deliveries_updated_at before update on public.deliveries
  for each row execute function public.set_updated_at();

grant select, insert, update on public.deliveries to authenticated;

-- Force PostgREST to pick up the new column(s)/table immediately.
notify pgrst, 'reload schema';

-- ---------- 010_listing_visibility_for_buyers.sql ----------
-- Bug: once a listing's status leaves 'active' (e.g. it's sold), the buyer
-- who bought it loses visibility of it (only "active" and "owner" policies
-- existed). That broke arranging delivery and viewing a purchased listing.
--
-- Fix: a buyer with an offer on a listing can always see that listing.
--
-- IMPORTANT (this is the corrected version): the policy must NOT query
-- listing_offers directly. listing_offers' own policies query listings, so
-- listings -> listing_offers -> listings loops forever and Postgres aborts
-- with "infinite recursion detected in policy for relation listings"
-- (error 42P17). The SECURITY DEFINER helpers below read the other table
-- without triggering its row-level security, which breaks the loop.

create or replace function public.user_has_offer_on_listing(p_listing_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.listing_offers
    where listing_id = p_listing_id
      and buyer_id = auth.uid()
  );
$$;

create or replace function public.user_owns_listing(p_listing_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.listings
    where id = p_listing_id
      and owner_id = auth.uid()
  );
$$;

grant execute on function public.user_has_offer_on_listing(uuid) to anon, authenticated;
grant execute on function public.user_owns_listing(uuid) to anon, authenticated;

-- Listings: buyer-with-an-offer can see the listing (no direct subquery).
drop policy if exists "listings_select_buyer" on public.listings;
create policy "listings_select_buyer" on public.listings for select
  using (public.user_has_offer_on_listing(id));

-- Offers: replace the policies that queried listings directly, so the
-- cycle can't re-form from the other side either.
drop policy if exists "offers_select_listing_owner" on public.listing_offers;
create policy "offers_select_listing_owner" on public.listing_offers for select
  using (public.user_owns_listing(listing_id));

drop policy if exists "offers_update_listing_owner" on public.listing_offers;
create policy "offers_update_listing_owner" on public.listing_offers for update
  using (public.user_owns_listing(listing_id));

notify pgrst, 'reload schema';

-- ---------- 011_delivery_start.sql ----------
-- Marks the exact moment a trip begins (buyer starting their pickup
-- journey, or farmer starting a delivery run) — separate from created_at,
-- which is just when pickup/delivery was chosen.

alter table public.deliveries
  add column if not exists started_at timestamptz;

comment on column public.deliveries.started_at is
  'When the traveling party (buyer for pickup, farmer for delivery) tapped Start.';

notify pgrst, 'reload schema';

-- ONE MANUAL STEP: promote your farmer account (replace the email):
--   update public.profiles set role = 'farmer' where email = 'YOUR_FARMER_EMAIL_HERE';

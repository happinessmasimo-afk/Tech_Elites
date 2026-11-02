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

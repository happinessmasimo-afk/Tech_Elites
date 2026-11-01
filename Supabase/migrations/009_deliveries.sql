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

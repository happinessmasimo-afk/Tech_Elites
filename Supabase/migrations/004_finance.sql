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

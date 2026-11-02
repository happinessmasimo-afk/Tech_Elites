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

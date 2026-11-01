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
